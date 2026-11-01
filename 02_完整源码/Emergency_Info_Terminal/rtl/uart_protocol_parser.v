`timescale 1ns/1ps

module uart_protocol_parser #(
    parameter integer CLK_HZ=25000000,
    parameter integer CERTIFICATE_COUNT=10,
    parameter integer SINGLE_CARD_CONTROL=0,
    parameter integer INTERBYTE_US=5000,
    parameter integer ENABLE_EVENT_SNAPSHOT=0
)(
    input wire clk,
    input wire rst,
    input wire byte_valid,
    input wire [7:0] byte_data,
    input wire us_tick,
    output reg command_valid,
    output reg [2:0] command_opcode,
    output reg [1:0] command_source,
    output reg [2:0] command_kind,
    output reg [15:0] command_event_id,
    output reg [7:0] command_sequence,
    output reg [2:0] command_level,
    output reg command_drill,
    output reg command_pending,
    output reg [2:0] command_region,
    output reg command_time_trusted,
    output reg [15:0] command_remaining_seconds,
    output reg [31:0] command_session,
    output reg [31:0] command_message_sequence,
    output reg [32:0] command_snapshot,
    output reg service_valid,
    output reg [7:0] service_type,
    output reg [15:0] service_batch,
    output reg [95:0] service_payload,
    output reg service_last,
    output reg frame_error,
    output reg crc_error
);
    localparam S_A5=0,S_5A=1,S_HEADER=2,S_PAYLOAD=3,S_CRC_H=4,S_CRC_L=5;
    reg [2:0] state;
    reg [3:0] header_index;
    reg [7:0] message_type;
    reg [7:0] payload_length;
    reg [3:0] payload_index;
    reg [15:0] crc,received_crc;
    reg [12:0] idle_us;
    reg [7:0] payload [0:13];
    function [15:0] crc16_next;
        input [15:0] current;
        input [7:0] value;
        integer bit_number;
        reg [15:0] work;
        begin
            work=current^{value,8'h00};
            for(bit_number=0;bit_number<8;bit_number=bit_number+1)
                work=work[15] ? (work<<1)^16'h1021 : work<<1;
            crc16_next=work;
        end
    endfunction
    always @(posedge clk or posedge rst) begin
        if(rst) begin
            state<=S_A5;header_index<=0;payload_length<=0;payload_index<=0;
            crc<=16'hffff;received_crc<=0;idle_us<=0;command_valid<=0;
            command_opcode<=0;command_source<=0;command_kind<=0;command_event_id<=0;
            command_sequence<=0;command_level<=4;command_drill<=0;command_pending<=0;
            command_region<=0;command_time_trusted<=0;command_remaining_seconds<=0;
            command_session<=0;command_message_sequence<=0;frame_error<=0;crc_error<=0;
            service_valid<=0;service_type<=0;service_batch<=0;
            service_payload<=0;service_last<=0;command_snapshot<=0;
        end else begin
            command_valid<=0;service_valid<=0;service_last<=0;
            frame_error<=0;crc_error<=0;
            if(us_tick && state!=S_A5) begin
                if(idle_us==INTERBYTE_US-1) begin state<=S_A5;idle_us<=0;frame_error<=1;end
                else idle_us<=idle_us+1'b1;
            end
            if(byte_valid) begin
                idle_us<=0;
                case(state)
                    S_A5:if(byte_data==8'ha5) state<=S_5A;
                    S_5A:begin
                        if(byte_data==8'h5a) begin state<=S_HEADER;header_index<=0;crc<=16'hffff;end
                        else state<=byte_data==8'ha5 ? S_5A : S_A5;
                    end
                    S_HEADER:begin
                        crc<=crc16_next(crc,byte_data);
                        case(header_index)
                            0:if(byte_data!=8'h01)begin state<=S_A5;frame_error<=1;end
                            1:message_type<=byte_data;
                            2:begin
                                if(byte_data[7:2]!=0)begin state<=S_A5;frame_error<=1;end
                                else command_source<=byte_data[1:0];
                            end
                            3:command_session[31:24]<=byte_data;
                            4:command_session[23:16]<=byte_data;
                            5:command_session[15:8]<=byte_data;
                            6:command_session[7:0]<=byte_data;
                            7:command_message_sequence[31:24]<=byte_data;
                            8:command_message_sequence[23:16]<=byte_data;
                            9:command_message_sequence[15:8]<=byte_data;
                            10:command_message_sequence[7:0]<=byte_data;
                            11:begin
                                payload_length<=byte_data;
                                payload_index<=0;
                                if(byte_data>14) begin state<=S_A5;frame_error<=1;end
                                else if(byte_data==0) state<=S_CRC_H;
                                else state<=S_PAYLOAD;
                            end
                        endcase
                        if(header_index!=11) header_index<=header_index+1'b1;
                    end
                    S_PAYLOAD:begin
                        payload[payload_index]<=byte_data;
                        crc<=crc16_next(crc,byte_data);
                        if(payload_index+1>=payload_length) state<=S_CRC_H;
                        else payload_index<=payload_index+1'b1;
                    end
                    S_CRC_H:begin received_crc[15:8]<=byte_data;state<=S_CRC_L;end
                    S_CRC_L:begin
                        state<=S_A5;
                        if({received_crc[15:8],byte_data}!=crc) crc_error<=1;
                        else if(ENABLE_EVENT_SNAPSHOT && message_type==8'h26 && payload_length==12 &&
                                payload[0][7]==0 && payload[5][7]==0 && payload[9][7]==0 &&
                                (payload[10]==0||(payload[10][7]&&!payload[10][0])) && payload[11]==0)begin
                            command_valid<=1;command_opcode<=6;
                            command_snapshot<={payload[10],payload[0][6],payload[9][6:0],payload[8],
                                payload[5][6:3],payload[1][1:0],payload[0][5:4],payload[0][0]};
                            command_kind<=payload[1][4:2];command_level<=payload[1][7:5];
                            command_event_id<={payload[2],payload[3]};command_sequence<=payload[4];
                            command_region<=payload[5][2:0];
                            command_drill<=payload[0][1];command_pending<=payload[0][2];
                            command_time_trusted<=payload[0][3];
                            command_remaining_seconds<={payload[6],payload[7]};
                        end else if(!ENABLE_EVENT_SNAPSHOT && (message_type==8'h01 || message_type==8'h03 ||
                                 message_type==8'h0a) && payload_length>=9) begin
                            command_valid<=1;command_opcode<=0;
                            command_event_id<={payload[0],payload[1]};
                            command_sequence<=payload[2];command_level<=payload[3][2:0];
                            command_drill<=payload[4][0] || message_type==8'h03;
                            command_pending<=payload[4][1];command_time_trusted<=payload[4][2];
                            command_region<=payload[5][2:0];
                            command_remaining_seconds<={payload[6],payload[7]};
                            command_kind<=message_type==8'h0a ? 3'd1 : payload[8][2:0];
                        end else if(!ENABLE_EVENT_SNAPSHOT && message_type==8'h02 && payload_length>=2) begin
                            command_valid<=1;command_opcode<=1;
                            command_event_id<={payload[0],payload[1]};
                        end else if(!ENABLE_EVENT_SNAPSHOT && message_type==8'h0b && payload_length==2) begin
                            command_valid<=1;command_opcode<=payload[1][0] ? 3'd3 : 3'd4;
                            command_region<=payload[0][2:0];
                        end else if(message_type==8'h0c && payload_length==6) begin
                            service_valid<=1;service_type<=message_type;
                            service_batch<={payload[0],payload[1]};service_payload<=0;
                            service_payload[31:0]<={payload[2],payload[3],payload[4],payload[5]};
                        end else if(message_type==8'h0d && payload_length==10) begin
                            service_valid<=1;service_type<=message_type;
                            service_batch<={payload[0],payload[1]};service_payload<=0;
                            service_payload[63:0]<={payload[2],payload[3],payload[4],payload[5],
                                payload[6],payload[7],payload[8],payload[9]};
                        end else if(message_type==8'h0b && payload_length==3) begin
                            service_valid<=1;service_type<=message_type;
                            service_batch<={payload[0],payload[1]};service_payload<=0;
                            service_payload[7:0]<=payload[2];
                            service_last<=SINGLE_CARD_CONTROL;
                        end else if(message_type==8'h0e && payload_length==14) begin
                            service_valid<=1;service_type<=message_type;
                            service_batch<={payload[0],payload[1]};
                            service_payload<={payload[2],payload[3],payload[4],payload[5],
                                payload[6],payload[7],payload[8],payload[9],payload[10],
                                payload[11],payload[12],payload[13]};

                            service_last<=payload[13]==8'h20+CERTIFICATE_COUNT;
                        end else if((message_type==8'h20 || message_type==8'h21 ||
                            message_type==8'h22 || message_type==8'h23 ||
                            message_type==8'h24 || message_type==8'h25 ||
                            message_type==8'h27 || message_type==8'h29 || message_type==8'h2a) && payload_length==12) begin
                            service_valid<=1;service_type<=message_type;
                            service_batch<=command_message_sequence[15:0];
                            service_payload<={payload[0],payload[1],payload[2],payload[3],
                                payload[4],payload[5],payload[6],payload[7],payload[8],
                                payload[9],payload[10],payload[11]};
                            service_last<=1;
                        end else frame_error<=1;
                    end
                    default:state<=S_A5;
                endcase
            end
        end
    end
endmodule
