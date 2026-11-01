`timescale 1ns/1ps

module v41_event_log_ring #(
    parameter integer DEPTH=32,parameter integer ADDR_BITS=5
)(
    input wire clk,input wire rst,
    input wire push_valid,input wire [7:0] push_type,
    input wire [63:0] push_data,input wire [23:0] timestamp,
    input wire fetch_valid,input wire [15:0] fetch_sequence,
    output reg fetch_done,output reg fetch_found,
    output reg [7:0] fetch_type,output reg [63:0] fetch_data,
    output reg [23:0] fetch_timestamp,
    output reg [15:0] oldest_sequence,output reg [15:0] next_sequence,
    output reg [15:0] retained_count,output reg [31:0] overwritten_count
);
    reg [7:0] type_mem [0:DEPTH-1];reg [63:0] data_mem [0:DEPTH-1];
    reg [23:0] time_mem [0:DEPTH-1];reg [15:0] seq_mem [0:DEPTH-1];
    reg [ADDR_BITS-1:0] write_ptr;integer j;reg [ADDR_BITS-1:0] lookup_ptr;
    always @* lookup_ptr=fetch_sequence[ADDR_BITS-1:0];
    always @(posedge clk or posedge rst)begin
        if(rst)begin
            write_ptr<=0;oldest_sequence<=0;next_sequence<=0;retained_count<=0;
            overwritten_count<=0;fetch_done<=0;fetch_found<=0;fetch_type<=0;
            fetch_data<=0;fetch_timestamp<=0;
            for(j=0;j<DEPTH;j=j+1)begin type_mem[j]<=0;data_mem[j]<=0;time_mem[j]<=0;seq_mem[j]<=0;end
        end else begin
            fetch_done<=0;
            if(push_valid)begin
                type_mem[write_ptr]<=push_type;data_mem[write_ptr]<=push_data;
                time_mem[write_ptr]<=timestamp;seq_mem[write_ptr]<=next_sequence;
                write_ptr<=write_ptr+1'b1;next_sequence<=next_sequence+1'b1;
                if(retained_count<DEPTH)retained_count<=retained_count+1'b1;
                else begin oldest_sequence<=oldest_sequence+1'b1;overwritten_count<=overwritten_count+1'b1;end
            end
            if(fetch_valid)begin
                fetch_done<=1;
                fetch_found<=(fetch_sequence>=oldest_sequence)&&(fetch_sequence<next_sequence)&&
                    (seq_mem[lookup_ptr]==fetch_sequence);
                fetch_type<=type_mem[lookup_ptr];fetch_data<=data_mem[lookup_ptr];
                fetch_timestamp<=time_mem[lookup_ptr];
            end
        end
    end
endmodule
