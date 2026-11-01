`timescale 1ns/1ps

module console_log_journal #(
    parameter [23:0] BASE_ADDRESS=24'h7fc000,
    parameter integer SLOT_BITS=8
)(
    input wire clk,input wire rst,
    input wire append_valid,output wire append_ready,
    input wire [1:0] category,input wire [5:0] flags,
    input wire [15:0] b_boot,input wire [31:0] b_ms,
    input wire [31:0] a_boot,input wire [31:0] a_us,
    input wire [7:0] event_type,input wire [55:0] payload,
    output wire program_valid,input wire program_ready,
    output wire [23:0] program_address,output reg [7:0] program_data,
    input wire program_done,input wire program_error,
    input wire restore_valid,input wire [15:0] restore_next_sequence,
    input wire [SLOT_BITS-1:0] restore_write_slot,
    output reg committed_pulse,output reg [15:0] next_sequence,
    output reg [SLOT_BITS-1:0] write_slot,output reg failed_pulse
);
    reg busy,awaiting_transport,restored;
    reg [5:0] byte_index;reg [223:0] body;reg [31:0] crc;
    wire [31:0] a_boot_handoff;
    console_hold_buffer #(.WIDTH(32)) boot_hold(.d(a_boot),.q(a_boot_handoff));
    wire [23:0] slot_offset={{(24-SLOT_BITS){1'b0}},write_slot}<<6;
    assign append_ready=!busy&&restored;
    assign program_valid=busy&&!awaiting_transport;
    assign program_address=BASE_ADDRESS+slot_offset+byte_index;
    function [31:0] crc32_byte;
        input [31:0] current;input [7:0] value;integer k;reg [31:0] work;
        begin work=current^value;
            for(k=0;k<8;k=k+1)
                work=work[0] ? (work>>1)^32'hedb88320 : work>>1;
            crc32_byte=work;
        end
    endfunction
    always @* begin
        if(byte_index<28)program_data=body>>((27-byte_index)*8);
        else case(byte_index)
            28:program_data=~crc[31:24];29:program_data=~crc[23:16];
            30:program_data=~crc[15:8];31:program_data=~crc[7:0];
            32:program_data=8'h43;33:program_data=8'h4d;
            34:program_data=8'h49;default:program_data=8'h54;
        endcase
    end
    always @(posedge clk or posedge rst)begin
        if(rst)begin busy<=0;awaiting_transport<=0;restored<=0;
            byte_index<=0;body<=0;crc<=32'hffffffff;
            committed_pulse<=0;failed_pulse<=0;next_sequence<=0;write_slot<=0;end
        else begin
            committed_pulse<=0;failed_pulse<=0;
            if(restore_valid&&!busy)begin
                next_sequence<=restore_next_sequence;
                write_slot<=restore_write_slot;
                restored<=1;
            end
            if(append_valid&&append_ready)begin
                body<={16'h4c47,8'h01,category,flags,next_sequence,b_boot,b_ms,
                    a_boot_handoff,a_us,event_type,payload};
                crc<=32'hffffffff;byte_index<=0;busy<=1;awaiting_transport<=0;
            end else if(program_valid&&program_ready)begin
                if(byte_index<28)crc<=crc32_byte(crc,program_data);
                if(byte_index==35)awaiting_transport<=1;
                else byte_index<=byte_index+1'b1;
            end else if(awaiting_transport&&program_done)begin
                busy<=0;awaiting_transport<=0;committed_pulse<=1;
                next_sequence<=next_sequence+1'b1;write_slot<=write_slot+1'b1;
            end else if(awaiting_transport&&program_error)begin
                busy<=0;awaiting_transport<=0;failed_pulse<=1;
            end
        end
    end
endmodule

module console_log_record_validator(
    input wire clk,input wire rst,input wire start,
    input wire byte_valid,input wire [7:0] byte_data,input wire finish,
    output reg done,output reg record_valid,output reg [15:0] sequence
);
    reg [5:0] index;reg [31:0] crc,received_crc,commit;
    reg [15:0] magic;reg [7:0] version;
    function [31:0] crc32_byte;
        input [31:0] current;input [7:0] value;integer k;reg [31:0] work;
        begin work=current^value;
            for(k=0;k<8;k=k+1)
                work=work[0] ? (work>>1)^32'hedb88320 : work>>1;
            crc32_byte=work;
        end
    endfunction
    always @(posedge clk or posedge rst)begin
        if(rst)begin index<=0;crc<=32'hffffffff;received_crc<=0;commit<=0;
            magic<=0;version<=0;sequence<=0;done<=0;record_valid<=0;end
        else begin
            done<=0;
            if(start)begin index<=0;crc<=32'hffffffff;received_crc<=0;
                commit<=0;magic<=0;version<=0;sequence<=0;record_valid<=0;end
            else if(byte_valid)begin
                if(index<28)crc<=crc32_byte(crc,byte_data);
                case(index)
                    0:magic[15:8]<=byte_data;1:magic[7:0]<=byte_data;
                    2:version<=byte_data;
                    4:sequence[15:8]<=byte_data;5:sequence[7:0]<=byte_data;
                    28:received_crc[31:24]<=byte_data;
                    29:received_crc[23:16]<=byte_data;
                    30:received_crc[15:8]<=byte_data;
                    31:received_crc[7:0]<=byte_data;
                    32:commit[31:24]<=byte_data;33:commit[23:16]<=byte_data;
                    34:commit[15:8]<=byte_data;35:commit[7:0]<=byte_data;
                endcase
                if(index<35)index<=index+1'b1;
            end
            if(finish)begin
                done<=1;record_valid<=index==35&&magic==16'h4c47&&version==1&&
                    received_crc==~crc&&commit==32'h434d4954;
            end
        end
    end
endmodule
