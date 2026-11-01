`timescale 1ns/1ps

module config_route_stream_parser(
    input wire clk,input wire rst,input wire file_start,
    input wire byte_valid,input wire [7:0] byte_data,output wire byte_ready,
    input wire cfg_ready,
    input wire file_end,
    output reg cfg_write,output reg [7:0] cfg_blocked_key,
    output reg [31:0] cfg_segment_mask,output reg [31:0] cfg_direction_mask,
    output reg [2:0] cfg_exit,output reg [1:0] cfg_status,
    output reg cfg_commit,output reg cfg_crc_ok,output reg cfg_checked,
    output reg cfg_assets_match,output reg [15:0] cfg_version,
    output reg [31:0] cfg_crc32,
    output reg done,output reg valid,output reg [3:0] error_reason
);
    localparam S_HEADER=0,S_HEADER_CHECK=1,S_PAYLOAD=2,S_WAIT_END=3,S_FAILED=4;
    localparam [31:0] EXPECTED_SIZE=32+256*9;
    reg [2:0] state;
    reg active;
    reg [5:0] header_index;
    reg [3:0] record_byte;
    reg [8:0] records_seen;
    reg [31:0] magic,total_size,payload_crc,route_crc,segment_crc,flags,record_count;
    reg [15:0] version,header_size;
    reg [31:0] crc;
    reg [31:0] segment_work,direction_work;
    assign byte_ready=active&&(state==S_HEADER||
        (state==S_PAYLOAD&&(record_byte!=8||cfg_ready)));
    function [31:0] crc32_byte;
        input [31:0] current;input [7:0] value;integer k;reg [31:0] work;
        begin work=current^value;
            for(k=0;k<8;k=k+1)
                work=work[0] ? (work>>1)^32'hedb88320 : work>>1;
            crc32_byte=work;
        end
    endfunction
    always @(posedge clk or posedge rst)begin
        if(rst)begin
            state<=S_HEADER;active<=0;header_index<=0;record_byte<=0;
            records_seen<=0;magic<=0;total_size<=0;payload_crc<=0;route_crc<=0;
            segment_crc<=0;flags<=0;record_count<=0;version<=0;header_size<=0;
            crc<=32'hffffffff;segment_work<=0;direction_work<=0;
            cfg_write<=0;cfg_blocked_key<=0;cfg_segment_mask<=0;
            cfg_direction_mask<=0;cfg_exit<=0;cfg_status<=0;cfg_commit<=0;
            cfg_crc_ok<=0;cfg_checked<=0;cfg_assets_match<=0;
            cfg_version<=0;cfg_crc32<=0;done<=0;valid<=0;error_reason<=0;
        end else begin
            cfg_write<=0;cfg_commit<=0;done<=0;
            if(file_start)begin
                state<=S_HEADER;active<=1;header_index<=0;record_byte<=0;
                records_seen<=0;magic<=0;total_size<=0;payload_crc<=0;route_crc<=0;
                segment_crc<=0;flags<=0;record_count<=0;version<=0;header_size<=0;
                crc<=32'hffffffff;valid<=0;error_reason<=0;cfg_crc_ok<=0;
                cfg_checked<=0;cfg_assets_match<=0;
            end else begin
                if(byte_valid&&byte_ready)begin
                    if(state==S_HEADER)begin
                        case(header_index)
                            0,1,2,3:magic<={magic[23:0],byte_data};
                            4:version[7:0]<=byte_data;5:version[15:8]<=byte_data;
                            6:header_size[7:0]<=byte_data;7:header_size[15:8]<=byte_data;
                            8,9,10,11:total_size<={byte_data,total_size[31:8]};
                            12,13,14,15:payload_crc<={byte_data,payload_crc[31:8]};
                            16,17,18,19:route_crc<={byte_data,route_crc[31:8]};
                            20,21,22,23:segment_crc<={byte_data,segment_crc[31:8]};
                            24,25,26,27:flags<={byte_data,flags[31:8]};
                            28,29,30,31:record_count<={byte_data,record_count[31:8]};
                        endcase
                        if(header_index==31)begin state<=S_HEADER_CHECK;header_index<=0;end
                        else header_index<=header_index+1'b1;
                    end else begin
                        crc<=crc32_byte(crc,byte_data);
                        case(record_byte)
                            0:segment_work[7:0]<=byte_data;
                            1:segment_work[15:8]<=byte_data;
                            2:segment_work[23:16]<=byte_data;
                            3:segment_work[31:24]<=byte_data;
                            4:direction_work[7:0]<=byte_data;
                            5:direction_work[15:8]<=byte_data;
                            6:direction_work[23:16]<=byte_data;
                            7:direction_work[31:24]<=byte_data;
                            8:begin
                                cfg_write<=1;cfg_blocked_key<=records_seen[7:0];
                                cfg_segment_mask<=segment_work;
                                cfg_direction_mask<=direction_work;
                                cfg_exit<=byte_data[2:0];cfg_status<=byte_data[4:3];
                                records_seen<=records_seen+1'b1;record_byte<=0;
                                if(records_seen==255)state<=S_WAIT_END;
                            end
                        endcase
                        if(record_byte!=8)record_byte<=record_byte+1'b1;
                    end
                end
                if(state==S_HEADER_CHECK)begin
                    if(magic!=32'h45495434)begin state<=S_FAILED;error_reason<=1;end
                    else if(version!=16'h4101||header_size!=32)begin
                        state<=S_FAILED;error_reason<=2;
                    end else if(total_size!=EXPECTED_SIZE||record_count!=256)begin
                        state<=S_FAILED;error_reason<=3;
                    end else begin
                        state<=S_PAYLOAD;cfg_version<=version;cfg_crc32<=route_crc;
                        cfg_checked<=flags[0];cfg_assets_match<=flags[1];
                    end
                end
                if(file_end&&active)begin
                    active<=0;done<=1;
                    if(state!=S_WAIT_END||records_seen!=256||record_byte!=0)begin
                        valid<=0;error_reason<=4;
                    end else if(~crc!=payload_crc||payload_crc!=route_crc)begin
                        valid<=0;cfg_crc_ok<=0;error_reason<=5;
                    end else if(!cfg_checked||!cfg_assets_match)begin
                        valid<=0;cfg_crc_ok<=1;error_reason<=6;
                    end else begin
                        valid<=1;cfg_crc_ok<=1;cfg_commit<=1;error_reason<=0;
                    end
                end
            end
        end
    end
endmodule
