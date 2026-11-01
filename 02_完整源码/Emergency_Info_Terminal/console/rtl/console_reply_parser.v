`timescale 1ns/1ps

module console_reply_parser #(
    parameter integer INTERBYTE_US=5000
)(
    input wire clk,input wire rst,input wire byte_valid,input wire [7:0] byte_data,
    input wire us_tick,
    output reg ack_valid,output reg [3:0] ack_result,
    output reg [31:0] ack_session,output reg [31:0] ack_sequence,
    output reg heartbeat_valid,output reg remote_alarm,
    output reg [2:0] remote_level,output reg [3:0] remote_active_count,
    output reg [7:0] remote_blocked_set,
    output reg [31:0] remote_boot_count,
    output reg [31:0] remote_session,
    output reg telemetry_valid,output reg [15:0] telemetry_last_line,
    output reg [15:0] telemetry_max_line,
    output reg [15:0] telemetry_video_underflows,
    output reg [15:0] telemetry_uart_errors,
    output reg latency_valid,output reg [23:0] pixel_latency_us,
    output reg [23:0] audio_latency_us,
    output reg finish_valid,output reg [3:0] finish_reason,
    output reg frame_error,output reg crc_error
);
    localparam S_A5=0,S_5A=1,S_HEADER=2,S_PAYLOAD=3,S_CRC_H=4,S_CRC_L=5;
    reg [2:0] state;
    reg [3:0] header_index;
    reg [7:0] message_type,payload_length,payload_index;
    reg [1:0] source;
    reg [31:0] session,sequence;

    wire [31:0] session_delay,session_handoff;
    genvar session_bit;
    generate for(session_bit=0;session_bit<32;session_bit=session_bit+1)begin: session_hold
        AL_MAP_LUT1 #(.INIT(2'b10),.EQN("(A)")) first(
            .a(session[session_bit]),.o(session_delay[session_bit]));
        AL_MAP_LUT1 #(.INIT(2'b10),.EQN("(A)")) second(
            .a(session_delay[session_bit]),.o(session_handoff[session_bit]));
    end endgenerate
    reg [15:0] crc,received_crc;
    reg [12:0] idle_us;
    reg [7:0] payload [0:7];
    wire [31:0] payload_tail_handoff;
    console_hold_buffer #(.WIDTH(32)) payload_hold(
        .d({payload[4],payload[5],payload[6],payload[7]}),.q(payload_tail_handoff));
    function [15:0] crc16_next;
        input [15:0] current;input [7:0] value;integer b;reg [15:0] work;
        begin
            work=current^{value,8'h00};
            for(b=0;b<8;b=b+1)
                work=work[15] ? (work<<1)^16'h1021 : work<<1;
            crc16_next=work;
        end
    endfunction
    always @(posedge clk or posedge rst) begin
        if(rst) begin
            state<=S_A5;header_index<=0;message_type<=0;payload_length<=0;
            payload_index<=0;source<=0;session<=0;sequence<=0;crc<=16'hffff;
            received_crc<=0;idle_us<=0;ack_valid<=0;ack_result<=0;
            ack_session<=0;ack_sequence<=0;heartbeat_valid<=0;remote_alarm<=0;
            remote_level<=0;remote_active_count<=0;remote_blocked_set<=0;
            remote_boot_count<=0;remote_session<=0;
            telemetry_valid<=0;telemetry_last_line<=0;telemetry_max_line<=0;
            telemetry_video_underflows<=0;telemetry_uart_errors<=0;
            latency_valid<=0;pixel_latency_us<=0;audio_latency_us<=0;
            finish_valid<=0;finish_reason<=0;frame_error<=0;crc_error<=0;
        end else begin
            ack_valid<=0;heartbeat_valid<=0;telemetry_valid<=0;
            latency_valid<=0;finish_valid<=0;
            frame_error<=0;crc_error<=0;
            if(us_tick && state!=S_A5) begin
                if(idle_us==INTERBYTE_US-1) begin
                    state<=S_A5;idle_us<=0;frame_error<=1;
                end else idle_us<=idle_us+1'b1;
            end
            if(byte_valid) begin
                idle_us<=0;
                case(state)
                    S_A5:if(byte_data==8'ha5)state<=S_5A;
                    S_5A:begin
                        if(byte_data==8'h5a)begin
                            state<=S_HEADER;header_index<=0;crc<=16'hffff;
                        end else state<=byte_data==8'ha5 ? S_5A : S_A5;
                    end
                    S_HEADER:begin
                        crc<=crc16_next(crc,byte_data);
                        case(header_index)
                            1:message_type<=byte_data;
                            2:source<=byte_data[1:0];
                            3:session[31:24]<=byte_data;
                            4:session[23:16]<=byte_data;
                            5:session[15:8]<=byte_data;
                            6:session[7:0]<=byte_data;
                            7:sequence[31:24]<=byte_data;
                            8:sequence[23:16]<=byte_data;
                            9:sequence[15:8]<=byte_data;
                            10:sequence[7:0]<=byte_data;
                            11:begin
                                payload_length<=byte_data;payload_index<=0;
                                if(byte_data>8)begin state<=S_A5;frame_error<=1;end
                                else if(byte_data==0)state<=S_CRC_H;
                                else state<=S_PAYLOAD;
                            end
                        endcase
                        if(header_index!=11)header_index<=header_index+1'b1;
                    end
                    S_PAYLOAD:begin
                        payload[payload_index]<=byte_data;
                        crc<=crc16_next(crc,byte_data);
                        if(payload_index+1>=payload_length)state<=S_CRC_H;
                        else payload_index<=payload_index+1'b1;
                    end
                    S_CRC_H:begin received_crc[15:8]<=byte_data;state<=S_CRC_L;end
                    S_CRC_L:begin
                        state<=S_A5;
                        if({received_crc[15:8],byte_data}!=crc)crc_error<=1;
                        else case(message_type)
                            8'h81:if(payload_length>=1)begin
                                ack_valid<=1;ack_result<=payload[0][3:0];
                                ack_session<=session_handoff;ack_sequence<=sequence;
                            end else frame_error<=1;
                            8'h82:if(payload_length>=6)begin
                                latency_valid<=1;
                                pixel_latency_us<={payload[0],payload[1],payload[2]};
                                audio_latency_us<={payload[3],payload[4],payload[5]};
                            end else frame_error<=1;
                            8'h83:if(payload_length>=1)begin
                                finish_valid<=1;finish_reason<=payload[0][3:0];
                            end else frame_error<=1;
                            8'h90:if(payload_length>=4)begin
                                remote_session<=session_handoff;
                                heartbeat_valid<=1;remote_alarm<=payload[0][7];
                                remote_level<=payload[0][2:0];
                                remote_active_count<=payload[1][3:0];
                                remote_blocked_set<=payload[2];
                                if(payload_length>=8)
                                    remote_boot_count<=payload_tail_handoff;
                            end else frame_error<=1;
                            8'h91:if(payload_length==8)begin
                                telemetry_valid<=1;
                                telemetry_last_line<={payload[0],payload[1]};
                                telemetry_max_line<={payload[2],payload[3]};
                                telemetry_video_underflows<=payload_tail_handoff[31:16];
                                telemetry_uart_errors<=payload_tail_handoff[15:0];
                            end else frame_error<=1;
                            default:frame_error<=1;
                        endcase
                    end
                    default:state<=S_A5;
                endcase
            end
        end
    end
endmodule
