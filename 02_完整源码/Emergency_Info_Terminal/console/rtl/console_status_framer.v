`timescale 1ns/1ps

module console_status_framer #(
    parameter [31:0] SESSION_ID=32'hb5200001,
    parameter integer DYNAMIC_TYPE=0,
    parameter integer EXTERNAL_IDENTITY=0,

    parameter integer STABLE_EXTERNAL_SESSION=0
)(
    input wire clk,input wire rst,
    input wire request_valid,output wire request_ready,
    input wire [95:0] request_payload,
    input wire [7:0] request_type,
    input wire [31:0] request_session,request_sequence,
    output wire byte_valid,input wire byte_ready,output reg [7:0] byte_data
);
    reg busy;
    reg [4:0] position;
    reg [31:0] sequence;
    reg [31:0] session;
    reg [95:0] payload;
    wire [95:0] payload_handoff;
    console_hold_buffer #(.WIDTH(96)) payload_hold(
        .d(request_payload),.q(payload_handoff));
    reg [15:0] crc;
    reg [7:0] message_type;
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
            case(index)
                0:payload_byte=payload[95:88]; 1:payload_byte=payload[87:80];
                2:payload_byte=payload[79:72]; 3:payload_byte=payload[71:64];
                4:payload_byte=payload[63:56]; 5:payload_byte=payload[55:48];
                6:payload_byte=payload[47:40]; 7:payload_byte=payload[39:32];
                8:payload_byte=payload[31:24]; 9:payload_byte=payload[23:16];
                10:payload_byte=payload[15:8]; default:payload_byte=payload[7:0];
            endcase
        end
    endfunction
    always @* begin
        if(position==0)byte_data=8'ha5;
        else if(position==1)byte_data=8'h5a;
        else if(position==2)byte_data=8'h01;
        else if(position==3)byte_data=message_type;
        else if(position==4)byte_data=8'h02;
        else if(position>=5&&position<=8)
            byte_data=(EXTERNAL_IDENTITY ?
                (STABLE_EXTERNAL_SESSION ? request_session : session) : SESSION_ID)>>((8-position)*8);
        else if(position>=9&&position<=12)
            byte_data=sequence>>((12-position)*8);
        else if(position==13)byte_data=8'd12;
        else if(position<=25)byte_data=payload_byte(position-14);
        else if(position==26)byte_data=crc[15:8];
        else byte_data=crc[7:0];
    end
    always @(posedge clk or posedge rst)begin
        if(rst)begin busy<=0;position<=0;sequence<=0;session<=0;payload<=0;crc<=16'hffff;message_type<=8'h20;end
        else if(!busy&&request_valid)begin
            busy<=1;position<=0;
            sequence<=EXTERNAL_IDENTITY ? request_sequence : sequence+1'b1;
            if(!STABLE_EXTERNAL_SESSION)session<=request_session;
            payload<=payload_handoff;crc<=16'hffff;
            message_type<=DYNAMIC_TYPE ? request_type : 8'h20;
        end else if(busy&&byte_ready)begin
            if(position>=2&&position<=25)crc<=crc16_next(crc,byte_data);
            if(position==27)begin busy<=0;position<=0;end
            else position<=position+1'b1;
        end
    end
endmodule
