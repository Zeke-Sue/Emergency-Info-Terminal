`timescale 1ns/1ps

module stft_512_serial(
    input wire clk,
    input wire rst,
    input wire sample_tick,
    input wire signed [15:0] sample_in,
    output reg spectrum_valid,
    output reg [5:0] spectrum_bin,
    output reg [15:0] spectrum_magnitude,
    output reg transform_done,
    output reg [23:0] peak_frequency_q8,
    output reg busy
);
    localparam ST_IDLE=0,ST_COPY=1,ST_DFT=2,ST_PEAK_REQ=3,
        ST_PEAK_LEFT=4,ST_PEAK_CENTRE=5,ST_PEAK_RIGHT=6,
        ST_PEAK_EVAL=7,ST_PEAK_SETUP=8,ST_DIVIDE=9,ST_MAGNITUDE=10;
    reg [3:0] state;

    reg [8:0] write_pointer,snapshot_base,copy_index,copy_index_d;
    reg [9:0] fill_count;
    reg [7:0] hop_count;
    reg snapshot_pending,copy_valid;
    wire [8:0] copy_address=snapshot_base+copy_index;
    wire [15:0] capture_q,snapshot_q;
    wire snapshot_we=state==ST_COPY && copy_valid;
    buffer_ram #(.DATA_WIDTH(16),.ADDR_WIDTH(9)) capture_memory(
        .clk(clk),.we(sample_tick),.wa(write_pointer),.ra(copy_address),
        .d(sample_in),.q(capture_q));

    reg [8:0] sample_index;
    buffer_ram #(.DATA_WIDTH(16),.ADDR_WIDTH(9)) snapshot_memory(
        .clk(clk),.we(snapshot_we),.wa(copy_index_d),.ra(sample_index),
        .d(capture_q),.q(snapshot_q));

    reg [5:0] bin_index,max_bin,peak_bin;
    reg [8:0] phase;
    reg [1:0] mac_phase;
    reg signed [15:0] windowed_sample;
    reg signed [47:0] real_accumulator,imag_accumulator;
    reg signed [47:0] magnitude_real,magnitude_imag;
    reg [15:0] max_magnitude;

    wire [8:0] sine_phase=mac_phase==1 ? sample_index+9'd128 :
                          (mac_phase==2 ? phase+9'd128 : phase);
    wire signed [15:0] sine_value;
    sine_quarter_rom sine_rom(.phase(sine_phase),.value(sine_value));
    wire signed [16:0] hann_coefficient=(17'sd32767-sine_value)>>>1;
    reg signed [16:0] multiplier_a,multiplier_b;
    always @* begin
        multiplier_a=17'sd0;multiplier_b=17'sd0;
        if(mac_phase==1) begin
            multiplier_a=$signed(snapshot_q);
            multiplier_b=hann_coefficient;
        end else if(mac_phase==2 || mac_phase==3) begin
            multiplier_a=windowed_sample;
            multiplier_b=$signed(sine_value);
        end
    end
    wire signed [33:0] shared_product=multiplier_a*multiplier_b;
    wire signed [47:0] real_final=real_accumulator+shared_product;
    wire signed [47:0] imag_final=imag_accumulator-shared_product;
    wire [47:0] real_absolute=magnitude_real[47] ?
        -magnitude_real : magnitude_real;
    wire [47:0] imag_absolute=magnitude_imag[47] ? -magnitude_imag : magnitude_imag;
    wire [48:0] magnitude_wide=real_absolute+(imag_absolute>>1);
    wire [28:0] magnitude_scaled=magnitude_wide>>20;
    wire [15:0] magnitude_clamped=|magnitude_scaled[28:16] ?
        16'hffff : magnitude_scaled[15:0];
    reg [5:0] magnitude_read_address;
    wire [15:0] magnitude_q;
    wire magnitude_we=state==ST_MAGNITUDE;
    buffer_ram #(.DATA_WIDTH(16),.ADDR_WIDTH(6)) magnitude_memory(
        .clk(clk),.we(magnitude_we),.wa(bin_index),.ra(magnitude_read_address),
        .d(magnitude_clamped),.q(magnitude_q));
    wire [5:0] final_max_bin=magnitude_clamped>max_magnitude ?
        bin_index : max_bin;

    reg signed [16:0] peak_left,peak_centre,peak_right;
    wire signed [18:0] peak_denominator=
        peak_left-(peak_centre<<<1)+peak_right;
    wire signed [23:0] peak_numerator=(peak_left-peak_right)<<<7;

    reg [23:0] divide_shift,divide_quotient;
    reg [24:0] divide_remainder;
    reg [18:0] divide_divisor;
    reg divide_negative;
    reg [4:0] divide_count;
    wire [24:0] divide_trial={divide_remainder[23:0],divide_shift[23]};
    wire divide_subtract=divide_trial>=divide_divisor;
    wire [23:0] quotient_next={divide_quotient[22:0],divide_subtract};
    wire [7:0] delta_magnitude=|quotient_next[23:8] ?
        8'd128 : (quotient_next[7:0]>128 ? 8'd128 : quotient_next[7:0]);
    wire signed [16:0] interpolated_bin_q8=divide_negative ?
        $signed({1'b0,peak_bin,8'd0})-$signed({9'd0,delta_magnitude}) :
        $signed({1'b0,peak_bin,8'd0})+$signed({9'd0,delta_magnitude});

    function [23:0] bin_to_frequency_q8;
        input signed [16:0] bin_q8;
        reg signed [26:0] scaled;
        begin
            scaled=(bin_q8<<<8)+(bin_q8<<<7)-(bin_q8<<<3)-bin_q8;
            bin_to_frequency_q8=scaled>>>2;
        end
    endfunction

    always @(posedge clk or posedge rst) begin
        if(rst) begin
            state<=ST_IDLE;write_pointer<=0;snapshot_base<=0;copy_index<=0;
            copy_index_d<=0;fill_count<=0;hop_count<=0;snapshot_pending<=0;
            copy_valid<=0;sample_index<=0;bin_index<=0;max_bin<=0;peak_bin<=0;
            phase<=0;mac_phase<=0;windowed_sample<=0;
            real_accumulator<=0;imag_accumulator<=0;max_magnitude<=0;
            magnitude_real<=0;magnitude_imag<=0;
            spectrum_valid<=0;spectrum_bin<=0;spectrum_magnitude<=0;
            transform_done<=0;peak_frequency_q8<=0;busy<=0;
            divide_shift<=0;divide_quotient<=0;divide_remainder<=0;
            divide_divisor<=1;divide_negative<=0;divide_count<=0;
            magnitude_read_address<=0;peak_left<=0;peak_centre<=0;peak_right<=0;
        end else begin
            spectrum_valid<=0;transform_done<=0;
            if(sample_tick) begin
                write_pointer<=write_pointer+1'b1;
                if(fill_count<512) begin
                    fill_count<=fill_count+1'b1;
                    if(fill_count==511) begin
                        snapshot_pending<=1;hop_count<=0;
                    end
                end else if(hop_count==255) begin
                    snapshot_pending<=1;hop_count<=0;
                end else hop_count<=hop_count+1'b1;
            end

            case(state)
                ST_IDLE:begin
                    busy<=0;
                    if(snapshot_pending) begin
                        snapshot_pending<=0;snapshot_base<=write_pointer;
                        copy_index<=0;copy_valid<=0;state<=ST_COPY;busy<=1;
                    end
                end
                ST_COPY:begin
                    copy_index_d<=copy_index;copy_valid<=1;
                    if(copy_index!=511) copy_index<=copy_index+1'b1;
                    if(copy_valid && copy_index_d==511) begin
                        copy_valid<=0;state<=ST_DFT;sample_index<=0;
                        bin_index<=0;phase<=0;mac_phase<=0;
                        real_accumulator<=0;imag_accumulator<=0;
                        max_magnitude<=0;max_bin<=0;
                    end
                end
                ST_DFT:begin
                    case(mac_phase)
                        0:mac_phase<=1;
                        1:begin
                            windowed_sample<=shared_product>>>15;
                            mac_phase<=2;
                        end
                        2:begin
                            real_accumulator<=real_final;
                            mac_phase<=3;
                        end
                        default:begin
                            imag_accumulator<=imag_final;
                            if(sample_index==511) begin
                                magnitude_real<=real_accumulator;
                                magnitude_imag<=imag_final;
                                state<=ST_MAGNITUDE;
                            end else begin
                                sample_index<=sample_index+1'b1;
                                phase<=phase+bin_index;mac_phase<=0;
                            end
                        end
                    endcase
                end
                ST_MAGNITUDE:begin
                    spectrum_valid<=1;spectrum_bin<=bin_index;
                    spectrum_magnitude<=magnitude_clamped;
                    if(magnitude_clamped>max_magnitude) begin
                        max_magnitude<=magnitude_clamped;
                        max_bin<=bin_index;
                    end
                    if(bin_index==63) begin
                        peak_bin<=final_max_bin;
                        state<=ST_PEAK_REQ;
                    end else begin
                        bin_index<=bin_index+1'b1;
                        sample_index<=0;phase<=0;mac_phase<=0;
                        real_accumulator<=0;imag_accumulator<=0;
                        state<=ST_DFT;
                    end
                end
                ST_PEAK_REQ:begin
                    if(peak_bin==0 || peak_bin==63) begin
                        peak_frequency_q8<=bin_to_frequency_q8(
                            $signed({1'b0,peak_bin,8'd0}));
                        transform_done<=1;state<=ST_IDLE;busy<=0;
                    end else begin
                        magnitude_read_address<=peak_bin-1'b1;
                        state<=ST_PEAK_LEFT;
                    end
                end
                ST_PEAK_LEFT:begin
                    magnitude_read_address<=peak_bin;
                    state<=ST_PEAK_CENTRE;
                end
                ST_PEAK_CENTRE:begin
                    peak_left<=$signed({1'b0,magnitude_q});
                    magnitude_read_address<=peak_bin+1'b1;
                    state<=ST_PEAK_RIGHT;
                end
                ST_PEAK_RIGHT:begin
                    peak_centre<=$signed({1'b0,magnitude_q});
                    state<=ST_PEAK_EVAL;
                end
                ST_PEAK_EVAL:begin
                    peak_right<=$signed({1'b0,magnitude_q});
                    state<=ST_PEAK_SETUP;
                end
                ST_PEAK_SETUP:begin
                    if(peak_denominator==0) begin
                        peak_frequency_q8<=bin_to_frequency_q8(
                            $signed({1'b0,peak_bin,8'd0}));
                        transform_done<=1;state<=ST_IDLE;busy<=0;
                    end else begin
                        divide_shift<=peak_numerator[23] ?
                            -peak_numerator : peak_numerator;
                        divide_divisor<=peak_denominator[18] ?
                            -peak_denominator : peak_denominator;
                        divide_negative<=peak_numerator[23]^peak_denominator[18];
                        divide_quotient<=0;divide_remainder<=0;divide_count<=0;
                        state<=ST_DIVIDE;
                    end
                end
                ST_DIVIDE:begin
                    divide_shift<={divide_shift[22:0],1'b0};
                    if(divide_subtract)
                        divide_remainder<=divide_trial-divide_divisor;
                    else divide_remainder<=divide_trial;
                    divide_quotient<=quotient_next;
                    if(divide_count==23) begin
                        peak_frequency_q8<=bin_to_frequency_q8(interpolated_bin_q8);
                        transform_done<=1;state<=ST_IDLE;busy<=0;
                    end else divide_count<=divide_count+1'b1;
                end
                default:state<=ST_IDLE;
            endcase
        end
    end
endmodule
