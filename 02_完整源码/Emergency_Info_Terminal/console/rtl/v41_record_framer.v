`timescale 1ns/1ps

module v41_record_framer(
    input wire clk,input wire rst,
    input wire msg_valid,output wire msg_ready,
    input wire [7:0] msg_type,input wire [15:0] msg_batch,
    input wire [95:0] msg_payload,input wire msg_last,
    output wire byte_valid,input wire byte_ready,output reg [7:0] byte_data
);
    reg busy;reg [5:0] position;reg [7:0] message_type,payload_length;
    reg [15:0] batch;reg [95:0] payload;reg [31:0] sequence;
    reg [15:0] crc;
    assign msg_ready=!busy;
    assign byte_valid=busy;
    function [15:0] crc16_next;
        input [15:0] current;input [7:0] value;integer b;reg [15:0] work;
        begin work=current^{value,8'h00};
            for(b=0;b<8;b=b+1)work=work[15]?(work<<1)^16'h1021:work<<1;
            crc16_next=work;end
    endfunction
    function [7:0] payload_byte;
        input [3:0] index;
        begin
            if(index==0)payload_byte=batch[15:8];
            else if(index==1)payload_byte=batch[7:0];
            else case(message_type)
                8'h0c:payload_byte=payload >> ((5-index)*8);
                8'h0d:payload_byte=payload >> ((9-index)*8);
                8'h0b:payload_byte=payload[7:0];
                default:payload_byte=payload >> ((13-index)*8);
            endcase
        end
    endfunction
    wire [5:0] crc_high_position=14+payload_length;
    wire [5:0] final_position=15+payload_length;
    always @* begin
        if(position==0)byte_data=8'ha5;
        else if(position==1)byte_data=8'h5a;
        else if(position==2)byte_data=8'h01;
        else if(position==3)byte_data=message_type;
        else if(position==4)byte_data=8'h02;
        else if(position>=5&&position<=8)byte_data=32'hb0410001>>((8-position)*8);
        else if(position>=9&&position<=12)byte_data=sequence>>((12-position)*8);
        else if(position==13)byte_data=payload_length;
        else if(position<crc_high_position)byte_data=payload_byte(position-14);
        else if(position==crc_high_position)byte_data=crc[15:8];
        else byte_data=crc[7:0];
    end
    always @(posedge clk or posedge rst)begin
        if(rst)begin busy<=0;position<=0;message_type<=0;payload_length<=0;
            batch<=0;payload<=0;sequence<=1;crc<=16'hffff;end
        else if(!busy&&msg_valid)begin
            busy<=1;position<=0;message_type<=msg_type;batch<=msg_batch;
            payload<=msg_payload;crc<=16'hffff;sequence<=sequence+1'b1;
            if(msg_type==8'h0c)payload_length<=6;
            else if(msg_type==8'h0d)payload_length<=10;
            else if(msg_type==8'h0b)payload_length<=3;
            else payload_length<=14;
        end else if(busy&&byte_ready)begin
            if(position>=2&&position<crc_high_position)
                crc<=crc16_next(crc,byte_data);
            if(position==final_position)begin busy<=0;position<=0;end
            else position<=position+1'b1;
        end
    end
endmodule
