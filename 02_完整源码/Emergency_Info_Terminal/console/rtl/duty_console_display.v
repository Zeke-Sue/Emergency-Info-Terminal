`timescale 1ns/1ps
module duty_console_display #(
    parameter integer SCAN_DIV=25000
)(
    input wire clk,input wire rst,input wire link_alive,input wire ack_pending,
    input wire error_latched,input wire permission_denied,input wire remote_alarm,
    input wire [1:0] role,input wire [1:0] action,input wire [2:0] level,
    input wire [2:0] region,input wire [3:0] ack_result,
    output wire [5:0] seg_sel,output reg [7:0] seg_data
);
    localparam integer DIV_BITS=SCAN_DIV<2 ? 1 : $clog2(SCAN_DIV);
    reg [DIV_BITS-1:0] divider;
    reg [2:0] digit;
    reg [3:0] value;
    assign seg_sel=~(6'b000001<<digit);
    always @(posedge clk or posedge rst)begin
        if(rst)begin divider<=0;digit<=0;end
        else if(divider==SCAN_DIV-1)begin
            divider<=0;digit<=digit==5 ? 0 : digit+1'b1;
        end else divider<=divider+1'b1;
    end
    always @* begin
        case(digit)
            0:value={1'b0,region};
            1:value={1'b0,level};
            2:value={2'b00,action};
            3:value={2'b00,role};
            4:value=ack_pending ? 4'hd : ack_result;
            default:value=permission_denied ? 4'hf :
                          error_latched ? 4'he :
                          !link_alive ? 4'hc :
                          remote_alarm ? 4'ha : 4'h0;
        endcase
        case(value)
            0:seg_data=8'hc0;1:seg_data=8'hf9;2:seg_data=8'ha4;3:seg_data=8'hb0;
            4:seg_data=8'h99;5:seg_data=8'h92;6:seg_data=8'h82;7:seg_data=8'hf8;
            8:seg_data=8'h80;9:seg_data=8'h90;10:seg_data=8'h88;11:seg_data=8'h83;
            12:seg_data=8'hc6;13:seg_data=8'ha1;14:seg_data=8'h86;default:seg_data=8'h8e;
        endcase
    end
endmodule
