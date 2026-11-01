`timescale 1ns/1ps

module site_notice_tone(
    input wire clk,rst,enable,sample_tick,
    output reg signed [15:0] tone
);
    reg [31:0] phase;
    reg [14:0] half_samples;
    reg high_tone;
    wire signed [15:0] sine;
    sine_quarter_rom waveform(.phase(phase[31:23]),.value(sine));
    always @(posedge clk or posedge rst)begin
        if(rst)begin phase<=0;half_samples<=0;high_tone<=0;tone<=0;end
        else if(!enable)begin phase<=0;half_samples<=0;high_tone<=0;tone<=0;end
        else if(sample_tick)begin
            phase<=phase+(high_tone ? 32'd134217728 : 32'd89478485);
            tone<=sine>>>2;
            if(half_samples==23999)begin half_samples<=0;high_tone<=!high_tone;end
            else half_samples<=half_samples+1'b1;
        end
    end
endmodule
