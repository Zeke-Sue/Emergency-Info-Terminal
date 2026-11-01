`timescale 1ns/1ps

module uart_reply_framer #(

    parameter integer CAPTURE_REQUEST=1,
    parameter integer PACKED_PAYLOAD=0
)(
    input wire clk,input wire rst,
    input wire request_valid,output wire request_ready,
    input wire [7:0] request_type,input wire [1:0] request_source,
    input wire [31:0] request_session,input wire [31:0] request_sequence,
    input wire [3:0] result_code,input wire [3:0] finish_reason,
    input wire [23:0] pixel_latency_us,input wire [23:0] audio_latency_us,
    input wire alarm_active,input wire [2:0] alarm_level,
    input wire [3:0] active_count,input wire [7:0] blocked_set,
    input wire [31:0] boot_count,
    input wire [15:0] telemetry_last_line,input wire [15:0] telemetry_max_line,
    input wire [15:0] telemetry_video_underflows,
    input wire [15:0] telemetry_uart_errors,
    input wire [63:0] request_payload,
    output wire byte_valid,input wire byte_ready,output reg [7:0] byte_data
);
    reg busy;
    reg [5:0] position;
    reg [7:0] message_type_q;
    wire [7:0] message_type=CAPTURE_REQUEST ? message_type_q : request_type;
    wire [7:0] payload_length=message_type==8'h82 ? 8'd6 :
        (message_type==8'h90 || message_type==8'h91 ? 8'd8 : 8'd1);
    reg [1:0] source_q;
    reg [31:0] session_q,sequence_q;
    wire [1:0] source=CAPTURE_REQUEST ? source_q : request_source;
    wire [31:0] session=CAPTURE_REQUEST ? session_q : request_session;
    wire [31:0] sequence=CAPTURE_REQUEST ? sequence_q : request_sequence;
    reg [3:0] result,reason,active_count_q;
    reg [23:0] pixel_q,audio_q;
    reg alarm_q;reg [2:0] level_q;reg [7:0] blocked_q;reg [31:0] boot_q;
    reg [15:0] last_line_q,max_line_q,underflow_q,uart_errors_q;
    reg [63:0] packed_q;
    wire [63:0] packed_data=CAPTURE_REQUEST ? packed_q : request_payload;
    wire [3:0] active_result=CAPTURE_REQUEST ? result : result_code;
    wire [3:0] active_reason=CAPTURE_REQUEST ? reason : finish_reason;
    wire [23:0] active_pixel=CAPTURE_REQUEST ? pixel_q : pixel_latency_us;
    wire [23:0] active_audio=CAPTURE_REQUEST ? audio_q : audio_latency_us;
    wire active_alarm=CAPTURE_REQUEST ? alarm_q : alarm_active;
    wire [2:0] active_level=CAPTURE_REQUEST ? level_q : alarm_level;
    wire [3:0] active_count_value=CAPTURE_REQUEST ? active_count_q : active_count;
    wire [7:0] active_blocked=CAPTURE_REQUEST ? blocked_q : blocked_set;
    wire [31:0] active_boot=CAPTURE_REQUEST ? boot_q : boot_count;
    wire [15:0] active_last_line=CAPTURE_REQUEST ? last_line_q : telemetry_last_line;
    wire [15:0] active_max_line=CAPTURE_REQUEST ? max_line_q : telemetry_max_line;
    wire [15:0] active_underflow=CAPTURE_REQUEST ? underflow_q : telemetry_video_underflows;
    wire [15:0] active_uart_errors=CAPTURE_REQUEST ? uart_errors_q : telemetry_uart_errors;
    reg [15:0] crc;
    assign request_ready=!busy;
    assign byte_valid=busy;
    function [15:0] crc16_next;
        input [15:0] current;input [7:0] value;integer b;reg [15:0] work;
        begin work=current^{value,8'h00};
            for(b=0;b<8;b=b+1)work=work[15]?(work<<1)^16'h1021:work<<1;
            crc16_next=work;end
    endfunction
    function [7:0] payload_byte;
        input [7:0] kind;input [3:0] index;
        begin payload_byte=0;
            if(PACKED_PAYLOAD)payload_byte=packed_data>>((7-index[2:0])*8);
            else case(kind)
                8'h81:payload_byte={4'd0,active_result};
                8'h82:case(index)
                    0:payload_byte=active_pixel[23:16];1:payload_byte=active_pixel[15:8];
                    2:payload_byte=active_pixel[7:0];3:payload_byte=active_audio[23:16];
                    4:payload_byte=active_audio[15:8];5:payload_byte=active_audio[7:0];
                endcase
                8'h83:payload_byte={4'd0,active_reason};
                8'h90:case(index)
                    0:payload_byte={active_alarm,4'd0,active_level};
                    1:payload_byte={4'd0,active_count_value};
                    2:payload_byte=active_blocked;
                    3:payload_byte={4'd0,active_result};
                    4:payload_byte=active_boot[31:24];5:payload_byte=active_boot[23:16];
                    6:payload_byte=active_boot[15:8];7:payload_byte=active_boot[7:0];
                endcase
                default:case(index)
                    0:payload_byte=active_last_line[15:8];1:payload_byte=active_last_line[7:0];
                    2:payload_byte=active_max_line[15:8];3:payload_byte=active_max_line[7:0];
                    4:payload_byte=active_underflow[15:8];5:payload_byte=active_underflow[7:0];
                    6:payload_byte=active_uart_errors[15:8];7:payload_byte=active_uart_errors[7:0];
                endcase
            endcase
        end
    endfunction
    wire [5:0] crc_high_position=14+payload_length;
    wire [5:0] final_position=15+payload_length;
    always @* begin
        if(position==0) byte_data=8'ha5;
        else if(position==1) byte_data=8'h5a;
        else if(position==2) byte_data=8'h01;
        else if(position==3) byte_data=message_type;
        else if(position==4) byte_data={6'd0,source};
        else if(position>=5 && position<=8)
            byte_data=session >> ((8-position)*8);
        else if(position>=9 && position<=12)
            byte_data=sequence >> ((12-position)*8);
        else if(position==13) byte_data=payload_length;
        else if(position<crc_high_position)
            byte_data=payload_byte(message_type,position-14);
        else if(position==crc_high_position) byte_data=crc[15:8];
        else byte_data=crc[7:0];
    end
    always @(posedge clk or posedge rst) begin
        if(rst) begin
            busy<=0;position<=0;message_type_q<=0;source_q<=0;
            session_q<=0;sequence_q<=0;result<=0;reason<=0;active_count_q<=0;
            pixel_q<=0;audio_q<=0;alarm_q<=0;level_q<=0;blocked_q<=0;boot_q<=0;crc<=16'hffff;
            last_line_q<=0;max_line_q<=0;underflow_q<=0;uart_errors_q<=0;
            packed_q<=0;
        end else begin
            if(!busy && request_valid) begin
                busy<=1;position<=0;message_type_q<=request_type;source_q<=request_source;
                session_q<=request_session;sequence_q<=request_sequence;result<=result_code;
                reason<=finish_reason;pixel_q<=pixel_latency_us;audio_q<=audio_latency_us;
                alarm_q<=alarm_active;level_q<=alarm_level;active_count_q<=active_count;
                blocked_q<=blocked_set;boot_q<=boot_count;crc<=16'hffff;
                last_line_q<=telemetry_last_line;max_line_q<=telemetry_max_line;
                underflow_q<=telemetry_video_underflows;uart_errors_q<=telemetry_uart_errors;
                packed_q<=request_payload;
            end else if(busy && byte_ready) begin
                if(position>=2 && position<crc_high_position)
                    crc<=crc16_next(crc,byte_data);
                if(position==final_position) begin busy<=0;position<=0;end
                else position<=position+1'b1;
            end
        end
    end
endmodule
