`timescale 1ns/1ps

module spi_nor_log_transport #(
    parameter integer CLK_DIV=2,
    parameter [23:0] BASE_ADDRESS=24'h7fc000,
    parameter integer SLOT_BITS=8,
    parameter integer POLL_LIMIT=1048575
)(
    input wire clk,input wire rst,
    input wire program_valid,output wire program_ready,
    input wire [23:0] program_address,input wire [7:0] program_data,
    output reg program_done,output reg program_error,
    output reg restore_valid,output reg [15:0] restore_next_sequence,
    output reg [SLOT_BITS-1:0] restore_write_slot,output reg initialized,
    output reg flash_cs_n,output wire flash_sclk,output wire flash_mosi,
    input wire flash_miso,output wire flash_wp_n,output wire flash_hold_n
);
    localparam [4:0] S_SCAN_BEGIN=0,S_SCAN_CMD_WAIT=1,
        S_SCAN_ADDR_BEGIN=2,S_SCAN_ADDR_WAIT=3,S_SCAN_DATA_BEGIN=4,
        S_SCAN_DATA_WAIT=5,S_SCAN_NEXT=6,S_SCAN_FINISH=7,S_COLLECT=8,
        S_WREN_BEGIN=9,S_WREN_WAIT=10,S_CMD_BEGIN=11,S_CMD_WAIT=12,
        S_ADDR_BEGIN=13,S_ADDR_WAIT=14,S_DATA_BEGIN=15,S_DATA_WAIT=16,
        S_POLL_BEGIN=17,S_POLL_CMD_WAIT=18,S_POLL_DATA_BEGIN=19,
        S_POLL_DATA_WAIT=20,S_DONE=21,S_ERROR=22;
    localparam [1:0] OP_ERASE=0,OP_BODY=1,OP_COMMIT=2;

    reg [4:0] state;
    reg spi_start;reg [7:0] spi_tx;
    wire spi_busy,spi_done;wire [7:0] spi_rx;
    spi_mode0_byte_master #(.CLK_DIV(CLK_DIV)) byte_master(
        .clk(clk),.rst(rst),.start(spi_start),.tx_data(spi_tx),
        .busy(spi_busy),.done(spi_done),.rx_data(spi_rx),
        .sclk(flash_sclk),.mosi(flash_mosi),.miso(flash_miso));
    assign flash_wp_n=1'b1;
    assign flash_hold_n=1'b1;

    reg [SLOT_BITS-1:0] scan_slot,scan_best_slot;
    reg [5:0] scan_index;
    reg [1:0] address_index;
    reg [31:0] scan_crc,scan_received_crc,scan_commit;
    reg [15:0] scan_magic,scan_sequence,scan_best_sequence;
    reg [7:0] scan_version;
    reg scan_best_valid;
    wire [23:0] scan_address=BASE_ADDRESS+
        ({{(24-SLOT_BITS){1'b0}},scan_slot}<<6);
    wire scan_record_valid=scan_magic==16'h4c47&&scan_version==8'h01&&
        scan_received_crc==~scan_crc&&
        {scan_commit[31:8],spi_rx}==32'h434d4954;
    function sequence_newer;
        input [15:0] candidate;input [15:0] current;
        reg [15:0] difference;
        begin difference=candidate-current;
            sequence_newer=candidate!=current&&!difference[15];
        end
    endfunction
    function [31:0] crc32_byte;
        input [31:0] current;input [7:0] value;integer k;reg [31:0] work;
        begin work=current^value;
            for(k=0;k<8;k=k+1)
                work=work[0] ? (work>>1)^32'hedb88320 : work>>1;
            crc32_byte=work;
        end
    endfunction

    reg [7:0] record_buffer [0:35];
    reg [5:0] collect_index,data_index;
    reg [23:0] collect_address;
    reg [1:0] operation;
    reg [19:0] poll_count;
    wire [23:0] operation_address=operation==OP_COMMIT ?
        collect_address+24'd32 : collect_address;
    wire [5:0] operation_last_index=operation==OP_BODY ? 6'd31 : 6'd3;
    wire collect_address_in_range=program_address>=BASE_ADDRESS&&
        program_address<BASE_ADDRESS+(24'd1<<(SLOT_BITS+6));
    assign program_ready=initialized&&state==S_COLLECT&&collect_index<36;

    integer i;
    always @(posedge clk or posedge rst)begin
        if(rst)begin
            state<=S_SCAN_BEGIN;spi_start<=0;spi_tx<=0;flash_cs_n<=1;
            program_done<=0;program_error<=0;restore_valid<=0;
            restore_next_sequence<=0;restore_write_slot<=0;initialized<=0;
            scan_slot<=0;scan_best_slot<=0;scan_index<=0;address_index<=0;
            scan_crc<=32'hffffffff;scan_received_crc<=0;scan_commit<=0;
            scan_magic<=0;scan_sequence<=0;scan_best_sequence<=0;
            scan_version<=0;scan_best_valid<=0;collect_index<=0;
            data_index<=0;collect_address<=0;operation<=OP_ERASE;poll_count<=0;
            for(i=0;i<36;i=i+1)record_buffer[i]<=0;
        end else begin
            spi_start<=0;program_done<=0;program_error<=0;restore_valid<=0;
            case(state)
                S_SCAN_BEGIN:begin
                    flash_cs_n<=0;spi_tx<=8'h03;spi_start<=1;
                    state<=S_SCAN_CMD_WAIT;
                end
                S_SCAN_CMD_WAIT:if(spi_done)begin
                    address_index<=0;state<=S_SCAN_ADDR_BEGIN;
                end
                S_SCAN_ADDR_BEGIN:begin
                    case(address_index)
                        0:spi_tx<=scan_address[23:16];
                        1:spi_tx<=scan_address[15:8];
                        default:spi_tx<=scan_address[7:0];
                    endcase
                    spi_start<=1;state<=S_SCAN_ADDR_WAIT;
                end
                S_SCAN_ADDR_WAIT:if(spi_done)begin
                    if(address_index==2)begin
                        scan_index<=0;scan_crc<=32'hffffffff;
                        scan_received_crc<=0;scan_commit<=0;scan_magic<=0;
                        scan_sequence<=0;scan_version<=0;
                        state<=S_SCAN_DATA_BEGIN;
                    end else begin address_index<=address_index+1'b1;
                        state<=S_SCAN_ADDR_BEGIN;end
                end
                S_SCAN_DATA_BEGIN:begin
                    spi_tx<=8'h00;spi_start<=1;state<=S_SCAN_DATA_WAIT;
                end
                S_SCAN_DATA_WAIT:if(spi_done)begin
                    if(scan_index<28)scan_crc<=crc32_byte(scan_crc,spi_rx);
                    case(scan_index)
                        0:scan_magic[15:8]<=spi_rx;
                        1:scan_magic[7:0]<=spi_rx;
                        2:scan_version<=spi_rx;
                        4:scan_sequence[15:8]<=spi_rx;
                        5:scan_sequence[7:0]<=spi_rx;
                        28:scan_received_crc[31:24]<=spi_rx;
                        29:scan_received_crc[23:16]<=spi_rx;
                        30:scan_received_crc[15:8]<=spi_rx;
                        31:scan_received_crc[7:0]<=spi_rx;
                        32:scan_commit[31:24]<=spi_rx;
                        33:scan_commit[23:16]<=spi_rx;
                        34:scan_commit[15:8]<=spi_rx;
                    endcase
                    if(scan_index==35)begin
                        flash_cs_n<=1;
                        if(scan_record_valid&&(!scan_best_valid||
                                sequence_newer(scan_sequence,scan_best_sequence)))begin
                            scan_best_valid<=1;scan_best_sequence<=scan_sequence;
                            scan_best_slot<=scan_slot;
                        end
                        state<=S_SCAN_NEXT;
                    end else begin scan_index<=scan_index+1'b1;
                        state<=S_SCAN_DATA_BEGIN;end
                end
                S_SCAN_NEXT:begin
                    if(scan_slot=={SLOT_BITS{1'b1}})state<=S_SCAN_FINISH;
                    else begin scan_slot<=scan_slot+1'b1;state<=S_SCAN_BEGIN;end
                end
                S_SCAN_FINISH:begin
                    restore_next_sequence<=scan_best_valid ?
                        scan_best_sequence+1'b1 : 16'd0;
                    restore_write_slot<=scan_best_valid ?
                        scan_best_slot+1'b1 : {SLOT_BITS{1'b0}};
                    restore_valid<=1;initialized<=1;collect_index<=0;
                    state<=S_COLLECT;
                end
                S_COLLECT:if(program_valid&&program_ready)begin
                    if(collect_index==0)begin
                        if(!collect_address_in_range||program_address[5:0]!=0)begin
                            program_error<=1;state<=S_ERROR;
                        end else begin
                            collect_address<=program_address;
                            record_buffer[0]<=program_data;collect_index<=1;
                        end
                    end else if(program_address!=collect_address+collect_index)begin
                        program_error<=1;state<=S_ERROR;
                    end else begin
                        record_buffer[collect_index]<=program_data;
                        if(collect_index==35)begin
                            operation<=collect_address[11:0]==0 ? OP_ERASE : OP_BODY;
                            collect_index<=36;state<=S_WREN_BEGIN;
                        end else collect_index<=collect_index+1'b1;
                    end
                end
                S_WREN_BEGIN:begin
                    flash_cs_n<=0;spi_tx<=8'h06;spi_start<=1;poll_count<=0;
                    state<=S_WREN_WAIT;
                end
                S_WREN_WAIT:if(spi_done)begin
                    flash_cs_n<=1;state<=S_CMD_BEGIN;
                end
                S_CMD_BEGIN:begin
                    flash_cs_n<=0;spi_tx<=operation==OP_ERASE ? 8'h20 : 8'h02;
                    spi_start<=1;state<=S_CMD_WAIT;
                end
                S_CMD_WAIT:if(spi_done)begin
                    address_index<=0;state<=S_ADDR_BEGIN;
                end
                S_ADDR_BEGIN:begin
                    case(address_index)
                        0:spi_tx<=operation_address[23:16];
                        1:spi_tx<=operation_address[15:8];
                        default:spi_tx<=operation_address[7:0];
                    endcase
                    spi_start<=1;state<=S_ADDR_WAIT;
                end
                S_ADDR_WAIT:if(spi_done)begin
                    if(address_index==2)begin
                        if(operation==OP_ERASE)begin
                            flash_cs_n<=1;state<=S_POLL_BEGIN;
                        end else begin data_index<=0;state<=S_DATA_BEGIN;end
                    end else begin address_index<=address_index+1'b1;
                        state<=S_ADDR_BEGIN;end
                end
                S_DATA_BEGIN:begin
                    spi_tx<=operation==OP_BODY ? record_buffer[data_index] :
                        record_buffer[data_index+32];
                    spi_start<=1;state<=S_DATA_WAIT;
                end
                S_DATA_WAIT:if(spi_done)begin
                    if(data_index==operation_last_index)begin
                        flash_cs_n<=1;state<=S_POLL_BEGIN;
                    end else begin data_index<=data_index+1'b1;
                        state<=S_DATA_BEGIN;end
                end
                S_POLL_BEGIN:begin
                    flash_cs_n<=0;spi_tx<=8'h05;spi_start<=1;
                    state<=S_POLL_CMD_WAIT;
                end
                S_POLL_CMD_WAIT:if(spi_done)state<=S_POLL_DATA_BEGIN;
                S_POLL_DATA_BEGIN:begin
                    spi_tx<=8'h00;spi_start<=1;state<=S_POLL_DATA_WAIT;
                end
                S_POLL_DATA_WAIT:if(spi_done)begin
                    flash_cs_n<=1;
                    if(spi_rx[0])begin
                        if(poll_count==POLL_LIMIT)state<=S_ERROR;
                        else begin poll_count<=poll_count+1'b1;state<=S_POLL_BEGIN;end
                    end else if(operation==OP_ERASE)begin
                        operation<=OP_BODY;state<=S_WREN_BEGIN;
                    end else if(operation==OP_BODY)begin
                        operation<=OP_COMMIT;state<=S_WREN_BEGIN;
                    end else state<=S_DONE;
                end
                S_DONE:begin
                    program_done<=1;collect_index<=0;state<=S_COLLECT;
                end
                default:begin
                    flash_cs_n<=1;program_error<=1;collect_index<=0;
                    state<=S_COLLECT;
                end
            endcase
        end
    end
endmodule

module spi_mode0_byte_master #(
    parameter integer CLK_DIV=2
)(
    input wire clk,input wire rst,input wire start,input wire [7:0] tx_data,
    output reg busy,output reg done,output reg [7:0] rx_data,
    output reg sclk,output reg mosi,input wire miso
);
    localparam integer DIV_BITS=CLK_DIV<2 ? 1 : $clog2(CLK_DIV);
    reg [DIV_BITS-1:0] divider;
    reg [2:0] bit_index;
    always @(posedge clk or posedge rst)begin
        if(rst)begin busy<=0;done<=0;rx_data<=0;sclk<=0;mosi<=0;
            divider<=0;bit_index<=0;end
        else begin
            done<=0;
            if(start&&!busy)begin
                busy<=1;sclk<=0;divider<=0;bit_index<=7;mosi<=tx_data[7];
            end else if(busy)begin
                if(divider==CLK_DIV-1)begin
                    divider<=0;
                    if(!sclk)begin
                        sclk<=1;rx_data[bit_index]<=miso;
                    end else begin
                        sclk<=0;
                        if(bit_index==0)begin busy<=0;done<=1;end
                        else begin bit_index<=bit_index-1'b1;
                            mosi<=tx_data[bit_index-1'b1];end
                    end
                end else divider<=divider+1'b1;
            end
        end
    end
endmodule
