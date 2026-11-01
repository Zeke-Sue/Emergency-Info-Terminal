`timescale 1ns/1ps

module museum_ui_control(
    input wire clk, rst,
    input wire [3:0] short_event, long_event,
    output wire previous, next, confirm, back, home, activity
);
    reg [3:0] short_seen, long_seen;
    wire [3:0] s=short_event & ~short_seen;
    wire [3:0] l=long_event & ~long_seen;
    assign home=l[3];
    assign back=s[3] && !home;
    assign confirm=s[2] && !(home || back);
    assign previous=s[0] && !s[1] && !(home || back || confirm);
    assign next=s[1] && !s[0] && !(home || back || confirm);
    assign activity=|short_event || |long_event;
    always @(posedge clk or posedge rst)
        if(rst) begin short_seen<=0;long_seen<=0;end
        else begin short_seen<=short_event;long_seen<=long_event;end
endmodule
