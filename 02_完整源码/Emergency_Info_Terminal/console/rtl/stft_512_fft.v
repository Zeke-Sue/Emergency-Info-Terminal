// 512点Hann窗短时傅里叶变换，帧移256点。
// 全部257个单边频点参与峰值检测，前64个频点用于显示。
`timescale 1ns/1ps

module stft_512_fft(
    input wire clk,
    input wire rst,
    input wire sample_tick,
    input wire signed [15:0] sample_in,
    output reg spectrum_valid,
    output reg [5:0] spectrum_bin,
    output reg [15:0] spectrum_magnitude,
    output reg transform_done,
    output reg [23:0] peak_frequency_q8,
    output reg busy,
    output reg full_bin_valid,output reg [8:0] full_bin_index,
    output reg [15:0] full_bin_magnitude,
    output reg overrun
);
    localparam ST_IDLE=0,ST_FEED=1,ST_WAIT=2,ST_OUTPUT=3,
        ST_PEAK=4,ST_DIVIDE=5;
    reg [2:0] state;

    reg [8:0] write_pointer,snapshot_base,read_index,q_index;
    reg [9:0] fill_count;
    reg [7:0] hop_count;
    reg snapshot_pending,read_valid,issue_done;
    wire [8:0] capture_read_address=snapshot_base+read_index;
    wire [15:0] capture_q;
    buffer_ram #(.DATA_WIDTH(16),.ADDR_WIDTH(9)) capture_memory(
        .clk(clk),.we(sample_tick),.wa(write_pointer),
        .ra(capture_read_address),.d(sample_in),.q(capture_q));

    wire [8:0] hann_phase=q_index+9'd128;
    wire signed [15:0] hann_cosine;
    sine_quarter_rom hann_rom(.phase(hann_phase),.value(hann_cosine));
    wire signed [16:0] hann_coefficient=
        (17'sd32767-$signed(hann_cosine))>>>1;
    wire signed [32:0] window_product=
        $signed(capture_q)*$signed(hann_coefficient);
    wire signed [15:0] windowed_sample=window_product>>>15;
    wire fft_start=state==ST_FEED&&read_valid&&q_index==0;
    wire fft_din_en=state==ST_FEED&&read_valid;
    wire fft_done,fft_busy,fft_dout_en;
    wire [24:0] fft_dout_re,fft_dout_im;
    fft transform(.clk(clk),.rst(rst),.mode(1'b0),.start(fft_start),
        .din_en(fft_din_en),.din_re(windowed_sample),.din_im(16'd0),
        .done(fft_done),.busy(fft_busy),.dout_en(fft_dout_en),
        .dout_re(fft_dout_re),.dout_im(fft_dout_im));

    reg [8:0] output_index,max_bin;
    wire signed [24:0] fft_real_signed=fft_dout_re;
    wire signed [24:0] fft_imag_signed=fft_dout_im;
    wire [24:0] fft_real_abs=fft_real_signed<0 ?
        -fft_real_signed : fft_real_signed;
    wire [24:0] fft_imag_abs=fft_imag_signed<0 ?
        -fft_imag_signed : fft_imag_signed;
    wire [25:0] magnitude_wide=fft_real_abs+(fft_imag_abs>>1);
    wire [18:0] magnitude_scaled=magnitude_wide>>7;
    wire [15:0] magnitude_clamped=|magnitude_scaled[18:16] ?
        16'hffff : magnitude_scaled[15:0];
    wire [25:0] norm_wide=fft_real_abs>=fft_imag_abs ?
        {1'b0,fft_real_abs}+({1'b0,fft_imag_abs}>>1) :
        {1'b0,fft_imag_abs}+({1'b0,fft_real_abs}>>1);
    wire [18:0] norm_scaled=norm_wide>>7;

    reg [25:0] max_magnitude,previous_magnitude;
    reg [25:0] peak_left,peak_centre,peak_right;
    reg right_pending;
    wire signed [27:0] peak_left_ext={2'b0,peak_left};
    wire signed [27:0] peak_centre_ext={2'b0,peak_centre};
    wire signed [27:0] peak_right_ext={2'b0,peak_right};
    wire signed [27:0] peak_denominator=
        peak_left_ext-(peak_centre_ext<<<1)+peak_right_ext;
    wire signed [27:0] peak_difference=peak_left_ext-peak_right_ext;
    wire signed [34:0] peak_numerator={peak_difference,7'd0};

    reg [34:0] divide_shift,divide_quotient;
    reg [28:0] divide_remainder;
    reg [27:0] divide_divisor;
    reg divide_negative;
    reg [5:0] divide_count;
    wire [28:0] divide_trial={divide_remainder[27:0],divide_shift[34]};
    wire divide_subtract=divide_trial>={1'b0,divide_divisor};
    wire [34:0] quotient_next=
        {divide_quotient[33:0],divide_subtract};
    wire [7:0] delta_magnitude=|quotient_next[34:8] ? 8'd128 :
        (quotient_next[7:0]>128 ? 8'd128 : quotient_next[7:0]);
    wire signed [17:0] peak_bin_q8=$signed({1'b0,max_bin,8'd0});
    wire signed [17:0] interpolated_bin_q8=divide_negative ?
        peak_bin_q8-$signed({10'd0,delta_magnitude}) :
        peak_bin_q8+$signed({10'd0,delta_magnitude});

    function [23:0] bin_to_frequency_q8;
        input signed [17:0] bin_q8;
        reg signed [27:0] scaled;
        begin
            scaled=(bin_q8<<<8)+(bin_q8<<<7)-(bin_q8<<<3)-bin_q8;
            bin_to_frequency_q8=scaled>>>2;
        end
    endfunction

    always @(posedge clk or posedge rst)begin
        if(rst)begin
            state<=ST_IDLE;write_pointer<=0;snapshot_base<=0;read_index<=0;
            q_index<=0;fill_count<=0;hop_count<=0;snapshot_pending<=0;
            read_valid<=0;issue_done<=0;output_index<=0;max_bin<=0;
            max_magnitude<=0;previous_magnitude<=0;peak_left<=0;
            peak_centre<=0;peak_right<=0;right_pending<=0;
            spectrum_valid<=0;spectrum_bin<=0;spectrum_magnitude<=0;
            transform_done<=0;peak_frequency_q8<=0;busy<=0;
            full_bin_valid<=0;full_bin_index<=0;full_bin_magnitude<=0;overrun<=0;
            divide_shift<=0;divide_quotient<=0;divide_remainder<=0;
            divide_divisor<=1;divide_negative<=0;divide_count<=0;
        end else begin
            spectrum_valid<=0;transform_done<=0;full_bin_valid<=0;
            if(sample_tick)begin
                write_pointer<=write_pointer+1'b1;
                if(fill_count<512)begin
                    fill_count<=fill_count+1'b1;
                    if(fill_count==511)begin
                        snapshot_pending<=1;hop_count<=0;
                    end
                end else if(hop_count==255)begin
                    if(snapshot_pending || state!=ST_IDLE)overrun<=1;
                    snapshot_pending<=1;hop_count<=0;
                end else hop_count<=hop_count+1'b1;
            end

            if(fft_dout_en)begin
                if(output_index<=256)begin
                    full_bin_valid<=1;full_bin_index<=output_index;
                    full_bin_magnitude<=|norm_scaled[18:16] ? 16'hffff : norm_scaled[15:0];
                    if(output_index<64)begin
                        spectrum_valid<=1;spectrum_bin<=output_index[5:0];
                        spectrum_magnitude<=magnitude_clamped;
                    end
                    if(right_pending)begin
                        peak_right<=magnitude_wide;right_pending<=0;
                    end
                    if(magnitude_wide>max_magnitude)begin
                        max_magnitude<=magnitude_wide;max_bin<=output_index;
                        peak_left<=output_index==0 ? 0 : previous_magnitude;
                        peak_centre<=magnitude_wide;peak_right<=0;
                        right_pending<=output_index!=256;
                    end
                    previous_magnitude<=magnitude_wide;
                end
                if(output_index==511)state<=ST_PEAK;
                else output_index<=output_index+1'b1;
            end

            case(state)
                ST_IDLE:begin
                    busy<=0;read_valid<=0;
                    if(snapshot_pending)begin
                        snapshot_pending<=0;snapshot_base<=write_pointer;
                        read_index<=0;issue_done<=0;read_valid<=0;
                        output_index<=0;max_bin<=0;max_magnitude<=0;
                        previous_magnitude<=0;peak_left<=0;peak_centre<=0;
                        peak_right<=0;right_pending<=0;state<=ST_FEED;busy<=1;
                    end
                end
                ST_FEED:begin
                    if(!issue_done)begin
                        q_index<=read_index;read_valid<=1;
                        if(read_index==511)issue_done<=1;
                        else read_index<=read_index+1'b1;
                    end else begin
                        read_valid<=0;state<=ST_WAIT;
                    end
                end
                ST_WAIT:if(fft_done)state<=ST_OUTPUT;
                ST_OUTPUT:begin end
                ST_PEAK:begin
                    if(max_bin==0||max_bin==256||peak_denominator==0)begin
                        peak_frequency_q8<=bin_to_frequency_q8(peak_bin_q8);
                        transform_done<=1;state<=ST_IDLE;busy<=0;
                    end else begin
                        divide_shift<=peak_numerator[34] ?
                            -peak_numerator : peak_numerator;
                        divide_divisor<=peak_denominator[27] ?
                            -peak_denominator : peak_denominator;
                        divide_negative<=peak_numerator[34]^peak_denominator[27];
                        divide_quotient<=0;divide_remainder<=0;divide_count<=0;
                        state<=ST_DIVIDE;
                    end
                end
                ST_DIVIDE:begin
                    divide_shift<={divide_shift[33:0],1'b0};
                    if(divide_subtract)
                        divide_remainder<=divide_trial-{1'b0,divide_divisor};
                    else divide_remainder<=divide_trial;
                    divide_quotient<=quotient_next;
                    if(divide_count==34)begin
                        peak_frequency_q8<=bin_to_frequency_q8(
                            interpolated_bin_q8);
                        transform_done<=1;state<=ST_IDLE;busy<=0;
                    end else divide_count<=divide_count+1'b1;
                end
                default:state<=ST_IDLE;
            endcase
        end
    end
endmodule
