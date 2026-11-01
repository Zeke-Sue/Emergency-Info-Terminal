`timescale 1ns/1ps

module audio_waveform_capture(
    input wire clk,rst,frame_tick,sample_valid,
    input wire signed [15:0] sample,
    input wire [6:0] read_index,
    output wire [15:0] read_sample,
    output reg ready
);
    reg display_bank,capture_bank,capturing,pending,waiting;
    reg [6:0] write_index;
    reg [7:0] trigger_wait;
    reg signed [15:0] previous;
    wire triggered=(previous<0&&sample>=0)||trigger_wait==255;
    wire write_sample=sample_valid&&(capturing||(waiting&&triggered));
    buffer_ram #(.DATA_WIDTH(16),.ADDR_WIDTH(8)) samples(
        .clk(clk),.we(write_sample),.wa({capture_bank,write_index}),
        .d(sample),.ra({display_bank,read_index}),.q(read_sample));
    always @(posedge clk or posedge rst)begin
        if(rst)begin
            display_bank<=0;capture_bank<=1;capturing<=0;pending<=0;
            waiting<=1;write_index<=0;trigger_wait<=0;previous<=0;ready<=0;
        end else begin
            if(sample_valid)begin
                previous<=sample;
                if(waiting)begin
                    if(triggered)begin waiting<=0;capturing<=1;write_index<=1;end
                    else trigger_wait<=trigger_wait+1'b1;
                end else if(capturing)begin
                    if(write_index==127)begin capturing<=0;pending<=1;end
                    else write_index<=write_index+1'b1;
                end
            end
            if(frame_tick&&pending)begin
                display_bank<=capture_bank;capture_bank<=display_bank;
                ready<=1;pending<=0;waiting<=1;write_index<=0;trigger_wait<=0;
            end
        end
    end
endmodule
