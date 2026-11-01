`timescale 1ns/1ps

module human_daily_follow #(
    parameter integer CLK_HZ=25000000,
    parameter integer WAIT_SECONDS=30,
    parameter integer DWELL_SECONDS=3
)(
    input wire clk,rst,enabled,ready,autoplay,blocked,restart,
    input wire consumed,done,
    output reg next_event
);
    localparam integer CW=$clog2(CLK_HZ*WAIT_SECONDS+1);
    reg [CW-1:0] count;
    reg finished;
    always @(posedge clk or posedge rst) begin
        if(rst)begin count<=0;finished<=0;next_event<=0;end
        else begin
            next_event<=0;
            if(!enabled||!ready||blocked||restart)begin count<=0;finished<=0;end
            else if(done)begin count<=0;finished<=1;end
            else if(autoplay)begin
                if(!finished&&consumed)count<=0;
                else if(count==(finished ? CLK_HZ*DWELL_SECONDS-1 : CLK_HZ*WAIT_SECONDS-1))begin
                    count<=0;finished<=0;next_event<=1;
                end else count<=count+1'b1;
            end
        end
    end
endmodule
