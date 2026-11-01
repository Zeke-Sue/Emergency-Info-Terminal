`timescale 1ns/1ps

module video_effects #(
    parameter integer WIDTH=640,
    parameter integer HEIGHT=480,
    parameter integer ENABLE=1,
    parameter integer SCROLL_STEP=1,
    parameter integer AUDIO_SAMPLES=128, LUT_ONLY=0, V5_CONTROLS=0,
    parameter integer AUXILIARY_OVERLAY=1,
    parameter integer WAVEFORM_OVERLAY=AUXILIARY_OVERLAY, FRAME_CAPTURE=0
)(
    input wire clk, rst, frame_tick,
    input wire [10:0] x, y,
    input wire [3:0] image_index,
    input wire [4:0] fade_gain,
    input wire [2:0] transition_mode,
    input wire zoom_mode,
    input wire [1:0] zoom_scale,
    input wire grayscale_enable,
    input wire overlay_enable,
    input wire [2:0] brightness_level,
    input wire [2:0] contrast_level,
    input wire [2:0] saturation_level,
    input wire [1:0] gamma_mode,temperature_mode,
    input wire [3:0] quality_selection,
    input wire [2:0] volume_level,
    input wire [1:0] flash_rate,flash_duty,
    input wire [15:0] audio_peak_absolute,
    input wire [31:0] audio_limited_count,audio_clipped_count,
    input wire [5:0] transition_settings,
    input wire osd_visible,
    input wire color_lut_active,
    input wire audio_sample_valid,
    input wire [15:0] audio_sample,
    input wire [23:0] rgb_in,
    output reg [23:0] rgb_out,
    output reg [12:0] scroll_position,
    output wire banner_pixel,
    output wire text_pixel,
    output wire osd_pixel,
    output wire waveform_pixel,
    output wire waveform_panel
);
    localparam integer BANNER_Y = HEIGHT>24 ? HEIGHT-24 : 0;
    localparam integer BANNER_HEIGHT = 20;
    localparam integer TEXT_CHARS = 12;
    localparam integer TEXT_PIXELS = TEXT_CHARS*16;
    localparam integer SCROLL_LIMIT = WIDTH+TEXT_PIXELS;
    localparam integer WAVE_TOP = HEIGHT>128 ? HEIGHT-120 : 0;
    localparam integer WAVE_BOTTOM = BANNER_Y>8 ? BANNER_Y-8 : BANNER_Y;
    localparam integer WAVE_CENTER = (WAVE_TOP+WAVE_BOTTOM)/2;
    localparam integer AUDIO_AW = $clog2(AUDIO_SAMPLES);

    localparam [4:0] CH_SPACE=0, CH_A=1, CH_N=2, CH_L=3, CH_O=4,
                     CH_G=5, CH_I=6, CH_C=7, CH_F=8, CH_P=9,
                     CH_B=10, CH_R=11, CH_S=12, CH_T=13,
                     CH_0=14, CH_1=15, CH_2=16, CH_3=17,
                     CH_4=18, CH_5=19, CH_6=20, CH_7=21,
                     CH_8=22, CH_9=23, CH_PLUS=24,
                     CH_MINUS=25, CH_DOT=26, CH_Z=27,
                     CH_M=28, CH_X=29, CH_D=30, CH_E=31;

    function [4:0] ticker_char;
        input [3:0] index;
        begin
            case(index)
                0:ticker_char=CH_A;     1:ticker_char=CH_N;
                2:ticker_char=CH_L;     3:ticker_char=CH_O;
                4:ticker_char=CH_G;     5:ticker_char=CH_I;
                6:ticker_char=CH_C;     7:ticker_char=CH_SPACE;
                8:ticker_char=CH_F;     9:ticker_char=CH_P;
                10:ticker_char=CH_G;   11:ticker_char=CH_A;
                default:ticker_char=CH_SPACE;
            endcase
        end
    endfunction

    function [7:0] font_row;
        input [4:0] character;
        input [2:0] row;
        begin
            font_row=8'h00;
            case(character)
                CH_D:case(row)
                    0,6:font_row=8'hfc;1,5:font_row=8'hc6;
                    2,3,4:font_row=8'hc3;default:font_row=0;
                endcase
                CH_E:case(row)
                    0,6:font_row=8'hfe;3:font_row=8'hfc;
                    1,2,4,5:font_row=8'hc0;default:font_row=0;
                endcase
                CH_A:case(row)
                    0:font_row=8'h3c;1:font_row=8'h66;2:font_row=8'hc3;3:font_row=8'hc3;
                    4:font_row=8'hff;5:font_row=8'hc3;6:font_row=8'hc3;default:font_row=0;
                endcase
                CH_B:case(row)
                    0:font_row=8'hfc;1,2:font_row=8'hc6;3:font_row=8'hfc;
                    4,5:font_row=8'hc6;6:font_row=8'hfc;default:font_row=0;
                endcase
                CH_N:case(row)
                    0:font_row=8'hc3;1:font_row=8'he3;2:font_row=8'hf3;3:font_row=8'hdb;
                    4:font_row=8'hcf;5:font_row=8'hc7;6:font_row=8'hc3;default:font_row=0;
                endcase
                CH_L:case(row)
                    0,1,2,3,4,5:font_row=8'hc0;6:font_row=8'hff;default:font_row=0;
                endcase
                CH_O:case(row)
                    0:font_row=8'h3c;1:font_row=8'h66;2,3,4,5:font_row=8'hc3;
                    6:font_row=8'h66;7:font_row=8'h3c;
                endcase
                CH_G:case(row)
                    0:font_row=8'h3c;1:font_row=8'h66;2:font_row=8'hc3;3:font_row=8'hc0;
                    4:font_row=8'hcf;5:font_row=8'hc3;6:font_row=8'h66;7:font_row=8'h3e;
                endcase
                CH_I:case(row)
                    0:font_row=8'h7e;1,2,3,4,5,6:font_row=8'h18;7:font_row=8'h7e;
                endcase
                CH_C:case(row)
                    0:font_row=8'h3c;1:font_row=8'h66;2,3,4,5:font_row=8'hc0;
                    6:font_row=8'h66;7:font_row=8'h3c;
                endcase
                CH_F:case(row)
                    0:font_row=8'hff;1,2:font_row=8'hc0;3:font_row=8'hfc;
                    4,5,6:font_row=8'hc0;default:font_row=0;
                endcase
                CH_P:case(row)
                    0:font_row=8'hfc;1,2:font_row=8'hc6;3:font_row=8'hfc;
                    4,5,6:font_row=8'hc0;default:font_row=0;
                endcase
                CH_R:case(row)
                    0:font_row=8'hfc;1,2:font_row=8'hc6;3:font_row=8'hfc;
                    4:font_row=8'hd8;5:font_row=8'hcc;6:font_row=8'hc6;default:font_row=0;
                endcase
                CH_S:case(row)
                    0:font_row=8'h3e;1,2:font_row=8'h60;3:font_row=8'h3c;
                    4,5:font_row=8'h06;6:font_row=8'h7c;default:font_row=0;
                endcase
                CH_T:case(row)
                    0:font_row=8'hff;1,2,3,4,5,6:font_row=8'h18;default:font_row=0;
                endcase
                CH_0:case(row)
                    0:font_row=8'h3c;1:font_row=8'h66;2,3,4,5:font_row=8'hc3;
                    6:font_row=8'h66;7:font_row=8'h3c;
                endcase
                CH_1:case(row)
                    0:font_row=8'h18;1:font_row=8'h38;2,3,4,5,6:font_row=8'h18;
                    7:font_row=8'h7e;
                endcase
                CH_2:case(row)
                    0:font_row=8'h3c;1:font_row=8'h66;2:font_row=8'h06;3:font_row=8'h0c;
                    4:font_row=8'h18;5:font_row=8'h30;6:font_row=8'h60;7:font_row=8'h7e;
                endcase
                CH_3:case(row)
                    0:font_row=8'h7e;1:font_row=8'h0c;2:font_row=8'h18;3:font_row=8'h0c;
                    4,5:font_row=8'h06;6:font_row=8'h66;7:font_row=8'h3c;
                endcase
                CH_4:case(row)
                    0:font_row=8'h0c;1:font_row=8'h1c;2:font_row=8'h3c;3:font_row=8'h6c;
                    4:font_row=8'hcc;5:font_row=8'hfe;6,7:font_row=8'h0c;
                endcase
                CH_5:case(row)
                    0:font_row=8'h7e;1,2:font_row=8'h60;3:font_row=8'h7c;
                    4,5:font_row=8'h06;6:font_row=8'h66;7:font_row=8'h3c;
                endcase
                CH_6:case(row)
                    0:font_row=8'h1c;1:font_row=8'h30;2:font_row=8'h60;3:font_row=8'h7c;
                    4,5,6:font_row=8'h66;7:font_row=8'h3c;
                endcase
                CH_7:case(row)
                    0:font_row=8'h7e;1:font_row=8'h06;2:font_row=8'h0c;3:font_row=8'h18;
                    4,5,6,7:font_row=8'h30;
                endcase
                CH_8:case(row)
                    0:font_row=8'h3c;1,2:font_row=8'h66;3:font_row=8'h3c;
                    4,5,6:font_row=8'h66;7:font_row=8'h3c;
                endcase
                CH_9:case(row)
                    0:font_row=8'h3c;1,2:font_row=8'h66;3:font_row=8'h3e;
                    4:font_row=8'h06;5:font_row=8'h0c;6:font_row=8'h18;7:font_row=8'h70;
                endcase
                CH_PLUS:case(row)
                    1,2,4,5:font_row=8'h18;3:font_row=8'h7e;default:font_row=0;
                endcase
                CH_MINUS:case(row)
                    3:font_row=8'h7e;default:font_row=0;
                endcase
                CH_DOT:case(row)
                    6,7:font_row=8'h18;default:font_row=0;
                endcase
                CH_Z:case(row)
                    0:font_row=8'hff;1:font_row=8'h06;2:font_row=8'h0c;3:font_row=8'h18;
                    4:font_row=8'h30;5:font_row=8'h60;6:font_row=8'hff;default:font_row=0;
                endcase
                CH_M:case(row)
                    0:font_row=8'hc3;1:font_row=8'he7;2:font_row=8'hff;3:font_row=8'hdb;
                    4,5,6:font_row=8'hc3;default:font_row=0;
                endcase
                CH_X:case(row)
                    0,1:font_row=8'hc3;2:font_row=8'h66;3:font_row=8'h3c;
                    4:font_row=8'h3c;5:font_row=8'h66;6:font_row=8'hc3;default:font_row=0;
                endcase
                default:font_row=0;
            endcase
        end
    endfunction

    function [4:0] brightness_value_char;
        input [2:0] level;
        input [1:0] index;
        begin
            brightness_value_char=CH_SPACE;
            case(index)
                0:case(level)
                    0,1:brightness_value_char=CH_MINUS;
                    2:brightness_value_char=CH_0;
                    default:brightness_value_char=CH_PLUS;
                endcase
                1:case(level)
                    0,4:brightness_value_char=LUT_ONLY ? CH_3 : CH_6;
                    1,3:brightness_value_char=LUT_ONLY ? CH_1 : CH_3;
                    default:brightness_value_char=CH_SPACE;
                endcase
                2:case(level)
                    0,4:brightness_value_char=LUT_ONLY ? CH_2 : CH_4;
                    1,3:brightness_value_char=LUT_ONLY ? CH_6 : CH_2;
                    default:brightness_value_char=CH_SPACE;
                endcase
                default:brightness_value_char=CH_SPACE;
            endcase
        end
    endfunction

    function [4:0] contrast_value_char;
        input [2:0] level;
        input [1:0] index;
        begin
            contrast_value_char=CH_SPACE;
            case(index)
                0:contrast_value_char=level>=2 ? CH_1 : CH_SPACE;
                1:case(level)
                    0:contrast_value_char=CH_7;
                    1:contrast_value_char=CH_8;
                    2:contrast_value_char=CH_0;
                    3:contrast_value_char=CH_1;
                    default:contrast_value_char=CH_2;
                endcase
                2:case(level)
                    0,4:contrast_value_char=CH_5;
                    1:contrast_value_char=CH_8;
                    2:contrast_value_char=CH_0;
                    default:contrast_value_char=CH_3;
                endcase
            endcase
        end
    endfunction

    function [4:0] scale_value_char;
        input [2:0] level;
        input [1:0] index;
        begin
            scale_value_char=CH_SPACE;
            case(index)
                0:scale_value_char=level>=2 ? CH_1 : CH_0;
                1:scale_value_char=CH_DOT;
                2:case(level)
                    0,4:scale_value_char=CH_5;
                    1:scale_value_char=CH_7;
                    3:scale_value_char=CH_2;
                    default:scale_value_char=CH_0;
                endcase
                3:case(level)
                    1,3:scale_value_char=CH_5;
                    default:scale_value_char=CH_0;
                endcase
            endcase
        end
    endfunction

    function [4:0] zoom_value_char;
        input enabled;
        input [1:0] index;
        begin
            case(index)
                0:zoom_value_char=enabled ? (V5_CONTROLS&&zoom_scale==2 ? CH_4 : CH_2) : CH_1;
                1:zoom_value_char=CH_X;
                default:zoom_value_char=CH_SPACE;
            endcase
        end
    endfunction

    function [4:0] mono_value_char;
        input enabled;
        input [1:0] index;
        begin
            if(enabled)case(index)
                0:mono_value_char=CH_O;1:mono_value_char=CH_N;
                default:mono_value_char=CH_SPACE;
            endcase
            else case(index)
                0:mono_value_char=CH_O;1,2:mono_value_char=CH_F;
                default:mono_value_char=CH_SPACE;
            endcase
        end
    endfunction

    function [7:0] adjust_channel;
        input [7:0] value;
        input [2:0] brightness;
        input [2:0] contrast;
        reg signed [8:0] centered;
        reg signed [9:0] scaled,offset_value;
        reg signed [10:0] result_value;
        begin
            centered = $signed({1'b0,value})-9'sd128;
            case(contrast)
                0:scaled=centered>>>1;
                1:scaled=centered-(centered>>>2);
                3:scaled=centered+(centered>>>2);
                4:scaled=centered+(centered>>>1);
                default:scaled=centered;
            endcase
            case(brightness)
                0:offset_value=-64;
                1:offset_value=-32;
                3:offset_value=32;
                4:offset_value=64;
                default:offset_value=0;
            endcase
            result_value=scaled+11'sd128+offset_value;
            if(result_value<0)adjust_channel=0;
            else if(result_value>255)adjust_channel=255;
            else adjust_channel=result_value[7:0];
        end
    endfunction

    function [7:0] saturate_channel;
        input [7:0] value;
        input [7:0] luma;
        input [2:0] saturation;
        reg signed [8:0] delta;
        reg signed [9:0] scaled_delta;
        reg signed [10:0] result_value;
        begin
            delta=$signed({1'b0,value})-$signed({1'b0,luma});
            case(saturation)
                0:scaled_delta=delta>>>1;
                1:scaled_delta=delta-(delta>>>2);
                3:scaled_delta=delta+(delta>>>2);
                4:scaled_delta=delta+(delta>>>1);
                default:scaled_delta=delta;
            endcase
            result_value=$signed({1'b0,luma})+scaled_delta;
            if(result_value<0)saturate_channel=0;
            else if(result_value>255)saturate_channel=255;
            else saturate_channel=result_value[7:0];
        end
    endfunction

    function [10:0] waveform_y_of;
        input [15:0] sample;
        reg signed [15:0] signed_sample;
        reg signed [12:0] position;
        begin
            signed_sample=$signed(sample);
            position=WAVE_CENTER-(signed_sample>>>8);
            if(position<WAVE_TOP+1)waveform_y_of=WAVE_TOP+1;
            else if(position>WAVE_BOTTOM-2)waveform_y_of=WAVE_BOTTOM-2;
            else waveform_y_of=position[10:0];
        end
    endfunction

    wire [7:0] adjusted_r_next = (LUT_ONLY || color_lut_active) ? rgb_in[23:16] :
        adjust_channel(rgb_in[23:16],brightness_level,contrast_level);
    wire [7:0] adjusted_g_next = (LUT_ONLY || color_lut_active) ? rgb_in[15:8] :
        adjust_channel(rgb_in[15:8],brightness_level,contrast_level);
    wire [7:0] adjusted_b_next = (LUT_ONLY || color_lut_active) ? rgb_in[7:0] :
        adjust_channel(rgb_in[7:0],brightness_level,contrast_level);
    wire [10:0] grayscale_sum_next = (adjusted_r_next<<1)+(adjusted_g_next<<2)+
                                     adjusted_g_next+adjusted_b_next+4;
    wire [7:0] grayscale_next = grayscale_sum_next[10:3];
    wire [7:0] color_r_next = grayscale_enable ? grayscale_next :
        (color_lut_active ? adjusted_r_next :
        saturate_channel(adjusted_r_next,grayscale_next,saturation_level));
    wire [7:0] color_g_next = grayscale_enable ? grayscale_next :
        (color_lut_active ? adjusted_g_next :
        saturate_channel(adjusted_g_next,grayscale_next,saturation_level));
    wire [7:0] color_b_next = grayscale_enable ? grayscale_next :
        (color_lut_active ? adjusted_b_next :
        saturate_channel(adjusted_b_next,grayscale_next,saturation_level));

    reg [7:0] color_r_q, color_g_q, color_b_q;
    reg [23:0] rgb_in_q;
    reg [10:0] x_q, y_q;
    reg [3:0] image_index_q;
    reg [2:0] transition_mode_q;
    reg [4:0] fade_gain_q;
    reg overlay_enable_q, osd_visible_q, zoom_mode_q, grayscale_enable_q;
    reg [2:0] brightness_level_q, contrast_level_q, saturation_level_q;
    reg [1:0] gamma_mode_q,temperature_mode_q;
    reg [3:0] quality_selection_q;
    reg [2:0] volume_level_q;
    reg [1:0] flash_rate_q,flash_duty_q;
    reg [15:0] audio_peak_q;
    reg [31:0] audio_limited_q,audio_clipped_q;
    reg [5:0] transition_settings_q;
    wire transition_reveal;
    wire [7:0] transition_alpha;
    wire [10:0] transition_old_x,transition_old_y,transition_new_x,transition_new_y;
    wire transition_dual_source;
    transition_coordinate_generator #(.WIDTH(WIDTH),.HEIGHT(HEIGHT)) transition_shape(
        .mode(transition_mode_q),.progress({fade_gain_q,2'b00}),.x(x_q),.y(y_q),
        .select_new(transition_reveal),.new_alpha(transition_alpha),
        .old_x(transition_old_x),.old_y(transition_old_y),.new_x(transition_new_x),
        .new_y(transition_new_y),.dual_source(transition_dual_source));

    wire [7:0] shared_font_bits;
    wire [13:0] scroll_sum = {1'b0,scroll_position}+x_q;
    wire [13:0] text_relative_x = scroll_sum-WIDTH;
    wire [3:0] character_index = text_relative_x[7:4];
    wire [2:0] character_x = text_relative_x[3:1];
    wire [10:0] text_relative_y = y_q-(BANNER_Y+2);
    wire [2:0] character_y = text_relative_y[3:1];
    wire [7:0] selected_font_row = shared_font_bits;
    wire inside_banner = ENABLE && AUXILIARY_OVERLAY && overlay_enable_q &&
                         y_q>=BANNER_Y && y_q<BANNER_Y+BANNER_HEIGHT;
    wire inside_text = inside_banner && y_q>=BANNER_Y+2 && y_q<BANNER_Y+18 &&
                       scroll_sum>=WIDTH && scroll_sum<WIDTH+TEXT_PIXELS;
    assign banner_pixel = inside_banner;
    assign text_pixel = inside_text && selected_font_row[~character_x];

    reg [15:0] wave_buffer [0:AUDIO_SAMPLES-1];
    reg [AUDIO_AW-1:0] wave_write;
    reg [AUDIO_AW:0] wave_count;
    reg wave_ready;
    reg [15:0] wave_sample_q;
    wire [10+AUDIO_AW:0] wave_scaled_x = x*AUDIO_SAMPLES;
    wire [AUDIO_AW-1:0] wave_offset = wave_scaled_x/WIDTH;
    wire [AUDIO_AW:0] wave_sum = wave_write+wave_offset;
    wire [AUDIO_AW-1:0] wave_index = wave_sum>=AUDIO_SAMPLES ? wave_sum-AUDIO_SAMPLES : wave_sum;
    wire [15:0] captured_sample;
    wire captured_ready;
    generate if(FRAME_CAPTURE)begin: stable_waveform
        audio_waveform_capture capture(.clk(clk),.rst(rst),.frame_tick(frame_tick),
            .sample_valid(audio_sample_valid),.sample(audio_sample),
            .read_index(wave_offset),.read_sample(captured_sample),.ready(captured_ready));
    end else begin: rolling_waveform
        assign captured_sample=wave_sample_q;assign captured_ready=wave_ready;
    end endgenerate
    wire [10:0] waveform_y = waveform_y_of(captured_sample);
    wire inside_wave_panel = ENABLE && WAVEFORM_OVERLAY && overlay_enable_q && captured_ready &&
                             y_q>=WAVE_TOP && y_q<WAVE_BOTTOM;
    assign waveform_pixel = inside_wave_panel && y_q+1>=waveform_y && y_q<=waveform_y+1;
    assign waveform_panel = inside_wave_panel;

    wire inside_osd = ENABLE && osd_visible_q && x_q>=8 && x_q<176 && y_q>=8 && y_q<(LUT_ONLY ? 306 : 104);
    wire gamma_bar=LUT_ONLY && inside_osd && x_q>=48 && x_q<128 && y_q>=108 && y_q<116;
    wire temp_bar=LUT_ONLY && inside_osd && x_q>=48 && x_q<128 && y_q>=126 && y_q<134;
    wire gamma_fill=gamma_bar && x_q<48+((gamma_mode_q+1)*24);
    wire temp_fill=temp_bar && x_q<48+((temperature_mode_q+1)*24);
    wire gamma_label=LUT_ONLY && inside_osd && x_q>=16 && x_q<24 && y_q>=108 && y_q<116;
    wire temp_label=LUT_ONLY && inside_osd && x_q>=16 && x_q<24 && y_q>=126 && y_q<134;
    wire [7:0] extra_font=shared_font_bits;
    wire effect_row=LUT_ONLY && inside_osd && y_q>=144 && y_q<152;
    wire duration_row=LUT_ONLY && inside_osd && y_q>=162 && y_q<170;
    wire easing_row=LUT_ONLY && inside_osd && y_q>=180 && y_q<188;
    wire volume_row=LUT_ONLY && inside_osd && y_q>=198 && y_q<206;
    wire peak_row=LUT_ONLY && inside_osd && y_q>=216 && y_q<224;
    wire limited_row=LUT_ONLY && inside_osd && y_q>=234 && y_q<242;
    wire clipped_row=LUT_ONLY && inside_osd && y_q>=252 && y_q<260;
    wire flash_rate_row=LUT_ONLY && inside_osd && y_q>=270 && y_q<278;
    wire flash_duty_row=LUT_ONLY && inside_osd && y_q>=288 && y_q<296;
    wire stats_row=peak_row||limited_row||clipped_row;
    wire settings_row=effect_row || duration_row || easing_row || volume_row || stats_row ||
        flash_rate_row || flash_duty_row;
    wire [2:0] settings_y=flash_rate_row ? y_q-270 : flash_duty_row ? y_q-288 :
        effect_row ? y_q-144 : (duration_row ? y_q-162 :
        (volume_row ? y_q-198 : (peak_row ? y_q-216 :
        (limited_row ? y_q-234 : (clipped_row ? y_q-252 : y_q-180)))));
    wire [31:0] stats_value=peak_row ? {16'd0,audio_peak_q} :
        (limited_row ? audio_limited_q : audio_clipped_q);
    wire [2:0] stats_column=(x_q-48)>>3;
    wire [3:0] stats_nibble=stats_value>>{~stats_column,2'b00};
    reg [4:0] stats_character;
    always @* begin
        case(stats_nibble)
            10:stats_character=CH_A;11:stats_character=CH_B;12:stats_character=CH_C;
            13:stats_character=CH_D;14:stats_character=CH_E;15:stats_character=CH_F;
            default:stats_character=CH_0+stats_nibble;
        endcase
    end
    reg [4:0] settings_char;
    always @* begin
        settings_char=CH_SPACE;
        if(x_q>=16 && x_q<24)settings_char=volume_row ? CH_A : (easing_row ? CH_S : CH_F);
        else if(x_q>=24 && x_q<32)settings_char=effect_row ? CH_X :
            (duration_row ? CH_R : CH_SPACE);
        else if(x_q>=48 && x_q<56)begin
            if(volume_row)settings_char=CH_0+volume_level_q;
            else if(effect_row)settings_char=CH_0+transition_settings_q[2:0];
            else if(duration_row)settings_char=transition_settings_q[4:3]==0 ? CH_1 :
                (transition_settings_q[4:3]==1 ? CH_3 : CH_6);
            else settings_char=CH_O;
        end else if(x_q>=56 && x_q<64)begin
            if(duration_row)settings_char=transition_settings_q[4:3]==0 ? CH_6 :
                (transition_settings_q[4:3]==1 ? CH_2 : CH_4);
            else if(easing_row)settings_char=transition_settings_q[5] ? CH_N : CH_F;
        end else if(x_q>=64 && x_q<72 && easing_row && !transition_settings_q[5])
            settings_char=CH_F;
        if(stats_row)begin
            settings_char=CH_SPACE;
            if(x_q>=16&&x_q<24)settings_char=peak_row ? CH_P : (limited_row ? CH_L : CH_C);
            else if(x_q>=48&&x_q<112)settings_char=stats_character;
        end
        if(flash_rate_row||flash_duty_row)begin
            settings_char=CH_SPACE;
            if(x_q>=16&&x_q<24)settings_char=CH_F;
            else if(x_q>=24&&x_q<32)settings_char=flash_rate_row ? CH_R : CH_D;
            else if(x_q>=48&&x_q<56)settings_char=flash_rate_row ?
                (flash_rate_q==2 ? CH_5 : CH_4) : CH_1;
            else if(x_q>=56&&x_q<64)settings_char=flash_rate_row ?
                (flash_rate_q==1 ? CH_5 : CH_0) : CH_MINUS;
            else if(x_q>=64&&x_q<72&&flash_duty_row)settings_char=CH_3+flash_duty_q;
        end
    end
    wire [7:0] settings_font=shared_font_bits;
    wire osd_label_1 = inside_osd && x_q>=12 && x_q<36 && y_q>=16 && y_q<24;
    wire osd_label_2 = inside_osd && x_q>=12 && x_q<36 && y_q>=34 && y_q<42;
    wire osd_label_3 = inside_osd && x_q>=12 && x_q<36 && y_q>=52 && y_q<60;
    wire osd_label_4 = inside_osd && x_q>=12 && x_q<36 && y_q>=70 && y_q<78;
    wire osd_label_5 = inside_osd && x_q>=12 && x_q<36 && y_q>=88 && y_q<96;
    wire osd_value_1 = inside_osd && x_q>=136 && x_q<168 && y_q>=16 && y_q<24;
    wire osd_value_2 = inside_osd && x_q>=136 && x_q<168 && y_q>=34 && y_q<42;
    wire osd_value_3 = inside_osd && x_q>=136 && x_q<168 && y_q>=52 && y_q<60;
    wire osd_value_4 = inside_osd && x_q>=136 && x_q<152 && y_q>=70 && y_q<78;
    wire osd_value_5 = inside_osd && x_q>=136 && x_q<160 && y_q>=88 && y_q<96;
    wire osd_text_region = osd_label_1 || osd_label_2 || osd_label_3 ||
                           osd_label_4 || osd_label_5 || osd_value_1 ||
                           osd_value_2 || osd_value_3 || osd_value_4 || osd_value_5;
    wire [1:0] osd_label_char_index = (x_q-12)>>3;
    wire [1:0] osd_value_char_index = (x_q-136)>>3;
    wire [2:0] osd_char_x = (osd_value_1||osd_value_2||osd_value_3||
                             osd_value_4||osd_value_5) ? x_q-136 : x_q-12;
    wire [2:0] osd_char_y = (osd_label_1||osd_value_1) ? y_q-16 :
                               ((osd_label_2||osd_value_2) ? y_q-34 :
                               ((osd_label_3||osd_value_3) ? y_q-52 :
                               ((osd_label_4||osd_value_4) ? y_q-70 : y_q-88)));
    reg [4:0] osd_character;
    always @* begin
        osd_character=CH_SPACE;
        if(osd_label_1)case(osd_label_char_index)
            0:osd_character=CH_B;1:osd_character=CH_R;2:osd_character=CH_I;
            default:osd_character=CH_SPACE;
        endcase
        else if(osd_label_2)case(osd_label_char_index)
            0:osd_character=CH_C;1:osd_character=CH_O;2:osd_character=CH_N;
            default:osd_character=CH_SPACE;
        endcase
        else if(osd_label_3)case(osd_label_char_index)
            0:osd_character=CH_S;1:osd_character=CH_A;2:osd_character=CH_T;
            default:osd_character=CH_SPACE;
        endcase
        else if(osd_label_4)case(osd_label_char_index)
            0:osd_character=CH_Z;1:osd_character=CH_O;2:osd_character=CH_M;
            default:osd_character=CH_SPACE;
        endcase
        else if(osd_label_5)case(osd_label_char_index)
            0:osd_character=CH_M;1:osd_character=CH_O;2:osd_character=CH_N;
            default:osd_character=CH_SPACE;
        endcase
        else if(osd_value_1)
            osd_character=brightness_value_char(brightness_level_q,osd_value_char_index);
        else if(osd_value_2)
            osd_character=LUT_ONLY ? contrast_value_char(contrast_level_q,osd_value_char_index) :
                scale_value_char(contrast_level_q,osd_value_char_index);
        else if(osd_value_3)
            osd_character=scale_value_char(saturation_level_q,osd_value_char_index);
        else if(osd_value_4)
            osd_character=zoom_value_char(zoom_mode_q,osd_value_char_index);
        else if(osd_value_5)
            osd_character=mono_value_char(grayscale_enable_q,osd_value_char_index);
    end

    wire [4:0] shared_character=inside_osd ?
        (settings_row ? settings_char : (gamma_label ? CH_G :
        (temp_label ? CH_T : osd_character))) : ticker_char(character_index);
    wire [2:0] shared_font_y=inside_osd ?
        (settings_row ? settings_y : (gamma_label ? y_q-108 :
        (temp_label ? y_q-126 : osd_char_y))) : character_y;
    assign shared_font_bits=font_row(shared_character,shared_font_y);
    wire [7:0] osd_font_bits = shared_font_bits;
    wire osd_text_pixel = osd_text_region && osd_font_bits[~osd_char_x];
    wire brightness_bar = inside_osd && x_q>=48 && x_q<128 && y_q>=16 && y_q<24;
    wire contrast_bar = inside_osd && x_q>=48 && x_q<128 && y_q>=34 && y_q<42;
    wire saturation_bar = inside_osd && x_q>=48 && x_q<128 && y_q>=52 && y_q<60;
    wire brightness_fill = brightness_bar && x_q-48 < (brightness_level_q+1)*16;
    wire contrast_fill = contrast_bar && x_q-48 < (contrast_level_q+1)*16;
    wire saturation_fill = saturation_bar && x_q-48 < (saturation_level_q+1)*16;
    assign osd_pixel = inside_osd;

    reg [23:0] text_color;
    reg [12:0] fade_r, fade_g, fade_b;
    reg [7:0] base_r, base_g, base_b;
    reg [7:0] layer_r, layer_g, layer_b;
    reg [9:0] mixed_r, mixed_g, mixed_b;
    always @* begin
        case(image_index_q)
            0:text_color=24'hffe060;
            1:text_color=24'h60ffff;
            2:text_color=24'hff80e0;
            default:text_color=24'h80ff80;
        endcase
        if(transition_mode_q==0)begin
            fade_r=color_r_q*fade_gain_q;
            fade_g=color_g_q*fade_gain_q;
            fade_b=color_b_q*fade_gain_q;
            base_r=(fade_r+8)>>4; base_g=(fade_g+8)>>4; base_b=(fade_b+8)>>4;
        end else begin
            fade_r=0;fade_g=0;fade_b=0;
            base_r=color_r_q;base_g=color_g_q;base_b=color_b_q;

            if(transition_mode_q!=2 && !transition_reveal)begin
                base_r=0;base_g=0;base_b=0;
            end
        end
        layer_r=base_r; layer_g=base_g; layer_b=base_b;
        mixed_r=0; mixed_g=0; mixed_b=0;
        if(inside_wave_panel)begin
            layer_r=base_r>>1; layer_g=base_g>>1; layer_b=base_b>>1;
            if(waveform_pixel)begin layer_r=8'h40;layer_g=8'hff;layer_b=8'h70;end
        end
        if(inside_banner)begin
            layer_r=base_r>>1;layer_g=base_g>>1;layer_b=base_b>>1;
        end
        if(text_pixel)begin
            mixed_r=layer_r+text_color[23:16]*3+2;
            mixed_g=layer_g+text_color[15:8]*3+2;
            mixed_b=layer_b+text_color[7:0]*3+2;
            layer_r=mixed_r>>2;layer_g=mixed_g>>2;layer_b=mixed_b>>2;
        end
        if(inside_osd)begin
            layer_r=base_r>>2;layer_g=base_g>>2;layer_b=base_b>>2;
            if(brightness_bar||contrast_bar||saturation_bar||gamma_bar||temp_bar)begin
                layer_r=8'h38;layer_g=8'h38;layer_b=8'h40;
            end
            if(brightness_fill)begin layer_r=8'hff;layer_g=8'hb0;layer_b=8'h30;end
            if(contrast_fill)begin layer_r=8'h40;layer_g=8'he0;layer_b=8'hff;end
            if(saturation_fill)begin layer_r=8'hff;layer_g=8'h50;layer_b=8'hc8;end
            if(gamma_fill)begin layer_r=8'hb0;layer_g=8'hff;layer_b=8'h80;end
            if(temp_fill)begin layer_r=8'hff;layer_g=8'ha0;layer_b=8'h70;end
            if((gamma_label||temp_label)&&extra_font[~x_q[2:0]])begin
                layer_r=255;layer_g=255;layer_b=255;
            end
            if(LUT_ONLY && x_q<11 &&
                ((quality_selection_q==0&&y_q>=16&&y_q<24)||
                 (quality_selection_q==1&&y_q>=34&&y_q<42)||
                 (quality_selection_q==2&&y_q>=52&&y_q<60)||
                 (quality_selection_q==3&&y_q>=108&&y_q<116)||
                 (quality_selection_q==4&&y_q>=126&&y_q<134)||
                 (quality_selection_q==5&&effect_row)||
                 (quality_selection_q==6&&duration_row)||
                 (quality_selection_q==7&&easing_row)||
                 (quality_selection_q==8&&volume_row)||
                 (quality_selection_q==9&&flash_rate_row)||
                 (quality_selection_q==10&&flash_duty_row)))begin
                layer_r=255;layer_g=255;layer_b=255;
            end
            if(osd_text_pixel)begin layer_r=8'hff;layer_g=8'hff;layer_b=8'hff;end
            if(settings_row && settings_font[~x_q[2:0]])begin
                layer_r=255;layer_g=255;layer_b=255;
            end
        end
        rgb_out=ENABLE ? {layer_r,layer_g,layer_b} : rgb_in_q;
    end

    always @(posedge clk or posedge rst) begin
        if(rst)begin
            scroll_position<=0; wave_write<=0; wave_count<=0; wave_ready<=0; wave_sample_q<=0;
            color_r_q<=0;color_g_q<=0;color_b_q<=0;rgb_in_q<=0;
            x_q<=0;y_q<=0;image_index_q<=0;transition_mode_q<=0;fade_gain_q<=0;
            overlay_enable_q<=0;osd_visible_q<=0;zoom_mode_q<=0;grayscale_enable_q<=0;
            brightness_level_q<=0;contrast_level_q<=0;saturation_level_q<=0;
            gamma_mode_q<=1;temperature_mode_q<=1;quality_selection_q<=0;volume_level_q<=7;
            flash_rate_q<=1;flash_duty_q<=1;
            audio_peak_q<=0;audio_limited_q<=0;audio_clipped_q<=0;
            transition_settings_q<=0;
        end else begin
            color_r_q<=color_r_next;color_g_q<=color_g_next;color_b_q<=color_b_next;
            rgb_in_q<=rgb_in;x_q<=x;y_q<=y;image_index_q<=image_index;
            transition_mode_q<=transition_mode;fade_gain_q<=fade_gain;
            overlay_enable_q<=overlay_enable;osd_visible_q<=osd_visible;
            zoom_mode_q<=zoom_mode;grayscale_enable_q<=grayscale_enable;
            brightness_level_q<=brightness_level;contrast_level_q<=contrast_level;
            saturation_level_q<=saturation_level;
            transition_settings_q<=transition_settings;
            gamma_mode_q<=gamma_mode;temperature_mode_q<=temperature_mode;
            quality_selection_q<=quality_selection;
            volume_level_q<=volume_level;
            flash_rate_q<=flash_rate;flash_duty_q<=flash_duty;
            if(frame_tick)begin
                audio_peak_q<=audio_peak_absolute;
                audio_limited_q<=audio_limited_count;audio_clipped_q<=audio_clipped_count;
            end

            if(!FRAME_CAPTURE)wave_sample_q<=wave_buffer[wave_index];
            if(ENABLE && AUXILIARY_OVERLAY && frame_tick)begin
                if(scroll_position>=SCROLL_LIMIT-SCROLL_STEP) scroll_position<=0;
                else scroll_position<=scroll_position+SCROLL_STEP;
            end
            if(ENABLE && WAVEFORM_OVERLAY && !FRAME_CAPTURE && audio_sample_valid)begin
                wave_buffer[wave_write]<=audio_sample;
                if(wave_write==AUDIO_SAMPLES-1)wave_write<=0;
                else wave_write<=wave_write+1'b1;
                if(!wave_ready)begin
                    if(wave_count==AUDIO_SAMPLES-1)wave_ready<=1;
                    else wave_count<=wave_count+1'b1;
                end
            end
        end
    end
endmodule
