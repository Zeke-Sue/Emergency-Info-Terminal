`timescale 1ns/1ps

module frame_store #(
    parameter integer WIDTH=640, HEIGHT=480, BURST=128,
    parameter integer DRAIN_CYCLES=32, READ_TIMEOUT=65535,
    parameter integer STREAMING=0, DUAL_SOURCE=0, ENABLE_AUX=0
)(
    input wire clk, rst, pixel_clk,
    input wire mem_init, mem_busy,
    input wire load_done, pixel_valid,
    input wire reads_enabled,
    output wire pixel_ready,
    input wire [21:0] pixel_addr,
    input wire [23:0] pixel_rgb,
    output reg cache_ready,
    output wire write_idle,
    output reg [3:0] error_code,
    input wire line_req_toggle,
    input wire [3:0] line_image,
    input wire [9:0] line_row,
    input wire line_bank,
    input wire [3:0] line_second_image,
    input wire [9:0] line_split,
    input wire line_horizontal_slide,
    input wire [1:0] line_zoom,
    input wire line_dual,
    input wire [10:0] second_ram_addr,
    output reg [23:0] second_ram_q,
    output reg line_ack_toggle,
    input wire [10:0] line_ram_addr,
    output reg [23:0] line_ram_q,
    output wire wr_en,
    output wire [20:0] wr_addr,
    output wire [31:0] wr_data,
    output wire rd_en,
    output wire [20:0] rd_addr,
    input wire rd_valid,
    input wire [31:0] rd_data,
    input wire aux_valid,aux_write,
    input wire [20:0] aux_addr,
    input wire [31:0] aux_wdata,
    output wire aux_ready,
    output reg aux_done,
    output reg [31:0] aux_rdata
);
    localparam integer PACKED_BURST=BURST*3/4;
    localparam integer LINE_WORDS=WIDTH*3/4;
    localparam integer FRAME_WORDS=LINE_WORDS*HEIGHT;
    localparam integer GROUPS=WIDTH/4;
    localparam [3:0] W_FILL=0, W_PACK0=1, W_PACK1=2, W_PACK2=3,
        W_FETCH=4, W_PRIME=5, W_SEND=6, W_DRAIN=7,
        IDLE=8, R_SEND=9, R_WAIT=10, R_GAP=11, FAULT=12,
        A_WRITE=13,A_READ=14,A_WAIT=15;
    reg [3:0] state;
    reg aux_write_q;
    reg [31:0] aux_data_q;
    reg [1:0] aux_issued;
    reg [2:0] aux_received;
    wire [31:0] write_q;
    reg [7:0] write_read_addr;
    reg [8:0] filled,packed_filled,issued,received,burst_goal;
    reg [21:0] source_base;
    reg [20:0] write_base,read_base;
    reg [23:0] pack_p0,pack_p1,pack_p2,pack_p3;
    reg [9:0] line_received,line_issued;
    reg bank_latched,req_latched;
    reg second_pass,dual_latched;
    reg [20:0] second_base;
    localparam integer TIMER_BITS=$clog2(READ_TIMEOUT+DRAIN_CYCLES+2);
    reg [TIMER_BITS-1:0] timer;
    reg [1:0] req_sync;
    reg [1:0] enable_sync;
    reg [31:0] unpack_w0,unpack_w1;

    wire unpack_w0_bit20,unpack_w0_bit18,unpack_w0_bit9,unpack_w1_bit5;
    physical_hold_buffer bit20_hold(.d(unpack_w0[20]),.q(unpack_w0_bit20));
    physical_hold_buffer bit18_hold(.d(unpack_w0[18]),.q(unpack_w0_bit18));
    physical_hold_buffer bit9_hold(.d(unpack_w0[9]),.q(unpack_w0_bit9));
    physical_hold_buffer bit5_hold(.d(unpack_w1[5]),.q(unpack_w1_bit5));
    wire [31:0] unpack_w0_ram={unpack_w0[31:21],unpack_w0_bit20,unpack_w0[19],unpack_w0_bit18,unpack_w0[17:10],unpack_w0_bit9,unpack_w0[8:0]};
    wire [31:0] unpack_w1_ram={unpack_w1[31:6],unpack_w1_bit5,unpack_w1[4:0]};
    reg [1:0] unpack_phase;
    reg [8:0] group_received;
    wire [9:0] write_group_addr=bank_latched ? GROUPS+group_received : group_received;
    wire [9:0] read_group_addr=line_ram_addr[10] ?
        GROUPS+(line_ram_addr[9:0]>>2) : (line_ram_addr[9:0]>>2);
    wire [9:0] second_group_addr=second_ram_addr[10] ?
        GROUPS+(second_ram_addr[9:0]>>2) : (second_ram_addr[9:0]>>2);
    wire collecting=state==R_SEND || state==R_WAIT;
    wire [20:0] packed_pixel_base=(pixel_addr>>2)+(pixel_addr>>1);

    wire [20:0] row_address=WIDTH==640 ?
        ({11'd0,line_row}<<9)-({11'd0,line_row}<<5) : line_row*LINE_WORDS;
    wire [20:0] frame_address=(WIDTH==640 && HEIGHT==480) ?
        ({17'd0,line_image}<<18)-({17'd0,line_image}<<15)+({17'd0,line_image}<<10) :
        line_image*FRAME_WORDS;
    wire unpack_strobe=collecting && rd_valid && line_received<LINE_WORDS &&
        unpack_phase==2;
    wire unpack_write=unpack_strobe && !second_pass;
    wire [20:0] second_frame_address=(WIDTH==640 && HEIGHT==480) ?
        ({17'd0,line_second_image}<<18)-({17'd0,line_second_image}<<15)+
        ({17'd0,line_second_image}<<10) : line_second_image*FRAME_WORDS;
    wire [23:0] lane_q0,lane_q1,lane_q2,lane_q3;
    reg [1:0] read_lane_q;
    packed_line_bank lane0(.write_clk(clk),.write_enable(unpack_write),
        .write_addr(write_group_addr[8:0]),.write_data(unpack_w0_ram[23:0]),
        .read_clk(pixel_clk),.read_addr(read_group_addr[8:0]),.read_data(lane_q0));
    packed_line_bank lane1(.write_clk(clk),.write_enable(unpack_write),
        .write_addr(write_group_addr[8:0]),.write_data({unpack_w0_ram[31:24],unpack_w1_ram[15:0]}),
        .read_clk(pixel_clk),.read_addr(read_group_addr[8:0]),.read_data(lane_q1));
    packed_line_bank lane2(.write_clk(clk),.write_enable(unpack_write),
        .write_addr(write_group_addr[8:0]),.write_data({rd_data[7:0],unpack_w1[31:16]}),
        .read_clk(pixel_clk),.read_addr(read_group_addr[8:0]),.read_data(lane_q2));
    packed_line_bank lane3(.write_clk(clk),.write_enable(unpack_write),
        .write_addr(write_group_addr[8:0]),.write_data(rd_data[31:8]),
        .read_clk(pixel_clk),.read_addr(read_group_addr[8:0]),.read_data(lane_q3));
    generate if(DUAL_SOURCE) begin: dual_lines
        wire [23:0] q0,q1,q2,q3;
        reg [1:0] lane;
        wire we=unpack_strobe && second_pass;
        packed_line_bank l0(.write_clk(clk),.write_enable(we),
            .write_addr(write_group_addr[8:0]),.write_data(unpack_w0_ram[23:0]),
            .read_clk(pixel_clk),.read_addr(second_group_addr[8:0]),.read_data(q0));
        packed_line_bank l1(.write_clk(clk),.write_enable(we),
            .write_addr(write_group_addr[8:0]),.write_data({unpack_w0_ram[31:24],unpack_w1_ram[15:0]}),
            .read_clk(pixel_clk),.read_addr(second_group_addr[8:0]),.read_data(q1));
        packed_line_bank l2(.write_clk(clk),.write_enable(we),
            .write_addr(write_group_addr[8:0]),.write_data({rd_data[7:0],unpack_w1[31:16]}),
            .read_clk(pixel_clk),.read_addr(second_group_addr[8:0]),.read_data(q2));
        packed_line_bank l3(.write_clk(clk),.write_enable(we),
            .write_addr(write_group_addr[8:0]),.write_data(rd_data[31:8]),
            .read_clk(pixel_clk),.read_addr(second_group_addr[8:0]),.read_data(q3));
        always @(posedge pixel_clk) lane<=second_ram_addr[1:0];
        always @* case(lane)
            0:second_ram_q=q0;1:second_ram_q=q1;2:second_ram_q=q2;default:second_ram_q=q3;
        endcase
    end else begin: one_source
        always @* second_ram_q=line_ram_q;
    end endgenerate
    wire read_pending=req_sync[1]!=line_ack_toggle && (!STREAMING || enable_sync[1]);
    assign pixel_ready=state==W_FILL && mem_init && (STREAMING || !cache_ready) &&
        !(STREAMING && read_pending) && !(ENABLE_AUX&&aux_valid&&!mem_busy);
    assign write_idle=state==W_FILL && filled==0 && !mem_busy;
    assign aux_ready=ENABLE_AUX&&state==W_FILL&&mem_init&&!mem_busy&&!read_pending;
    assign wr_en=state==W_SEND||state==A_WRITE;
    assign wr_addr=state==A_WRITE ? read_base+aux_issued : write_base+issued;
    assign wr_data=state==A_WRITE ? aux_data_q : write_q;
    assign rd_en=state==R_SEND||state==A_READ;

    assign rd_addr=state==A_READ ? read_base+aux_issued : read_base+line_issued;

    wire pack_write=state==W_PACK0 || state==W_PACK1 || state==W_PACK2;
    wire [31:0] pack_data=state==W_PACK0 ? {pack_p1[23:16],pack_p0} :
        state==W_PACK1 ? {pack_p2[15:0],pack_p1[15:0]} : {pack_p3,pack_p2[23:16]};
    buffer_ram #(.DATA_WIDTH(32),.ADDR_WIDTH(7)) write_memory(
        .clk(clk),.we(pack_write),.wa(packed_filled[6:0]),
        .ra(write_read_addr[6:0]),.d(pack_data),.q(write_q));
    always @(posedge clk) begin

        if(state==W_FILL&&pixel_valid&&pixel_ready)begin
            case(filled[1:0])
                0:pack_p0<=pixel_rgb;1:pack_p1<=pixel_rgb;
                2:pack_p2<=pixel_rgb;3:pack_p3<=pixel_rgb;
            endcase
        end
        if((state==W_FILL&&STREAMING&&read_pending&&!mem_busy)||
                (state==IDLE&&req_sync[1]!=line_ack_toggle&&!mem_busy))begin
            read_base<=frame_address+row_address;
            second_base<=second_frame_address+row_address;
        end else if(state==R_WAIT&&received==burst_goal&&line_received==LINE_WORDS&&
                dual_latched&&!second_pass)read_base<=second_base;
        else if(aux_valid&&aux_ready)begin
            read_base<=aux_addr;aux_data_q<=aux_wdata;
        end
        if((state==A_READ||state==A_WAIT)&&!aux_write_q&&rd_valid&&aux_received==0)
            aux_rdata<=rd_data;
        if(collecting && rd_valid && line_received<LINE_WORDS)begin
            if(unpack_phase==0)unpack_w0<=rd_data;
            else if(unpack_phase==1)unpack_w1<=rd_data;
        end
    end
    always @(posedge pixel_clk)read_lane_q<=line_ram_addr[1:0];
    always @* begin
        case(read_lane_q)
            0:line_ram_q=lane_q0;
            1:line_ram_q=lane_q1;
            2:line_ram_q=lane_q2;
            default:line_ram_q=lane_q3;
        endcase
    end
    always @(posedge clk or posedge rst) begin
        if(rst)begin
            state<=W_FILL;cache_ready<=0;error_code<=0;
            filled<=0;packed_filled<=0;issued<=0;received<=0;burst_goal<=0;
            source_base<=0;write_base<=0;write_read_addr<=0;
            line_received<=0;line_issued<=0;bank_latched<=0;req_latched<=0;
            timer<=0;req_sync<=0;enable_sync<=0;line_ack_toggle<=0;
            unpack_phase<=0;group_received<=0;
            second_pass<=0;dual_latched<=0;
            aux_done<=0;aux_write_q<=0;aux_issued<=0;aux_received<=0;
        end else begin
            aux_done<=0;
            if((state==A_READ||state==A_WAIT)&&!aux_write_q&&rd_valid)begin
                aux_received<=aux_received+1'b1;
            end
            req_sync<={req_sync[0],line_req_toggle};
            enable_sync<={enable_sync[0],reads_enabled};
            if(STREAMING && !enable_sync[1])line_ack_toggle<=req_sync[1];
            if(collecting && rd_valid)begin
                received<=received+1'b1;
                line_received<=line_received+1'b1;
                if(unpack_phase==2)begin
                    unpack_phase<=0;group_received<=group_received+1'b1;
                end else unpack_phase<=unpack_phase+1'b1;
            end
            case(state)
                W_FILL:begin
                    if(STREAMING && read_pending && !mem_busy)begin
                        second_pass<=0;dual_latched<=DUAL_SOURCE && line_dual;
                        bank_latched<=line_bank;req_latched<=req_sync[1];
                        line_received<=0;line_issued<=0;issued<=0;received<=0;
                        burst_goal<=0;unpack_phase<=0;group_received<=0;
                        timer<=0;state<=R_SEND;
                    end else if(aux_valid&&aux_ready)begin
                        aux_write_q<=aux_write;timer<=0;aux_issued<=0;aux_received<=0;
                        state<=aux_write ? A_WRITE : A_READ;
                    end else if(pixel_valid && pixel_ready)begin
                        if(filled==0)begin
                            source_base<=pixel_addr;
                            write_base<=packed_pixel_base;
                        end
                        if((filled==0 && pixel_addr[1:0]!=0) ||
                           (filled!=0 && pixel_addr!=source_base+filled))begin
                            error_code<=6;state<=FAULT;
                        end else begin
                            filled<=filled+1'b1;
                            if(filled[1:0]==3)state<=W_PACK0;
                        end
                    end else if(load_done && filled==0 && mem_init && !mem_busy)begin
                        cache_ready<=1;
                        if(!STREAMING)state<=IDLE;
                    end
                end
                W_PACK0:begin packed_filled<=packed_filled+1'b1;state<=W_PACK1;end
                W_PACK1:begin packed_filled<=packed_filled+1'b1;state<=W_PACK2;end
                W_PACK2:begin
                    if(filled==BURST)begin
                        filled<=0;packed_filled<=0;state<=W_FETCH;
                    end else begin packed_filled<=packed_filled+1'b1;state<=W_FILL;end
                end
                W_FETCH:if(!mem_busy)begin write_read_addr<=0;issued<=0;state<=W_PRIME;end
                W_PRIME:begin write_read_addr<=1;state<=W_SEND;end
                W_SEND:begin
                    write_read_addr<=write_read_addr+1'b1;
                    if(issued==PACKED_BURST-1)begin timer<=0;state<=W_DRAIN;end
                    else issued<=issued+1'b1;
                end
                W_DRAIN:begin
                    if(timer<DRAIN_CYCLES)timer<=timer+1'b1;
                    else if(!mem_busy)state<=W_FILL;
                end
                IDLE:if(req_sync[1]!=line_ack_toggle && !mem_busy)begin
                    second_pass<=0;dual_latched<=DUAL_SOURCE && line_dual;
                    bank_latched<=line_bank;req_latched<=req_sync[1];
                    line_received<=0;line_issued<=0;issued<=0;received<=0;burst_goal<=0;
                    unpack_phase<=0;group_received<=0;
                    timer<=0;state<=R_SEND;
                end
                R_SEND:begin
                    timer<=timer+1'b1;line_issued<=line_issued+1'b1;
                    if(issued==BURST-1 || line_issued==LINE_WORDS-1)begin
                        burst_goal<=issued+1'b1;state<=R_WAIT;
                    end else issued<=issued+1'b1;
                end
                R_WAIT:begin
                    timer<=timer+1'b1;
                    if(received==burst_goal)begin
                        if(line_received==LINE_WORDS)begin
                            if(dual_latched && !second_pass)begin
                                second_pass<=1;
                                line_received<=0;line_issued<=0;unpack_phase<=0;
                                group_received<=0;timer<=0;state<=R_GAP;
                            end else begin
                                line_ack_toggle<=req_latched;state<=STREAMING ? W_FILL : IDLE;
                            end
                        end else begin timer<=0;state<=R_GAP;end
                    end else if(timer==READ_TIMEOUT)begin error_code<=5;state<=FAULT;end
                end
                R_GAP:begin
                    if(timer<DRAIN_CYCLES)timer<=timer+1'b1;
                    else if(!mem_busy)begin
                        issued<=0;received<=0;burst_goal<=0;timer<=0;state<=R_SEND;
                    end
                end

                A_WRITE,A_READ:begin
                    timer<=0;
                    if(aux_issued==3)state<=A_WAIT;
                    else aux_issued<=aux_issued+1'b1;
                end
                A_WAIT:begin
                    if(timer<READ_TIMEOUT)timer<=timer+1'b1;
                    if(timer>=DRAIN_CYCLES&&!mem_busy&&(aux_write_q||aux_received==4))begin
                        aux_done<=1;state<=W_FILL;
                    end else if(timer==READ_TIMEOUT)begin
                        error_code<=5;aux_done<=1;state<=FAULT;
                    end
                end
                FAULT:cache_ready<=0;
                default:begin error_code<=15;state<=FAULT;end
            endcase
        end
    end
endmodule
