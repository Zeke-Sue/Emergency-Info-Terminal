// 构建双缓冲颜色查找表，处理亮度、对比度、Gamma及色温。
// 统计功能由参数控制；同亮度连续像素采用前递避免计数冲突。
`timescale 1ns/1ps

module image_quality_engine #(
    parameter integer FRAME_PIXELS=307200, SEPARATE_STATS=0, SMOOTH_PARAMETERS=1,
    parameter integer ENABLE_STATISTICS=1
)(
    input wire clk,
    input wire rst,
    input wire frame_tick,
    input wire pixel_valid,
    input wire enable,
    input wire alarm_bypass,
    input wire [23:0] rgb_in,
    input wire [23:0] histogram_rgb,
    input wire histogram_valid,
    input wire signed [8:0] target_brightness,
    input wire [7:0] target_contrast_q7,
    input wire [1:0] gamma_mode,
    input wire [1:0] temperature_mode,
    input wire auto_contrast_enable,
    input wire [7:0] histogram_query,
    input wire [5:0] histogram_column,
    output reg [19:0] histogram_value,
    output wire [19:0] histogram_column_value,
    output reg [7:0] low_cut,
    output reg [7:0] high_cut,
    output reg lut_ready,
    output wire [23:0] rgb_out
);
    localparam ST_INIT=0,ST_IDLE=1,ST_SCAN=2,ST_DIVIDE=3,ST_BUILD=4,ST_BUILD_WRITE=5,
        ST_FILTER=6,ST_CONTRAST=7,ST_GAMMA=8;
    reg [20:0] low_threshold,high_threshold;
    reg [19:0] sample_count;
    reg [7:0] sample_mod200;
    reg [12:0] sample_quotient200;
    wire accumulation_write;
    wire [20:0] final_count={1'b0,sample_count}+accumulation_write;
    wire [20:0] final_tail={8'd0,sample_quotient200}+
        ((sample_mod200!=0 || accumulation_write) ? 21'd1 : 21'd0);

    reg [3:0] state;
    reg [7:0] index,index_d;
    reg scan_valid,scan_issued_done;
    reg [20:0] cumulative;
    reg [20:0] histogram_group_sum;
    reg low_found,high_found;
    wire signed [8:0] current_brightness,current_contrast_signed;
    wire [7:0] current_contrast_q7=current_contrast_signed[7:0];
    wire signed [6:0] gamma_weight;
    wire signed [5:0] temperature_r,temperature_b;
    wire smooth_tick=frame_tick && enable && state==ST_IDLE;
    wire smooth_busy;
    generate if(SMOOTH_PARAMETERS)begin: smooth_parameters
    quality_parameter_smoother parameter_smoother(
        .clk(clk),.rst(rst),.frame_tick(smooth_tick),
        .target_brightness(target_brightness),.target_contrast(target_contrast_q7),
        .gamma_mode(gamma_mode),.temperature_mode(temperature_mode),
        .brightness(current_brightness),.contrast(current_contrast_signed),
        .gamma_weight(gamma_weight),.temperature_r(temperature_r),
        .temperature_b(temperature_b),.busy(smooth_busy));
    end else begin: frame_parameters
        reg signed [8:0] brightness_q;
        reg [7:0] contrast_q;
        reg [1:0] gamma_q,temperature_q;
        always @(posedge clk or posedge rst)
            if(rst)begin brightness_q<=0;contrast_q<=128;gamma_q<=1;temperature_q<=1;end
            else if(smooth_tick)begin
                brightness_q<=target_brightness;contrast_q<=target_contrast_q7;
                gamma_q<=gamma_mode;temperature_q<=temperature_mode;
            end
        assign current_brightness=brightness_q;
        assign current_contrast_signed={1'b0,contrast_q};
        assign gamma_weight=gamma_q==0 ? -7'sd32 : gamma_q==2 ? 7'sd32 : 7'sd0;
        assign temperature_r=temperature_q==0 ? 6'sd12 : temperature_q==2 ? -6'sd10 : 6'sd0;
        assign temperature_b=temperature_q==0 ? -6'sd12 : temperature_q==2 ? 6'sd14 : 6'sd0;
        assign smooth_busy=1'b0;
    end endgenerate
    reg active_lut,pending_lut,init_lut_bank;

    reg pixel_valid_d,last_write_valid;
    reg [7:0] luma_d,last_write_addr;
    reg [19:0] last_write_data;

    reg [7:0] divisor;
    reg [15:0] dividend,quotient;
    reg [7:0] remainder;
    reg [4:0] divide_count;
    reg [15:0] gain_q8;
    reg [7:0] applied_low,applied_high;

    function [7:0] filter_cut;
        input [7:0] current,target;
        reg [8:0] distance,step;
        begin
            distance=target>=current ? target-current : current-target;
            step=(distance+9'd3)>>2;
            filter_cut=target>=current ? current+step : current-step;
        end
    endfunction
    wire [7:0] filtered_low=filter_cut(applied_low,low_cut);
    wire [7:0] filtered_high=filter_cut(applied_high,high_cut);

    wire [23:0] stats_rgb=SEPARATE_STATS ? histogram_rgb : rgb_in;
    wire stats_valid=SEPARATE_STATS ? histogram_valid : pixel_valid;
    wire [10:0] luma_sum=(stats_rgb[23:16]<<1)+(stats_rgb[15:8]<<2)+
                         stats_rgb[15:8]+stats_rgb[7:0];
    wire [7:0] luma=luma_sum[10:3];

    wire [7:0] histogram_ra=state==ST_SCAN ? index :
        (stats_valid ? luma : histogram_query);
    wire [19:0] selected_hist;
    wire [19:0] accumulation_base=
        last_write_valid && last_write_addr==luma_d ? last_write_data : selected_hist;
    wire [19:0] accumulation_data=&accumulation_base ?
        accumulation_base : accumulation_base+1'b1;

    wire init_write=state==ST_INIT;
    wire clear_write=state==ST_SCAN && scan_valid;
    assign accumulation_write=state==ST_IDLE && pixel_valid_d;
    wire histogram_we=init_write || clear_write || accumulation_write;
    wire [7:0] histogram_wa=init_write ? index : (clear_write ? index_d : luma_d);
    wire [19:0] histogram_wd=(init_write || clear_write) ? 20'd0 : accumulation_data;
    generate if(ENABLE_STATISTICS)begin: statistics
    buffer_ram #(.DATA_WIDTH(20),.ADDR_WIDTH(8)) histogram_memory(
        .clk(clk),.we(histogram_we),.wa(histogram_wa),.ra(histogram_ra),
        .d(histogram_wd),.q(selected_hist));

    wire histogram_display_we=(state==ST_INIT && index[1:0]==0) ||
        (state==ST_SCAN && scan_valid && index_d[1:0]==3);
    wire [5:0] histogram_display_wa=state==ST_INIT ? index[7:2] : index_d[7:2];
    wire [19:0] histogram_display_wd=state==ST_INIT ? 20'd0 :
        histogram_group_sum[19:0]+selected_hist;
    buffer_ram #(.DATA_WIDTH(20),.ADDR_WIDTH(6)) histogram_display(
        .clk(clk),.we(histogram_display_we),.wa(histogram_display_wa),
        .ra(histogram_column),.d(histogram_display_wd),.q(histogram_column_value));
    end else begin: manual_only
        assign selected_hist=0;
        assign histogram_column_value=0;
    end endgenerate

    reg [7:0] lut_r_d,lut_g_d,lut_b_d,gamma_value;
    reg [7:0] mapped_q,gamma_q;
    reg signed [17:0] multiply_a,multiply_b;
    wire signed [35:0] shared_product=multiply_a*multiply_b;
    wire [7:0] map_delta=index-applied_low;
    wire [23:0] map_product=shared_product[23:0];
    wire [15:0] map_scaled=map_product[23:8];
    wire [7:0] mapped_value=!ENABLE_STATISTICS ? index : index<=applied_low ? 8'd0 :
        (index>=applied_high ? 8'd255 :
        (|map_scaled[15:8] ? 8'd255 : map_scaled[7:0]));
    wire signed [8:0] contrast_delta=$signed({1'b0,mapped_q})-9'sd128;
    wire signed [17:0] contrast_product=shared_product[17:0];
    wire signed [10:0] contrast_scaled=$signed(contrast_product)>>>7;
    wire signed [10:0] brightness_extended=
        {{2{current_brightness[8]}},current_brightness};
    wire signed [10:0] contrast_sum=contrast_scaled+11'sd128+brightness_extended;
    wire [7:0] contrasted_value=contrast_sum<0 ? 8'd0 :
        (contrast_sum>255 ? 8'd255 : contrast_sum[7:0]);
    wire [15:0] gamma_curves;
    reg [7:0] contrasted_q;
    wire [7:0] gamma_endpoint=gamma_weight<0 ? gamma_curves[15:8] : gamma_curves[7:0];
    wire signed [8:0] gamma_delta=$signed({1'b0,gamma_endpoint})-$signed({1'b0,contrasted_q});
    wire signed [6:0] gamma_amount=gamma_weight<0 ? -gamma_weight : gamma_weight;
    wire signed [15:0] gamma_product=shared_product[15:0];
    wire signed [9:0] gamma_blended=SMOOTH_PARAMETERS ?
        $signed({1'b0,contrasted_q})+((gamma_product+16'sd16)>>>5) :
        $signed({2'b0,(gamma_weight==0 ? contrasted_q : gamma_endpoint)});
    gamma_curve_rom gamma_table(.clk(clk),.address(contrasted_value),.value(gamma_curves));

    always @* begin
        if(ENABLE_STATISTICS&&state==ST_BUILD)begin
            multiply_a={10'd0,map_delta};multiply_b={2'd0,gain_q8};
        end else if(state==ST_CONTRAST)begin
            multiply_a={{9{contrast_delta[8]}},contrast_delta};
            multiply_b={10'd0,current_contrast_q7};
        end else if(SMOOTH_PARAMETERS)begin
            multiply_a={{9{gamma_delta[8]}},gamma_delta};
            multiply_b={11'd0,gamma_amount};
        end else begin
            multiply_a=0;multiply_b=0;
        end
    end
    function [7:0] clamp10;
        input signed [9:0] value;
        begin
            if(value<0) clamp10=0;
            else if(value>255) clamp10=255;
            else clamp10=value[7:0];
        end
    endfunction
    always @* begin
        if(state==ST_INIT) begin
            gamma_value=0;
            lut_r_d=index;lut_g_d=index;lut_b_d=index;
        end else begin
            gamma_value=gamma_q;
            lut_r_d=clamp10($signed({1'b0,gamma_value})+temperature_r);
            lut_g_d=gamma_value;
            lut_b_d=clamp10($signed({1'b0,gamma_value})+temperature_b);
        end
    end

    wire lut_we=state==ST_INIT || state==ST_BUILD_WRITE;
    wire [7:0] lut_r_q,lut_g_q,lut_b_q;
    wire [8:0] lut_write_address={state==ST_INIT ? init_lut_bank : !active_lut,index};
    buffer_ram #(.DATA_WIDTH(8),.ADDR_WIDTH(9)) red_lut(
        .clk(clk),.we(lut_we),.wa(lut_write_address),.ra({active_lut,rgb_in[23:16]}),.d(lut_r_d),.q(lut_r_q));
    buffer_ram #(.DATA_WIDTH(8),.ADDR_WIDTH(9)) green_lut(
        .clk(clk),.we(lut_we),.wa(lut_write_address),.ra({active_lut,rgb_in[15:8]}),.d(lut_g_d),.q(lut_g_q));
    buffer_ram #(.DATA_WIDTH(8),.ADDR_WIDTH(9)) blue_lut(
        .clk(clk),.we(lut_we),.wa(lut_write_address),.ra({active_lut,rgb_in[7:0]}),.d(lut_b_d),.q(lut_b_q));

    reg [23:0] rgb_q;
    reg enable_q,alarm_bypass_q;
    assign rgb_out=(alarm_bypass_q || !enable_q) ? rgb_q :
                   {lut_r_q,lut_g_q,lut_b_q};

    wire [20:0] scan_sum=cumulative+{1'b0,selected_hist};
    wire [7:0] scan_low=(!low_found && scan_sum>=low_threshold) ? index_d : low_cut;
    wire [7:0] scan_high=(!high_found && scan_sum>=high_threshold) ? index_d : high_cut;
    wire [8:0] shifted_remainder={remainder,dividend[15]};

    always @(posedge clk or posedge rst) begin
        if(rst) begin
            state<=ST_INIT;index<=0;index_d<=0;
            scan_valid<=0;scan_issued_done<=0;cumulative<=0;histogram_group_sum<=0;
            low_found<=0;high_found<=0;low_cut<=0;high_cut<=255;lut_ready<=0;
            active_lut<=0;pending_lut<=0;init_lut_bank<=0;
            sample_count<=0;sample_mod200<=0;sample_quotient200<=0;
            low_threshold<=0;high_threshold<=0;
            pixel_valid_d<=0;luma_d<=0;
            last_write_valid<=0;last_write_addr<=0;
            last_write_data<=0;histogram_value<=0;
            divisor<=255;dividend<=0;quotient<=0;remainder<=0;
            divide_count<=0;gain_q8<=256;
            applied_low<=0;applied_high<=255;
            rgb_q<=0;enable_q<=0;alarm_bypass_q<=0;
            contrasted_q<=0;mapped_q<=0;gamma_q<=0;
        end else begin
            rgb_q<=rgb_in;enable_q<=enable;alarm_bypass_q<=alarm_bypass;
            pixel_valid_d<=ENABLE_STATISTICS&&stats_valid && enable;
            luma_d<=luma;
            if(!ENABLE_STATISTICS)histogram_value<=0;
            else if(!stats_valid)
                histogram_value<=selected_hist;

            if(accumulation_write) begin
                sample_count<=sample_count+1'b1;
                if(sample_mod200==199)begin
                    sample_mod200<=0;sample_quotient200<=sample_quotient200+1'b1;
                end else sample_mod200<=sample_mod200+1'b1;
                last_write_valid<=1;
                last_write_addr<=luma_d;
                last_write_data<=accumulation_data;
            end

            case(state)
                ST_INIT:begin
                    if(index==255) begin
                        index<=0;init_lut_bank<=1;
                        if(init_lut_bank)begin state<=ST_IDLE;lut_ready<=1;end
                        last_write_valid<=0;
                    end else index<=index+1'b1;
                end
                ST_IDLE:begin
                    if(frame_tick && pending_lut)begin
                        active_lut<=!active_lut;pending_lut<=0;
                    end
                    if(frame_tick && enable) begin
                        low_threshold<=final_tail;
                        high_threshold<=final_count-final_tail;
                        sample_count<=0;sample_mod200<=0;sample_quotient200<=0;
                        index<=0;index_d<=0;scan_valid<=0;scan_issued_done<=0;
                        cumulative<=0;low_found<=0;high_found<=0;
                        lut_ready<=0;last_write_valid<=0;pixel_valid_d<=0;
                        state<=ENABLE_STATISTICS ? ST_SCAN : ST_BUILD;
                    end
                end
                ST_SCAN:if(ENABLE_STATISTICS)begin
                    if(!scan_issued_done) begin
                        index_d<=index;scan_valid<=1;
                        if(index==255) scan_issued_done<=1;
                        else index<=index+1'b1;
                    end else scan_valid<=0;
                    if(scan_valid) begin
                        cumulative<=scan_sum;
                        if(index_d[1:0]==0) histogram_group_sum<={1'b0,selected_hist};
                        else if(index_d[1:0]==3) histogram_group_sum<=0;
                        else histogram_group_sum<=histogram_group_sum+
                            {1'b0,selected_hist};
                        if(!low_found && scan_sum>=low_threshold) begin
                            low_cut<=index_d;low_found<=1;
                        end
                        if(!high_found && scan_sum>=high_threshold) begin
                            high_cut<=index_d;high_found<=1;
                        end
                        if(index_d==255) begin
                            index<=0;
                            if(!auto_contrast_enable || high_threshold==0 ||
                               {1'b0,scan_high}<={1'b0,scan_low}+9'd1) begin
                                low_cut<=0;high_cut<=255;
                            end else begin
                                low_cut<=scan_low;high_cut<=scan_high;
                            end
                            state<=ST_FILTER;
                        end
                    end
                end
                ST_FILTER:if(ENABLE_STATISTICS)begin
                    applied_low<=filtered_low;applied_high<=filtered_high;
                    if(filtered_low==0 && filtered_high==255)begin
                        gain_q8<=256;state<=ST_BUILD;
                    end else begin
                        divisor<=filtered_high-filtered_low;
                        dividend<=16'd65280;quotient<=0;remainder<=0;
                        divide_count<=0;state<=ST_DIVIDE;
                    end
                end
                ST_DIVIDE:if(ENABLE_STATISTICS)begin
                    dividend<={dividend[14:0],1'b0};
                    if(shifted_remainder>=divisor) begin
                        remainder<=shifted_remainder-divisor;
                        quotient<={quotient[14:0],1'b1};
                    end else begin
                        remainder<=shifted_remainder;
                        quotient<={quotient[14:0],1'b0};
                    end
                    if(divide_count==15) begin
                        gain_q8<=shifted_remainder>=divisor ?
                            {quotient[14:0],1'b1} : {quotient[14:0],1'b0};
                        state<=ST_BUILD;index<=0;
                    end else divide_count<=divide_count+1'b1;
                end
                ST_BUILD:begin mapped_q<=mapped_value;state<=ST_CONTRAST;end
                ST_CONTRAST:begin contrasted_q<=contrasted_value;state<=ST_GAMMA;end
                ST_GAMMA:begin gamma_q<=clamp10(gamma_blended);state<=ST_BUILD_WRITE;end
                ST_BUILD_WRITE:begin
                    if(index==255) begin
                        state<=ST_IDLE;lut_ready<=1;pending_lut<=1;index<=0;
                    end else begin index<=index+1'b1;state<=ST_BUILD;end
                end
                default:state<=ST_INIT;
            endcase
        end
    end
endmodule
