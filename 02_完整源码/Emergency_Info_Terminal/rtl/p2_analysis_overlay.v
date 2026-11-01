`timescale 1ns/1ps

module p2_analysis_overlay #(
    parameter integer WIDTH=640,
    parameter integer HEIGHT=480
)(
    input wire [10:0] x,
    input wire [10:0] y,
    input wire [1:0] view,
    input wire [19:0] histogram_value,
    input wire [7:0] waterfall_value,
    input wire [23:0] peak_frequency_q8,
    input wire [23:0] rgb_in,
    output wire [5:0] histogram_column,
    output wire [6:0] waterfall_age,
    output wire [5:0] waterfall_bin,
    output reg [23:0] rgb_out
);

    localparam integer WATER_X=WIDTH-128;
    wire hist_region=x<256 && y<128;
    wire spectrum_region=x>=256&&x<512&&y<128;
    wire water_region=x>=WATER_X && x<WIDTH && y<128;
    assign histogram_column=hist_region ? x[7:2] : 6'd0;
    assign waterfall_age=water_region ? x[6:0] : 7'd0;
    assign waterfall_bin=water_region ? 6'd63-y[6:1] : spectrum_region ? x[7:2] : 6'd0;
    wire [7:0] hist_height=|histogram_value[19:15] ? 8'd127 :
        (histogram_value[14:8]>127 ? 8'd127 : histogram_value[14:8]);
    wire hist_bar=hist_region && x[1:0]!=3 && y[6:0]>=127-hist_height;
    wire [7:0] water_r=waterfall_value[7] ?
        {waterfall_value[6:0],1'b0} : 8'd0;
    wire [7:0] water_g=waterfall_value[7:1];
    wire [7:0] water_b=8'd32+(waterfall_value>>2);

    wire [7:0] peak_scaled=peak_frequency_q8[20:13];
    wire [11:0] peak_scaled_wide={4'd0,peak_scaled};
    wire [11:0] peak_times_eleven=(peak_scaled_wide<<3)+
        (peak_scaled_wide<<1)+peak_scaled_wide;
    wire [5:0] peak_bin_approx=peak_times_eleven[11] ?
        6'd63 : peak_times_eleven[10:5];
    wire peak_marker=water_region && waterfall_bin==peak_bin_approx;
    always @* begin
        rgb_out=rgb_in;
        if(view[0] && hist_region)
            rgb_out=hist_bar ? 24'h40e0ff : {1'b0,rgb_in[23:17],1'b0,rgb_in[15:9],1'b0,rgb_in[7:1]};
        if(view[1] && spectrum_region)
            rgb_out=(x[1:0]!=3&&y[6:0]>=127-{1'b0,waterfall_value[7:1]}) ? 24'h45dfb2 : 24'h142b3c;
        if(view[1] && water_region)
            rgb_out=peak_marker ? 24'hffffff : {water_r,water_g,water_b};
    end
endmodule
