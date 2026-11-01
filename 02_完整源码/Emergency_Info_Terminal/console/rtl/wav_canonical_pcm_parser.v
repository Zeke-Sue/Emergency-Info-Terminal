`timescale 1ns/1ps

module wav_canonical_pcm_parser #(
    parameter integer COMPUTE_CRC=1
)(
    input wire clk,rst,file_start,byte_valid,input wire [7:0] byte_data,
    output wire byte_ready,input wire file_end,sample_ready,
    output reg data_start,output wire data_byte_valid,output wire [7:0] data_byte,
    output reg sample_valid,output reg signed [15:0] sample,
    output reg data_finish,parse_done,file_valid,output reg [3:0] error_reason,
    output wire [31:0] data_length,sample_count,container_length,container_crc32
);
    localparam HEADER=0,DATA=1,FINISH=2,TRAIL=3,ERROR=4;
    reg [2:0] state;
    reg active,end_pending,header_good,half_sample;
    reg [5:0] index;
    reg [31:0] riff_size,crc;
    reg [23:0] length,remaining;
    reg [22:0] samples;
    reg [24:0] total;
    reg [7:0] low_byte;
    reg [3:0] crc_left;
    reg [7:0] expected_header;
    wire take=byte_valid&&byte_ready;
    assign byte_ready=active&&!end_pending&&crc_left==0&&state!=FINISH&&
        (!sample_valid||sample_ready);
    assign data_byte_valid=take&&state==DATA;
    assign data_byte=byte_data;
    assign data_length={8'd0,length};
    assign sample_count={9'd0,samples};
    assign container_length={7'd0,total};
    assign container_crc32=~crc;
    always @* begin
        expected_header=0;
        case(index)
            0:expected_header="R";1:expected_header="I";
            2,3:expected_header="F";8:expected_header="W";
            9:expected_header="A";10:expected_header="V";11:expected_header="E";
            12:expected_header="f";13:expected_header="m";14:expected_header="t";
            15:expected_header=" ";16,34:expected_header=16;
            20,22,30:expected_header=1;
            24:expected_header=8'h80;25:expected_header=8'hbb;
            28:expected_header=0;29:expected_header=8'h77;
            32:expected_header=2;36:expected_header="d";
            37,39:expected_header="a";38:expected_header="t";
            default:expected_header=0;
        endcase
    end
    always @(posedge clk or posedge rst)begin
        if(rst)begin
            state<=HEADER;active<=0;end_pending<=0;header_good<=1;half_sample<=0;
            index<=0;riff_size<=0;crc<=32'hffffffff;crc_left<=0;
            length<=0;remaining<=0;samples<=0;total<=0;low_byte<=0;
            data_start<=0;sample_valid<=0;sample<=0;data_finish<=0;
            parse_done<=0;file_valid<=0;error_reason<=0;
        end else begin
            data_start<=0;data_finish<=0;parse_done<=0;
            if(sample_valid&&sample_ready)sample_valid<=0;
            if(file_start)begin
                state<=HEADER;active<=1;end_pending<=0;header_good<=1;half_sample<=0;
                index<=0;riff_size<=0;crc<=32'hffffffff;crc_left<=0;
                length<=0;remaining<=0;samples<=0;total<=0;
                sample_valid<=0;file_valid<=0;error_reason<=0;
            end else if(active)begin
                if(file_end)end_pending<=1;
                if(crc_left!=0)begin
                    crc<=crc[0] ? (crc>>1)^32'hedb88320 : crc>>1;
                    crc_left<=crc_left-1'b1;
                end
                if(state==FINISH&&!sample_valid&&crc_left==0)begin
                    data_finish<=1;state<=TRAIL;
                end
                if(end_pending&&crc_left==0&&!sample_valid&&state!=FINISH)begin
                    active<=0;parse_done<=1;
                    file_valid<=state==TRAIL&&error_reason==0&&
                        {7'd0,total}==riff_size+32'd8;
                    if(error_reason==0&&(state!=TRAIL||{7'd0,total}!=riff_size+32'd8))
                        error_reason<=2;
                end
                if(take)begin
                    if(COMPUTE_CRC)begin crc<=crc^{24'd0,byte_data};crc_left<=8;end
                    if(&total)begin state<=ERROR;error_reason<=2;end
                    else total<=total+1'b1;
                    case(state)
                        HEADER:begin
                            case(index)
                                4:riff_size[7:0]<=byte_data;
                                5:riff_size[15:8]<=byte_data;
                                6:riff_size[23:16]<=byte_data;
                                7:riff_size[31:24]<=byte_data;
                                40:length[7:0]<=byte_data;
                                41:length[15:8]<=byte_data;
                                42:length[23:16]<=byte_data;
                                default:if(byte_data!=expected_header)header_good<=0;
                            endcase
                            index<=index+1'b1;
                            if(index==43)begin
                                if(!header_good||byte_data!=0||length==0||length[0]||
                                        riff_size!={8'd0,length}+32'd36)begin
                                    state<=ERROR;error_reason<=3;
                                end else begin state<=DATA;remaining<=length;data_start<=1;end
                            end
                        end
                        DATA:begin
                            remaining<=remaining-1'b1;half_sample<=!half_sample;
                            if(!half_sample)low_byte<=byte_data;
                            else begin
                                sample<={byte_data,low_byte};sample_valid<=1;samples<=samples+1'b1;
                            end
                            if(remaining==1)state<=FINISH;
                        end
                        TRAIL:begin state<=ERROR;error_reason<=2;end
                        default:begin end
                    endcase
                end
            end
        end
    end
endmodule
