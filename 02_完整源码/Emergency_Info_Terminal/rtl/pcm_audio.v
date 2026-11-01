`timescale 1ns/1ps

module pcm_audio #(
    parameter integer PIXEL_HZ = 25000000,
    parameter integer SAMPLE_HZ = 48000
)(
    input wire clk, rst, enable, test_mode,
    input wire [3:0] image_index,
    output reg sample_valid,
    output reg [15:0] sample_left, sample_right,
    output reg acr_valid,
    output wire [19:0] acr_n, acr_cts
);
    reg [31:0] sample_acc;
    reg [23:0] phase;
    reg [23:0] image_step;
    always @* begin
        case(image_index[2:0])
            0: image_step=24'd153791;
            1: image_step=24'd172666;
            2: image_step=24'd182802;
            3: image_step=24'd205171;
            4: image_step=24'd230337;
            5: image_step=24'd243969;
            6: image_step=24'd274028;
            default: image_step=24'd307582;
        endcase
    end
    wire [23:0] step = test_mode ? 24'd349525 : image_step;
    reg [6:0] acr_count;
    reg [11:0] envelope;
    wire [11:0] triangle = phase[23] ? ~phase[22:11] : phase[22:11];
    wire signed [12:0] centered = $signed({1'b0, triangle}) - 13'sd2048;
    wire signed [25:0] scaled = centered * $signed({1'b0, envelope});

    assign acr_n = 20'd6144;
    assign acr_cts = PIXEL_HZ / 1000;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            sample_acc <= 0; phase <= 0; envelope <= 0; acr_count <= 0;
            sample_valid <= 0; sample_left <= 0; sample_right <= 0; acr_valid <= 0;
        end else begin
            sample_valid <= 0; acr_valid <= 0;
            if (sample_acc >= PIXEL_HZ-SAMPLE_HZ) begin
                sample_acc <= sample_acc - (PIXEL_HZ-SAMPLE_HZ);
                sample_valid <= 1;
                phase <= phase + step;
                if (enable && envelope < 12'd1024) envelope <= envelope + 1'b1;
                else if (!enable && envelope != 0) envelope <= envelope - 1'b1;

                sample_left <= scaled[23:8];
                sample_right <= scaled[23:8];
                acr_count <= acr_count + 1'b1;
                if (acr_count == 0) acr_valid <= 1;
            end else sample_acc <= sample_acc + SAMPLE_HZ;
        end
    end
endmodule
