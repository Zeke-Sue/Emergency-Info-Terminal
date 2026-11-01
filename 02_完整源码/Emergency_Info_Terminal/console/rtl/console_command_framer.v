`timescale 1ns/1ps

module console_command_framer(
    input wire clk,input wire rst,
    input wire request_valid,output wire request_ready,
    input wire [1:0] request_action,input wire [1:0] request_source,
    input wire [31:0] request_session,input wire [31:0] request_sequence,
    input wire [15:0] request_event_id,input wire [7:0] request_event_sequence,
    input wire [2:0] request_level,input wire request_drill,
    input wire request_pending,input wire [2:0] request_region,
    input wire request_time_trusted,input wire [15:0] request_remaining_seconds,
    input wire [2:0] request_kind,
    output wire byte_valid,input wire byte_ready,output reg [7:0] byte_data
);
    reg busy;
    reg [5:0] position;
    reg [7:0] message_type,payload_length;
    reg [1:0] source,action;
    reg [31:0] session,sequence;
    reg [15:0] event_id,remaining_seconds;
    reg [7:0] event_sequence;
    reg [2:0] level,region,kind;
    reg drill,pending,time_trusted;
    reg [15:0] crc;
    assign request_ready=!busy;
    assign byte_valid=busy;

    function [15:0] crc16_next;
        input [15:0] current;input [7:0] value;integer b;reg [15:0] work;
        begin
            work=current^{value,8'h00};
            for(b=0;b<8;b=b+1)
                work=work[15] ? (work<<1)^16'h1021 : work<<1;
            crc16_next=work;
        end
    endfunction
    function [7:0] payload_byte;
        input [3:0] index;
        begin
            payload_byte=0;
            case(action)
                0:case(index)
                    0:payload_byte=event_id[15:8];
                    1:payload_byte=event_id[7:0];
                    2:payload_byte=event_sequence;
                    3:payload_byte={5'd0,level};
                    4:payload_byte={5'd0,time_trusted,pending,drill};
                    5:payload_byte={5'd0,region};
                    6:payload_byte=remaining_seconds[15:8];
                    7:payload_byte=remaining_seconds[7:0];
                    8:payload_byte={5'd0,kind};
                endcase
                1:begin
                    if(index==0)payload_byte={5'd0,region};
                    else payload_byte=8'h01;
                end
                2:begin
                    if(index==0)payload_byte={5'd0,region};
                    else payload_byte=8'h00;
                end
                default:begin
                    if(index==0)payload_byte=event_id[15:8];
                    else payload_byte=event_id[7:0];
                end
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
            byte_data=payload_byte(position-14);
        else if(position==crc_high_position) byte_data=crc[15:8];
        else byte_data=crc[7:0];
    end
    always @(posedge clk or posedge rst) begin
        if(rst) begin
            busy<=0;position<=0;message_type<=0;payload_length<=0;
            source<=0;action<=0;session<=0;sequence<=0;event_id<=0;
            event_sequence<=0;level<=0;drill<=0;pending<=0;region<=0;
            time_trusted<=0;remaining_seconds<=0;kind<=0;crc<=16'hffff;
        end else begin
            if(!busy && request_valid) begin
                busy<=1;position<=0;source<=request_source;action<=request_action;
                session<=request_session;sequence<=request_sequence;
                event_id<=request_event_id;event_sequence<=request_event_sequence;
                level<=request_level;drill<=request_drill;pending<=request_pending;
                region<=request_region;time_trusted<=request_time_trusted;
                remaining_seconds<=request_remaining_seconds;kind<=request_kind;
                crc<=16'hffff;
                if(request_action==0) begin
                    message_type<=request_kind==1 ? 8'h0a :
                                  (request_drill ? 8'h03 : 8'h01);
                    payload_length<=9;
                end else if(request_action==3) begin
                    message_type<=8'h02;payload_length<=2;
                end else begin
                    message_type<=8'h0b;payload_length<=2;
                end
            end else if(busy && byte_ready) begin
                if(position>=2 && position<crc_high_position)
                    crc<=crc16_next(crc,byte_data);
                if(position==final_position) begin busy<=0;position<=0;end
                else position<=position+1'b1;
            end
        end
    end
endmodule
