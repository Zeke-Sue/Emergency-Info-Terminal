`timescale 1ns/1ps

module uart_single_session_filter(
    input wire clk,input wire rst,input wire command_valid,
    input wire [1:0] command_source,input wire [31:0] command_session,
    input wire [31:0] command_sequence,
    output reg accept_valid,output reg duplicate_valid,output reg session_changed
);
    reg peer_valid;
    reg [1:0] peer_source;
    reg [31:0] peer_session,peer_sequence;
    always @(posedge clk or posedge rst)begin
        if(rst)begin
            peer_valid<=0;peer_source<=0;peer_session<=0;peer_sequence<=0;
            accept_valid<=0;duplicate_valid<=0;session_changed<=0;
        end else begin
            accept_valid<=0;duplicate_valid<=0;session_changed<=0;
            if(command_valid)begin
                if(!peer_valid||peer_source!=command_source||peer_session!=command_session)begin
                    peer_valid<=1;peer_source<=command_source;
                    peer_session<=command_session;peer_sequence<=command_sequence;
                    accept_valid<=1;session_changed<=1;
                end else if(command_sequence>peer_sequence)begin
                    peer_sequence<=command_sequence;accept_valid<=1;
                end else duplicate_valid<=1;
            end
        end
    end
endmodule
