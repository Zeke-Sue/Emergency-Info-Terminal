`timescale 1ns/1ps

module test_tone_40k #(parameter integer CLK_HZ=25000000)(
    input wire clk,rst,enable,output_tick,
    output reg native_valid,
    output reg signed [15:0] native_sample,
    output reg signed [15:0] output_sample,
    output reg underflow,overflow
);
    reg [31:0] sample_acc;
    reg [5:0] phase;
    function signed [15:0] sine40;
        input [5:0] p;
        reg [3:0] q;
        reg signed [15:0] magnitude;
        begin
            q=p<=10 ? p : p<=20 ? 20-p : p<=30 ? p-20 : 40-p;
            case(q)
                0:magnitude=0;1:magnitude=641;2:magnitude=1266;
                3:magnitude=1860;4:magnitude=2408;5:magnitude=2896;
                6:magnitude=3314;7:magnitude=3650;8:magnitude=3896;
                9:magnitude=4046;default:magnitude=4096;
            endcase
            sine40=p<20 ? magnitude : -magnitude;
        end
    endfunction
    reg signed [15:0] fifo[0:7];
    reg [2:0] wp,rp,fraction;
    reg [3:0] count;
    reg started;
    wire push=native_valid;
    wire step=output_tick&&(started||count>=3)&&count>=2;
    wire pop=step&&fraction!=0;
    wire signed [15:0] first=fifo[rp];
    wire signed [15:0] second=fifo[rp+3'd1];
    wire signed [19:0] weighted_first=first*$signed({1'b0,3'd6-fraction});
    wire signed [19:0] weighted_second=second*$signed({1'b0,fraction});
    wire signed [20:0] interpolated=$signed(weighted_first)+$signed(weighted_second);
    always @(posedge clk or posedge rst)begin
        if(rst)begin
            sample_acc<=0;phase<=0;native_valid<=0;native_sample<=0;
            output_sample<=0;wp<=0;rp<=0;fraction<=0;count<=0;
            started<=0;underflow<=0;overflow<=0;
        end else if(!enable)begin
            sample_acc<=0;phase<=0;native_valid<=0;native_sample<=0;
            output_sample<=0;wp<=0;rp<=0;fraction<=0;count<=0;
            started<=0;underflow<=0;overflow<=0;
        end else begin
            native_valid<=0;
            if(sample_acc>=CLK_HZ-40000)begin
                sample_acc<=sample_acc-(CLK_HZ-40000);
                native_valid<=1;native_sample<=sine40(phase);
                phase<=phase==39 ? 6'd0 : phase+1'b1;
            end else sample_acc<=sample_acc+40000;
            if(push)begin
                fifo[wp]<=native_sample;wp<=wp+1'b1;
                if(count==8&&!pop)overflow<=1;
            end
            case({push,pop})
                2'b10:count<=count+1'b1;
                2'b01:count<=count-1'b1;
                default:begin end
            endcase
            if(step)begin
                started<=1;output_sample<=interpolated/6;
                fraction<=fraction==0 ? 3'd5 : fraction-1'b1;
                if(pop)rp<=rp+1'b1;
            end else if(output_tick&&started)begin
                underflow<=1;output_sample<=0;
            end
        end
    end
endmodule
