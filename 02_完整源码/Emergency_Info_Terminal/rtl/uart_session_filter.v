`timescale 1ns/1ps

module uart_session_filter(
    input wire clk,input wire rst,input wire command_valid,
    input wire [1:0] command_source,input wire [31:0] command_session,
    input wire [31:0] command_sequence,
    output reg accept_valid,output reg duplicate_valid
);
    reg source_valid [0:3];
    reg [31:0] source_session [0:3];
    reg [31:0] source_sequence [0:3];
    integer i;
    always @(posedge clk or posedge rst) begin
        if(rst) begin
            accept_valid<=0;duplicate_valid<=0;
            for(i=0;i<4;i=i+1) begin
                source_valid[i]<=0;source_session[i]<=0;source_sequence[i]<=0;
            end
        end else begin
            accept_valid<=0;duplicate_valid<=0;
            if(command_valid) begin
                if(!source_valid[command_source] ||
                        source_session[command_source]!=command_session) begin
                    source_valid[command_source]<=1;
                    source_session[command_source]<=command_session;
                    source_sequence[command_source]<=command_sequence;
                    accept_valid<=1;
                end else if(command_sequence>source_sequence[command_source]) begin
                    source_sequence[command_source]<=command_sequence;
                    accept_valid<=1;
                end else duplicate_valid<=1;
            end
        end
    end
endmodule
