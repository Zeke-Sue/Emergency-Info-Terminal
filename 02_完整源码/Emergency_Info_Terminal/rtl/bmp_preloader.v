// 解析24位BMP头部与像素数据，按目标尺寸完成缩放并提交整帧。
`timescale 1ns/1ps

module bmp_preloader #(
    parameter integer WIDTH = 640,
    parameter integer HEIGHT = 480,

    parameter [31:0] SCAN_FIRST = 32'd2048,
    parameter [31:0] SCAN_LIMIT = 32'd131072,
    parameter integer IO_TIMEOUT = 25000000,
    parameter integer INIT_TIMEOUT = 500000000,
    parameter integer ON_DEMAND = 0,
    parameter integer IMAGE_COUNT = 8,
    parameter integer ENABLE_AUDIO_STREAM = 0,
    parameter integer ENABLE_AUDIO_ABORT = 0,
    parameter integer ENABLE_ROUTE_CONFIG = 1,
    parameter integer STRICT_CHAIN = 0,
    parameter integer MAX_SOURCE_WIDTH = 1280,
    parameter integer MAX_SOURCE_HEIGHT = 960,
    parameter integer ENABLE_VIEWPORT = 0,
    parameter integer FIXED_PLAYLIST = 0,
    parameter integer FIXED_WAV_FILES = 12,
    parameter [7:0] DEFAULT_VIEW = 0
)(
    input wire clk, rst, start_ready, sd_ready,
    input wire load_request,
    input wire [3:0] load_image,
    input wire [1:0] load_slot,
    input wire [7:0] load_view,
    output wire sector_req,
    output wire [31:0] sector_lba,
    input wire [7:0] sector_data,
    input wire sector_valid, sector_end,
    output reg pixel_valid,
    input wire pixel_ready,
    output reg [21:0] pixel_addr,
    output reg [23:0] pixel_rgb,
    output reg done,
    output wire busy,
    output reg [4:0] image_count,
    output reg [3:0] error_code,
    input wire route_cfg_ready,
    output wire route_cfg_write,output wire [7:0] route_cfg_key,
    output wire [31:0] route_cfg_segments,
    output wire [31:0] route_cfg_directions,
    output wire [2:0] route_cfg_exit,output wire [1:0] route_cfg_status,
    output wire route_cfg_commit,output wire route_cfg_crc_ok,
    output wire route_cfg_checked,output wire route_cfg_assets_match,
    output wire [15:0] route_cfg_version,
    output wire [31:0] route_cfg_crc32,
    output wire route_config_valid,output wire [3:0] route_config_error,
    input wire audio_open_req,input wire [3:0] audio_file_index,
    input wire audio_abort,
    output wire audio_busy,output wire audio_open_done,
    output wire audio_not_found,output wire [31:0] audio_file_size,
    output wire [7:0] audio_file_data,output wire audio_file_valid,
    input wire audio_file_ready,output wire audio_file_end,
    output wire [4:0] audio_wav_count,
    output wire [3:0] audio_read_error,
    output wire audio_read_progress,
    output wire playlist_valid
);
    localparam integer FRAME_PIXELS = WIDTH*HEIGHT;
    localparam [20:0] LAST_ROW = (HEIGHT-1)*WIDTH;
    localparam [20:0] ROW_BACK = WIDTH*2-1;
    localparam integer SOURCE_X_BITS = $clog2(MAX_SOURCE_WIDTH+1);
    localparam integer SOURCE_Y_BITS = $clog2(MAX_SOURCE_HEIGHT+1);
    localparam integer DEST_X_BITS = $clog2(WIDTH);
    localparam integer DEST_Y_BITS = $clog2(HEIGHT);
    localparam integer FIT_WIDTH_BITS = $clog2(WIDTH+1);
    localparam integer FIT_HEIGHT_BITS = $clog2(HEIGHT+1);
    localparam integer STRIDE_BITS = $clog2(MAX_SOURCE_WIDTH*3+4);
    localparam integer BMP_BYTES_BITS = $clog2(((MAX_SOURCE_WIDTH*3+3)/4)*4*MAX_SOURCE_HEIGHT+1);
    localparam integer FIT_PRODUCT_LIMIT_A = MAX_SOURCE_WIDTH*HEIGHT+
        MAX_SOURCE_HEIGHT;
    localparam integer FIT_PRODUCT_LIMIT_B = MAX_SOURCE_HEIGHT*WIDTH+
        MAX_SOURCE_WIDTH;
    localparam integer FIT_PRODUCT_LIMIT =
        FIT_PRODUCT_LIMIT_A>FIT_PRODUCT_LIMIT_B ?
            FIT_PRODUCT_LIMIT_A : FIT_PRODUCT_LIMIT_B;
    localparam integer FIT_PRODUCT_BITS = $clog2(FIT_PRODUCT_LIMIT+1);
    localparam integer FIT_QUOTIENT_BITS =
        $clog2((WIDTH>HEIGHT ? WIDTH : HEIGHT)+1);
    localparam integer PHASE_LIMIT_X =
        MAX_SOURCE_WIDTH+WIDTH>WIDTH*3 ? MAX_SOURCE_WIDTH+WIDTH : WIDTH*3;
    localparam integer PHASE_LIMIT_Y =
        MAX_SOURCE_HEIGHT+HEIGHT>HEIGHT*3 ? MAX_SOURCE_HEIGHT+HEIGHT : HEIGHT*3;
    localparam integer PHASE_BITS =
        $clog2((PHASE_LIMIT_X>PHASE_LIMIT_Y ? PHASE_LIMIT_X : PHASE_LIMIT_Y)+1);
    localparam integer WEIGHT_BITS = PHASE_BITS+8;
    localparam [15:0] DEST_WIDTH_CONST = WIDTH;
    localparam [15:0] DEST_HEIGHT_CONST = HEIGHT;
    localparam [4:0] WAIT_MOUNT=0, OPEN_FILE=1, WAIT_FILE=2,
        CONSUME=3, HEADER_CALC=4, HEADER_CHECK=5, FIT_SETUP=6,
        FIT_DIVIDE=7, FIT_APPLY=8, SCALE=9, WEIGHT_H=10,
        WEIGHT_V=11, SCALE_LEFT=12, SCALE_RIGHT=13,
        BLEND=14, BLEND_CALC=15, EMIT=16, DRAIN=17,
        FINISHED=18, FAILED=19, CONFIG_OPEN=20, CONFIG_WAIT=21,
        CONFIG_STREAM=22, CONFIG_DONE=23, READ_WAIT=24, FIT_COMPARE=25,
        PHASE_ADVANCE=26, PHASE_APPLY=27, FIT_SELECT=28;

    reg [4:0] state;
    wire file_valid;
    reg [31:0] bmp_width;
    wire [31:0] header_height;
    assign busy=(state!=WAIT_MOUNT && state!=FINISHED && state!=FAILED) ||
        (state==FAILED && file_valid);
    reg open_req;
    reg audio_mode;
    reg audio_open_pending;
    reg [3:0] audio_index;
    reg config_start,config_end;
    reg config_attempted;
    reg [3:0] selected_image;
    reg [1:0] selected_slot;
    reg [7:0] selected_view;
    reg [SOURCE_X_BITS-1:0] crop_width,crop_x,physical_x;
    reg [SOURCE_Y_BITS-1:0] crop_height,crop_y,physical_row;
    wire [1:0] crop_shift=ENABLE_VIEWPORT ?
        (selected_view[7:6]>2 ? 2'd2 : selected_view[7:6]) : 2'd0;
    wire [2:0] pan_level_x=selected_view[5:3]>4 ? 3'd4 : selected_view[5:3];
    wire [2:0] pan_level_y=selected_view[2:0]>4 ? 3'd4 : selected_view[2:0];

    wire [SOURCE_X_BITS-1:0] shifted_w=bmp_width[SOURCE_X_BITS-1:0]>>crop_shift;
    wire [SOURCE_Y_BITS-1:0] shifted_h=header_height[SOURCE_Y_BITS-1:0]>>crop_shift;
    wire [SOURCE_X_BITS-1:0] cropped_w=shifted_w==0 ? 1 : shifted_w;
    wire [SOURCE_Y_BITS-1:0] cropped_h=shifted_h==0 ? 1 : shifted_h;
    function [15:0] pan_offset;
        input [15:0] span;
        input [2:0] level;
        reg [17:0] product;
        begin
            case(level)
                0:product=0;
                1:product={2'd0,span};
                2:product={1'd0,span,1'b0};
                3:product={2'd0,span}+{1'd0,span,1'b0};
                default:product={span,2'd0};
            endcase
            pan_offset=product[17:2];
        end
    endfunction
    wire [SOURCE_X_BITS-1:0] crop_span_x=bmp_width[SOURCE_X_BITS-1:0]-cropped_w;
    wire [SOURCE_Y_BITS-1:0] crop_span_y=header_height[SOURCE_Y_BITS-1:0]-cropped_h;
    wire [SOURCE_X_BITS-1:0] crop_offset_x=pan_offset(crop_span_x,pan_level_x);
    wire [SOURCE_Y_BITS-1:0] crop_offset_y=pan_offset(crop_span_y,pan_level_y);
    wire in_crop=physical_x>=crop_x && physical_x<crop_x+crop_width &&
        physical_row>=crop_y && physical_row<crop_y+crop_height;
    wire open_done;
    wire [31:0] directory_size;
    wire [7:0] file_data;
    wire file_ready;
    wire file_end;
    wire fat_mounted;
    wire [3:0] fat_error;
    wire file_not_found;
    wire [5:0] catalog_file_count;
    wire [4:0] catalog_bmp_count,catalog_wav_count;
    wire catalog_config_found;
    wire [7:0] catalog_malformed_count;
    wire catalog_overflow;

    reg bottom_up;

    reg [12:0] file_pos;

    reg fixed_header_bad,dib_large;
    reg [31:0] bmp_file_size, data_offset;
    reg [31:0] bmp_height;
    reg [SOURCE_X_BITS-1:0] source_width;
    reg [SOURCE_Y_BITS-1:0] source_height;
    reg [1:0] row_padding,padding_remaining;
    reg [STRIDE_BITS-1:0] calculated_stride;
    reg [SOURCE_Y_BITS-1:0] calculated_height;
    reg [BMP_BYTES_BITS-1:0] calculated_image_bytes;
    reg [SOURCE_X_BITS-1:0] source_x,scaled_source_x;
    reg [SOURCE_Y_BITS-1:0] source_row;
    reg [10:0] row_read_address;
    reg [1:0] rows_pending;
    reg [DEST_X_BITS-1:0] dest_x;
    reg [DEST_Y_BITS-1:0] dest_row;
    reg [1:0] component;
    reg [7:0] blue, green;
    reg [PHASE_BITS-1:0] horizontal_phase,vertical_phase;
    reg phase_vertical;
    reg [PHASE_BITS-1:0] phase_remainder,phase_denominator;
    reg [1:0] phase_steps;
    reg [FIT_WIDTH_BITS-1:0] fit_width,fit_x_offset;
    reg [FIT_HEIGHT_BITS-1:0] fit_height,fit_y_stream_offset;
    reg fit_divide_width;
    reg [FIT_PRODUCT_BITS-1:0] fit_dividend,fit_remainder,fit_divisor;
    reg [FIT_PRODUCT_BITS-1:0] fit_product_q;
    reg [FIT_QUOTIENT_BITS-1:0] fit_quotient;
    reg [$clog2(FIT_PRODUCT_BITS)-1:0] fit_bit;
    reg write_bank, lower_bank, upper_bank;
    reg [8:0] horizontal_weight, vertical_weight;
    reg [23:0] lower_left, upper_left, lower_right, upper_right;
    reg [WEIGHT_BITS-1:0] weight_remainder,weight_divisor;
    reg [8:0] weight_result;
    reg [3:0] weight_bit;
    reg [7:0] blend_left, blend_right;
    reg [8:0] blend_weight;
    reg [3:0] blend_phase;
    reg [23:0] lower_blended, upper_blended;

    assign header_height = bmp_height[31] ?
        (~bmp_height+1'b1) : bmp_height;
    wire [STRIDE_BITS-1:0] header_row_bytes =
        bmp_width[SOURCE_X_BITS-1:0]+(bmp_width[SOURCE_X_BITS-1:0]<<1);
    wire [STRIDE_BITS-1:0] header_stride = (header_row_bytes+3)&32'hffff_fffc;
    wire basic_header_ok = !fixed_header_bad && dib_large &&
        bmp_width!=0 && !bmp_width[31] && bmp_width<=MAX_SOURCE_WIDTH &&
        header_height!=0 && header_height<=MAX_SOURCE_HEIGHT && data_offset>=54 &&
        data_offset<=4096;
    wire [BMP_BYTES_BITS:0] required_file_bytes={1'b0,calculated_image_bytes}+data_offset[12:0];
    wire header_ok = basic_header_ok &&
        calculated_image_bytes!=0 &&
        bmp_file_size>=required_file_bytes &&
        bmp_file_size<=directory_size &&
        directory_size>=required_file_bytes;
    wire row_write = state==CONSUME && file_valid && file_ready &&
        file_pos>=data_offset && file_pos>=54 && padding_remaining==0 && component==2 && in_crop;
    wire [23:0] row0_q, row1_q;
    wire [23:0] lower_q=lower_bank ? row1_q : row0_q;
    wire [23:0] upper_q=upper_bank ? row1_q : row0_q;
    wire signed [8:0] blend_difference =
        $signed({1'b0,blend_right})-$signed({1'b0,blend_left});

    wire signed [17:0] multiply_left = state==HEADER_CALC ?
        $signed({1'b0,header_stride}) : state==FIT_SETUP ?
        $signed({2'b0,crop_width}) : state==FIT_COMPARE ?
        $signed({2'b0,crop_height}) : state==BLEND_CALC ?
        {{9{blend_difference[8]}},blend_difference} : 18'sd0;
    wire signed [17:0] multiply_right = state==HEADER_CALC ?
        $signed({1'b0,header_height[SOURCE_Y_BITS-1:0]}) : state==FIT_SETUP ?
        $signed({2'b0,DEST_HEIGHT_CONST}) : state==FIT_COMPARE ?
        $signed({2'b0,DEST_WIDTH_CONST}) : state==BLEND_CALC ?
        $signed({9'b0,blend_weight}) : 18'sd0;
    wire signed [35:0] multiply_product=multiply_left*multiply_right;
    wire [FIT_PRODUCT_BITS-1:0] fit_height_numerator = fit_product_q;

    wire fit_select_width = fit_dividend<=fit_height_numerator;
    wire [FIT_PRODUCT_BITS-1:0] fit_selected_numerator =
        fit_select_width ? fit_dividend : fit_height_numerator;
    wire [15:0] fit_selected_divisor =
        fit_select_width ? crop_height : crop_width;
    wire [FIT_PRODUCT_BITS-1:0] fit_shifted_remainder =
        {fit_remainder[FIT_PRODUCT_BITS-2:0],
         fit_dividend[FIT_PRODUCT_BITS-1]};
    wire fit_subtract = fit_shifted_remainder>=fit_divisor;
    wire [FIT_QUOTIENT_BITS-1:0] fit_quotient_next =
        {fit_quotient[FIT_QUOTIENT_BITS-2:0],fit_subtract};
    wire [FIT_WIDTH_BITS:0] fit_x_end =
        {1'b0,fit_x_offset}+{1'b0,fit_width};
    wire [FIT_HEIGHT_BITS:0] fit_y_end =
        {1'b0,fit_y_stream_offset}+{1'b0,fit_height};
    wire inside_fit_x = dest_x>=fit_x_offset && dest_x<fit_x_end;
    wire inside_fit_y = dest_row>=fit_y_stream_offset && dest_row<fit_y_end;
    wire [FIT_HEIGHT_BITS-1:0] last_fit_stream_row =
        fit_y_stream_offset+fit_height-1'b1;
    wire native_size=source_width==fit_width && source_height==fit_height;
    wire area_downscale=source_width>fit_width || source_height>fit_height;
    wire [PHASE_BITS-1:0] horizontal_next=
        horizontal_phase+source_width-1'b1;
    wire [PHASE_BITS-1:0] horizontal_denominator=fit_width-1'b1;

    wire exact_half_width=(source_width=={fit_width,1'b0}) &&
                          (source_height=={fit_height,1'b0});
    wire exact_half_height=exact_half_width;
    wire [PHASE_BITS-1:0] vertical_next=vertical_phase+source_height-1'b1;
    wire [PHASE_BITS-1:0] vertical_denominator=fit_height-1'b1;
    wire [WEIGHT_BITS-1:0] horizontal_weight_dividend=
        {horizontal_phase,8'b0};
    wire [WEIGHT_BITS-1:0] vertical_weight_dividend=
        {vertical_phase,8'b0};
    wire [WEIGHT_BITS-1:0] horizontal_weight_divisor=
        {(fit_width-1'b1),8'b0};
    wire [WEIGHT_BITS-1:0] vertical_weight_divisor=
        {(fit_height-1'b1),8'b0};

    wire config_byte_ready,config_done;
    wire image_file_ready=state==CONSUME || state==DRAIN ||
        (state==CONFIG_STREAM&&config_byte_ready);
    assign file_ready=audio_mode ? audio_file_ready : image_file_ready;
    assign audio_busy=audio_mode;
    assign audio_open_done=audio_mode&&open_done;
    assign audio_not_found=audio_mode&&file_not_found;
    assign audio_file_size=directory_size;
    assign audio_file_data=file_data;
    assign audio_file_valid=audio_mode&&file_valid;
    assign audio_file_end=audio_mode&&file_end;
    assign audio_wav_count=catalog_wav_count;
    assign audio_read_error=audio_mode ? fat_error : 4'd0;

    generate if(ENABLE_ROUTE_CONFIG)begin: local_route_config
    config_route_stream_parser config_parser(.clk(clk),.rst(rst),
        .file_start(config_start),.byte_valid(state==CONFIG_STREAM&&file_valid),
        .byte_data(file_data),.byte_ready(config_byte_ready),
        .cfg_ready(route_cfg_ready),.file_end(config_end),
        .cfg_write(route_cfg_write),.cfg_blocked_key(route_cfg_key),
        .cfg_segment_mask(route_cfg_segments),
        .cfg_direction_mask(route_cfg_directions),.cfg_exit(route_cfg_exit),
        .cfg_status(route_cfg_status),.cfg_commit(route_cfg_commit),
        .cfg_crc_ok(route_cfg_crc_ok),.cfg_checked(route_cfg_checked),
        .cfg_assets_match(route_cfg_assets_match),.cfg_version(route_cfg_version),
        .cfg_crc32(route_cfg_crc32),.done(config_done),
        .valid(route_config_valid),.error_reason(route_config_error));
    end else begin: no_local_route_config
        assign config_byte_ready=1'b1;
        assign config_done=1'b1;
        assign route_cfg_write=1'b0;
        assign route_cfg_key=8'd0;
        assign route_cfg_segments=32'd0;
        assign route_cfg_directions=32'd0;
        assign route_cfg_exit=3'd0;
        assign route_cfg_status=2'd0;
        assign route_cfg_commit=1'b0;
        assign route_cfg_crc_ok=1'b0;
        assign route_cfg_checked=1'b0;
        assign route_cfg_assets_match=1'b0;
        assign route_cfg_version=16'd0;
        assign route_cfg_crc32=32'd0;
        assign route_config_valid=1'b0;
        assign route_config_error=4'd0;
    end endgenerate

    assign audio_read_progress=audio_mode&&sector_valid;
    wire entry_valid,entry_wav,entry_long;
    wire [4:0] entry_ordinal;
    wire [31:0] entry_hash;
    wire [7:0] entry_length;
    generate if(FIXED_PLAYLIST)begin: playlist_names

        assign playlist_valid=fat_mounted&&catalog_bmp_count==16&&
            catalog_wav_count==FIXED_WAV_FILES&&catalog_malformed_count==0&&!catalog_overflow;
    end else begin: no_playlist_names
        assign playlist_valid=1'b1;
    end endgenerate
    fat32_file_reader #(.IO_TIMEOUT(IO_TIMEOUT),.INIT_TIMEOUT(INIT_TIMEOUT),.STRICT_CHAIN(STRICT_CHAIN),.FIXED_PLAYLIST(FIXED_PLAYLIST),.HASH_NAMES(!FIXED_PLAYLIST),
        .CACHE_BMP(1),.CACHE_WAV(ENABLE_AUDIO_STREAM),.CACHE_CONFIG(ENABLE_ROUTE_CONFIG),.FIXED_WAV_FILES(FIXED_WAV_FILES),
        .MAX_BMP_FILES(IMAGE_COUNT),.MAX_WAV_FILES(16)) files(
        .clk(clk),.rst(rst),.start_ready(start_ready),.sd_ready(sd_ready),
        .sector_req(sector_req),.sector_lba(sector_lba),
        .sector_data(sector_data),.sector_valid(sector_valid),.sector_end(sector_end),
        .open_req(open_req),
        .abort_file((state==FAILED && !audio_mode) ||
            (ENABLE_AUDIO_ABORT && audio_mode && audio_abort)),
        .open_type(audio_mode ? 2'd2 :
            ((state==CONFIG_OPEN||state==CONFIG_WAIT||
            state==CONFIG_STREAM||state==CONFIG_DONE) ? 2'd3 : 2'd1)),
        .file_index({2'd0,audio_mode ? audio_index :
            (ON_DEMAND ? selected_image : image_count[3:0])}),
        .open_done(open_done),.open_not_found(file_not_found),
        .file_size(directory_size),.file_data(file_data),.file_valid(file_valid),
        .file_ready(file_ready),.file_end(file_end),.mounted(fat_mounted),
        .catalog_file_count(catalog_file_count),.bmp_file_count(catalog_bmp_count),
        .wav_file_count(catalog_wav_count),.config_found(catalog_config_found),
        .catalog_malformed_count(catalog_malformed_count),
        .catalog_overflow(catalog_overflow),
        .error_code(fat_error),.media_entry_valid(entry_valid),.media_entry_wav(entry_wav),
        .media_entry_long(entry_long),.media_entry_ordinal(entry_ordinal),
        .media_entry_hash(entry_hash),.media_entry_length(entry_length));

    source_line_ram source_row_memory0(
        .clk(clk),.write_enable(row_write && !write_bank),.write_addr(source_x[10:0]),
        .write_data({file_data,green,blue}),
        .read_addr(row_read_address),.read_data(row0_q));
    source_line_ram source_row_memory1(
        .clk(clk),.write_enable(row_write && write_bank),.write_addr(source_x[10:0]),
        .write_data({file_data,green,blue}),
        .read_addr(row_read_address),.read_data(row1_q));

    wire signed [18:0] blend_product=multiply_product[18:0];
    wire signed [19:0] blend_base =
        $signed({1'b0,blend_left,8'b0});
    wire signed [19:0] blend_sum =
        blend_base+blend_product+20'sd128;
    wire [7:0] blend_value = blend_sum[15:8];

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= WAIT_MOUNT;
            open_req <= 0;
            audio_mode<=0;audio_open_pending<=0;audio_index<=0;
            config_start<=0;config_end<=0;config_attempted<=0;
            selected_image<=0;selected_slot<=0;
            row_read_address<=0;
            pixel_valid <= 0;
            pixel_addr <= 0;
            pixel_rgb <= 0;
            done <= 0;
            image_count <= 0;
            error_code <= 0;
            bottom_up <= 0;
            file_pos <= 0;
            fixed_header_bad <= 0;
            bmp_file_size <= 0;
            data_offset <= 0;
            dib_large <= 0;
            bmp_width <= 0;
            bmp_height <= 0;
            source_width <= 0;
            source_height <= 0;
            row_padding <= 0;
            padding_remaining <= 0;
            calculated_stride <= 0;
            calculated_height <= 0;
            calculated_image_bytes <= 0;
            source_x <= 0;
            source_row <= 0;
            scaled_source_x <= 0;
            rows_pending <= 0;
            selected_view<=ENABLE_VIEWPORT ? DEFAULT_VIEW : 8'd0;
            crop_width<=WIDTH;crop_height<=HEIGHT;crop_x<=0;crop_y<=0;
            physical_x<=0;physical_row<=0;
            dest_x <= 0;
            dest_row <= 0;
            component <= 0;
            blue <= 0;
            green <= 0;
            horizontal_phase <= 0;
            vertical_phase <= 0;
            fit_width <= WIDTH;
            fit_height <= HEIGHT;
            fit_x_offset <= 0;
            fit_y_stream_offset <= 0;
            fit_divide_width <= 0;
            fit_dividend <= 0;
            fit_product_q <= 0;
            fit_remainder <= 0;
            fit_divisor <= 0;
            fit_quotient <= 0;
            fit_bit <= 0;
            write_bank <= 0;
            lower_bank <= 0;
            upper_bank <= 0;
            horizontal_weight <= 0;
            vertical_weight <= 0;
            lower_left <= 0;
            upper_left <= 0;
            lower_right <= 0;
            upper_right <= 0;
            weight_remainder <= 0;
            weight_divisor <= 0;
            weight_result <= 0;
            weight_bit <= 0;
            blend_left <= 0;
            blend_right <= 0;
            blend_weight <= 0;
            blend_phase <= 0;
            lower_blended <= 0;
            upper_blended <= 0;
        end else begin
            config_start<=0;
            config_end<=0;
            case (state)
                WAIT_MOUNT: begin
                    if (fat_error!=0) begin error_code<=fat_error;state<=FAILED;end
                    else if (fat_mounted) begin
                        if(ENABLE_ROUTE_CONFIG&&!config_attempted&&catalog_config_found)
                            state<=CONFIG_OPEN;
                        else if(!ON_DEMAND)state<=OPEN_FILE;
                        else if(load_request)begin
                            selected_image<=load_image;selected_slot<=load_slot;
                            selected_view<=ENABLE_VIEWPORT ? load_view : 8'd0;
                            error_code<=0;done<=0;state<=OPEN_FILE;
                        end
                    end
                end

                CONFIG_OPEN: begin
                    open_req<=1;
                    state<=CONFIG_WAIT;
                end

                CONFIG_WAIT: begin
                    open_req<=0;
                    if(fat_error!=0)begin error_code<=fat_error;state<=FAILED;end
                    else if(file_not_found)begin
                        config_attempted<=1;
                        state<=WAIT_MOUNT;
                    end else if(open_done)begin
                        config_start<=1;
                        state<=CONFIG_STREAM;
                    end
                end

                CONFIG_STREAM: begin
                    if(fat_error!=0)begin error_code<=fat_error;state<=FAILED;end
                    else if(file_end)begin
                        config_end<=1;
                        state<=CONFIG_DONE;
                    end
                end

                CONFIG_DONE: begin
                    if(config_done)begin
                        config_attempted<=1;
                        state<=WAIT_MOUNT;
                    end
                end

                OPEN_FILE: begin
                    open_req <= 1;
                    state <= WAIT_FILE;
                end

                WAIT_FILE: begin
                    open_req <= 0;
                    if (!open_req && fat_error!=0) begin error_code<=fat_error;state<=FAILED;end
                    else if(file_not_found)begin error_code<=3;state<=FAILED;end
                    else if (open_done) begin
                        file_pos <= 0;
                        fixed_header_bad <= 0;
                        bmp_file_size <= 0;
                        data_offset <= 0;
                        dib_large <= 0;
                        bmp_width <= 0;
                        bmp_height <= 0;
                        state <= CONSUME;
                    end
                end

                CONSUME: begin
                    if (fat_error!=0) begin error_code<=fat_error;state<=FAILED;end
                    else if (!file_valid && file_end) begin error_code<=8;state<=FAILED;end
                    else if (file_valid) begin
                        if(!(&file_pos))file_pos <= file_pos+1'b1;
                        case (file_pos)
                            0: if(file_data!=8'h42)fixed_header_bad<=1;
                            1: if(file_data!=8'h4d)fixed_header_bad<=1;
                            2,3,4,5: bmp_file_size <= {file_data,bmp_file_size[31:8]};
                            10,11,12,13: data_offset <= {file_data,data_offset[31:8]};
                            14: dib_large <= file_data>=40;
                            15,16,17: dib_large <= dib_large||file_data!=0;
                            18,19,20,21: bmp_width <= {file_data,bmp_width[31:8]};
                            22,23,24,25: bmp_height <= {file_data,bmp_height[31:8]};
                            26: if(file_data!=1)fixed_header_bad<=1;
                            28: if(file_data!=24)fixed_header_bad<=1;
                            27,29,30,31,32,33: if(file_data!=0)fixed_header_bad<=1;
                        endcase

                        if (file_pos==53) state <= HEADER_CALC;
                        else if (file_pos>=54 && file_pos>=data_offset) begin
                            if (padding_remaining!=0)
                                padding_remaining <= padding_remaining-1'b1;
                            else case (component)
                                0: begin blue<=file_data;component<=1;end
                                1: begin green<=file_data;component<=2;end
                                2: begin
                                    component <= 0;

                                    if(physical_x==bmp_width[SOURCE_X_BITS-1:0]-1'b1)begin
                                        physical_x<=0;physical_row<=physical_row+1'b1;
                                        padding_remaining<=row_padding;
                                    end else physical_x<=physical_x+1'b1;
                                    if(in_crop)begin
                                    if (source_x==source_width-1) begin
                                        source_x <= 0;
                                        scaled_source_x <= 0;
                                        dest_x <= 0;
                                        horizontal_phase <= 0;
                                        if(rows_pending!=0) begin
                                            if(rows_pending>1) begin
                                                lower_bank<=write_bank;
                                                write_bank<=!write_bank;
                                                source_row<=source_row+1'b1;
                                                rows_pending<=rows_pending-1'b1;
                                                state<=CONSUME;
                                            end else begin
                                                upper_bank<=write_bank;
                                                rows_pending<=0;
                                                state<=SCALE;
                                            end
                                        end else if (native_size || source_height==1) begin
                                            lower_bank <= write_bank;
                                            upper_bank <= write_bank;
                                            state <= SCALE;
                                        end else if (source_row==0) begin
                                            lower_bank <= write_bank;
                                            write_bank <= !write_bank;
                                            source_row <= 1;
                                            state <= CONSUME;
                                        end else begin
                                            upper_bank <= write_bank;
                                            state <= SCALE;
                                        end
                                    end else source_x <= source_x+1'b1;
                                    end
                                end
                            endcase
                        end
                    end
                end

                HEADER_CALC: begin
                    calculated_stride <= header_stride[STRIDE_BITS-1:0];
                    calculated_height <= header_height[SOURCE_Y_BITS-1:0];
                    calculated_image_bytes <= multiply_product[31:0];
                    state <= HEADER_CHECK;
                end

                HEADER_CHECK: begin
                    if (!header_ok) begin error_code<=7;state<=FAILED;end
                    else begin
                        bottom_up <= !bmp_height[31];
                        crop_width<=cropped_w;crop_height<=cropped_h;
                        crop_x<=crop_offset_x;

                        crop_y<=bmp_height[31] ? crop_offset_y : crop_span_y-crop_offset_y;
                        state <= FIT_SETUP;
                    end
                end

                FIT_SETUP: begin
                    fit_dividend <=
                        multiply_product[FIT_PRODUCT_BITS-1:0];
                    state <= FIT_COMPARE;
                end

                FIT_COMPARE: begin

                    fit_product_q<=multiply_product[FIT_PRODUCT_BITS-1:0];
                    state<=FIT_SELECT;
                end
                FIT_SELECT: begin
                    fit_remainder <= 0;
                    fit_quotient <= 0;
                    fit_bit <= FIT_PRODUCT_BITS-1;
                    fit_dividend <= fit_selected_numerator+(fit_selected_divisor>>1);
                    fit_divisor <= fit_selected_divisor;
                    if (fit_select_width) begin
                        fit_divide_width <= 1;
                        fit_height <= HEIGHT;
                    end else begin
                        fit_divide_width <= 0;
                        fit_width <= WIDTH;
                    end
                    state <= FIT_DIVIDE;
                end

                FIT_DIVIDE: begin
                    fit_dividend <=
                        {fit_dividend[FIT_PRODUCT_BITS-2:0],1'b0};
                    fit_quotient <= fit_quotient_next;
                    if (fit_subtract)
                        fit_remainder <= fit_shifted_remainder-fit_divisor;
                    else fit_remainder <= fit_shifted_remainder;
                    if (fit_bit==0) state <= FIT_APPLY;
                    else fit_bit <= fit_bit-1'b1;
                end

                FIT_APPLY: begin
                    if (fit_divide_width) begin
                        fit_width <= fit_quotient==0 ? 1 : fit_quotient;
                        fit_x_offset <= (WIDTH-(fit_quotient==0 ? 1 : fit_quotient))>>1;
                        fit_y_stream_offset <= 0;
                    end else begin
                        fit_height <= fit_quotient==0 ? 1 : fit_quotient;
                        fit_x_offset <= 0;

                        if (bmp_height[31])
                            fit_y_stream_offset <=
                                (HEIGHT-(fit_quotient==0 ? 1 : fit_quotient))>>1;
                        else
                            fit_y_stream_offset <= HEIGHT-
                                (fit_quotient==0 ? 1 : fit_quotient)-
                                ((HEIGHT-(fit_quotient==0 ? 1 : fit_quotient))>>1);
                    end
                    source_width <= crop_width;
                    source_height <= crop_height;
                    row_padding <= calculated_stride-header_row_bytes;
                    padding_remaining <= 0;
                    component <= 0;
                    source_x <= 0;
                    source_row <= 0;
                    physical_x<=0;physical_row<=0;
                    scaled_source_x <= 0;
                    row_read_address <= 0;
                    dest_x <= 0;
                    dest_row <= 0;
                    horizontal_phase <= 0;
                    vertical_phase <= 0;
                    rows_pending <= 0;
                    write_bank <= 0;
                    lower_bank <= 0;
                    upper_bank <= 0;
                    horizontal_weight <= 0;
                    vertical_weight <= 0;
                    pixel_addr <= (ON_DEMAND ? {2'b0,selected_slot} : image_count)*FRAME_PIXELS+
                        (bmp_height[31] ? 21'd0 : LAST_ROW);
                    state <= CONSUME;
                end

                SCALE: begin
                    if (!inside_fit_x || !inside_fit_y) begin
                        pixel_rgb <= 0;
                        pixel_valid <= 1;
                        state <= EMIT;
                    end else if (native_size) begin
                        row_read_address<=scaled_source_x[10:0];
                        state<=READ_WAIT;
                    end
                    else if(exact_half_width) begin
                        horizontal_weight<=9'd128;
                        vertical_weight<=9'd128;
                        scaled_source_x<=source_x==source_width-1 ? source_x : source_x+1'b1;
                        row_read_address<=source_x[10:0];
                        state<=READ_WAIT;
                    end
                    else if (source_width==1 || fit_width==1) begin
                        horizontal_weight <= 0;
                        weight_remainder <= vertical_weight_dividend;
                        weight_divisor <= vertical_weight_divisor;
                        weight_result <= 0;
                        weight_bit <= 8;
                        state <= WEIGHT_V;
                    end else begin
                        weight_remainder <= horizontal_weight_dividend;
                        weight_divisor <= horizontal_weight_divisor;
                        weight_result <= 0;
                        weight_bit <= 8;
                        state <= WEIGHT_H;
                    end
                end

                WEIGHT_H: begin
                    if (weight_remainder>=weight_divisor) begin
                        weight_remainder <= weight_remainder-weight_divisor;
                        weight_result[weight_bit] <= 1'b1;
                    end
                    weight_divisor <= weight_divisor>>1;
                    if (weight_bit==0) begin
                        horizontal_weight <= {weight_result[8:1],
                            weight_remainder>=weight_divisor};
                        weight_remainder <= vertical_weight_dividend;
                        weight_divisor <= vertical_weight_divisor;
                        weight_result <= 0;
                        weight_bit <= 8;
                        state <= WEIGHT_V;
                    end else weight_bit <= weight_bit-1'b1;
                end

                WEIGHT_V: begin
                    if (source_height==1 || fit_height==1) begin
                        vertical_weight <= 0;
                        scaled_source_x <= source_x==source_width-1 ?
                            source_x : source_x+1'b1;
                        row_read_address <= source_x[10:0];
                        state <= READ_WAIT;
                    end else begin
                        if (weight_remainder>=weight_divisor) begin
                            weight_remainder <= weight_remainder-weight_divisor;
                            weight_result[weight_bit] <= 1'b1;
                        end
                        weight_divisor <= weight_divisor>>1;
                        if (weight_bit==0) begin
                            vertical_weight <= {weight_result[8:1],
                                weight_remainder>=weight_divisor};
                            scaled_source_x <= source_x==source_width-1 ?
                                source_x : source_x+1'b1;
                            row_read_address <= source_x[10:0];
                            state <= READ_WAIT;
                        end else weight_bit <= weight_bit-1'b1;
                    end
                end

                READ_WAIT: begin
                    row_read_address<=scaled_source_x[10:0];
                    state<=SCALE_LEFT;
                end

                SCALE_LEFT: begin
                    if (native_size) begin
                        pixel_rgb <= lower_q;
                        pixel_valid <= 1;
                        state <= EMIT;
                    end else begin
                        lower_left <= lower_q;
                        upper_left <= upper_q;
                        state <= SCALE_RIGHT;
                    end
                end

                SCALE_RIGHT: begin
                    lower_right <= lower_q;
                    upper_right <= upper_q;
                    state <= BLEND;
                end

                BLEND: begin
                    blend_left <= lower_left[23:16];
                    blend_right <= lower_right[23:16];
                    blend_weight <= horizontal_weight;
                    blend_phase <= 0;
                    state <= BLEND_CALC;
                end

                BLEND_CALC: begin
                    case (blend_phase)
                        0: begin
                            lower_blended[23:16] <= blend_value;
                            blend_left <= lower_left[15:8];
                            blend_right <= lower_right[15:8];
                            blend_phase <= 1;
                        end
                        1: begin
                            lower_blended[15:8] <= blend_value;
                            blend_left <= lower_left[7:0];
                            blend_right <= lower_right[7:0];
                            blend_phase <= 2;
                        end
                        2: begin
                            lower_blended[7:0] <= blend_value;
                            blend_left <= upper_left[23:16];
                            blend_right <= upper_right[23:16];
                            blend_phase <= 3;
                        end
                        3: begin
                            upper_blended[23:16] <= blend_value;
                            blend_left <= upper_left[15:8];
                            blend_right <= upper_right[15:8];
                            blend_phase <= 4;
                        end
                        4: begin
                            upper_blended[15:8] <= blend_value;
                            blend_left <= upper_left[7:0];
                            blend_right <= upper_right[7:0];
                            blend_phase <= 5;
                        end
                        5: begin
                            upper_blended[7:0] <= blend_value;
                            blend_left <= lower_blended[23:16];
                            blend_right <= upper_blended[23:16];
                            blend_weight <= vertical_weight;
                            blend_phase <= 6;
                        end
                        6: begin
                            pixel_rgb[23:16] <= blend_value;
                            blend_left <= lower_blended[15:8];
                            blend_right <= upper_blended[15:8];
                            blend_phase <= 7;
                        end
                        7: begin
                            pixel_rgb[15:8] <= blend_value;
                            blend_left <= lower_blended[7:0];
                            blend_right <= upper_blended[7:0];
                            blend_phase <= 8;
                        end
                        default: begin
                            pixel_rgb[7:0] <= blend_value;
                            pixel_valid <= 1;
                            state <= EMIT;
                        end
                    endcase
                end

                EMIT: if (pixel_ready) begin
                    pixel_valid <= 0;
                    if (dest_x==WIDTH-1) begin
                        dest_x <= 0;
                        source_x <= 0;
                        scaled_source_x <= 0;
                        horizontal_phase <= 0;
                        if (dest_row==HEIGHT-1) begin
                            state <= DRAIN;
                        end else begin
                            dest_row <= dest_row+1'b1;
                            pixel_addr <= bottom_up ?
                                pixel_addr-ROW_BACK : pixel_addr+1'b1;

                            if (!inside_fit_y || dest_row==last_fit_stream_row) begin
                                vertical_phase <= 0;
                                state <= SCALE;
                            end else if (native_size) begin
                                vertical_phase <= 0;
                                source_row <= source_row+1'b1;
                                write_bank <= !write_bank;
                                state <= CONSUME;
                            end else if (source_height==1) begin
                                vertical_phase <= 0;
                                state <= SCALE;
                            end else if (dest_row==last_fit_stream_row-1'b1 && !area_downscale) begin
                                vertical_phase <= fit_height-1;
                                state <= SCALE;
                            end else begin
                                phase_vertical<=1;
                                phase_remainder<=exact_half_height ? 0 : vertical_next;
                                phase_denominator<=vertical_denominator;
                                phase_steps<=exact_half_height ? 2 : 0;
                                state<=exact_half_height ? PHASE_APPLY : PHASE_ADVANCE;
                            end
                        end
                    end else begin
                        dest_x <= dest_x+1'b1;
                        pixel_addr <= pixel_addr+1'b1;
                        if (inside_fit_y && inside_fit_x &&
                                dest_x+1'b1<fit_x_end) begin
                            if (source_width==1) begin
                                horizontal_phase <= 0;
                                source_x <= 0;
                                scaled_source_x<=0;
                            end else begin
                                phase_vertical<=0;
                                phase_remainder<=exact_half_width ? 0 : horizontal_next;
                                phase_denominator<=horizontal_denominator;
                                phase_steps<=exact_half_width ? 2 : 0;
                            end
                        end
                        if(inside_fit_y&&inside_fit_x&&dest_x+1'b1<fit_x_end&&source_width!=1)
                            state<=exact_half_width ? PHASE_APPLY : PHASE_ADVANCE;
                        else state<=SCALE;
                    end
                end

                PHASE_ADVANCE:begin
                    if(phase_steps!=3&&phase_remainder>=phase_denominator)begin
                        phase_remainder<=phase_remainder-phase_denominator;
                        phase_steps<=phase_steps+1'b1;
                    end else begin

                        if(phase_vertical && area_downscale &&
                                dest_row==last_fit_stream_row)begin
                            phase_steps<=phase_steps-1'b1;
                            phase_remainder<=vertical_denominator;
                        end
                        state<=PHASE_APPLY;
                    end
                end
                PHASE_APPLY:begin
                    if(phase_vertical)begin
                        vertical_phase<=phase_remainder;
                        if(phase_steps!=0)begin
                            rows_pending<=phase_steps;
                            if(phase_steps==1)lower_bank<=upper_bank;
                            write_bank<=lower_bank;
                            source_row<=source_row+1'b1;
                            state<=CONSUME;
                        end else state<=SCALE;
                    end else begin
                        horizontal_phase<=phase_remainder;
                        source_x<=source_x+phase_steps;
                        scaled_source_x<=source_x+phase_steps;
                        state<=SCALE;
                    end
                end

                DRAIN: begin
                    if (fat_error!=0) begin error_code<=fat_error;state<=FAILED;end
                    else if (file_end) begin
                        if (ON_DEMAND) begin
                            image_count<=IMAGE_COUNT;done<=1;state<=FINISHED;
                        end else if (image_count==IMAGE_COUNT-1) begin
                            image_count <= IMAGE_COUNT;
                            done <= 1;
                            state <= FINISHED;
                        end else begin
                            image_count <= image_count+1'b1;
                            state <= OPEN_FILE;
                        end
                    end
                end

                FINISHED: begin
                    open_req<=0;pixel_valid<=0;
                    if(audio_mode)begin

                        if(open_done)audio_open_pending<=0;
                        if((file_end&&!audio_open_pending)||file_not_found||
                                (fat_error!=0 && !open_req))
                            audio_mode<=0;
                    end else if(ON_DEMAND && load_request)begin
                        selected_image<=load_image;selected_slot<=load_slot;
                        selected_view<=ENABLE_VIEWPORT ? load_view : 8'd0;
                        error_code<=0;done<=0;state<=OPEN_FILE;
                    end else if(ENABLE_AUDIO_STREAM&&audio_open_req)begin
                        audio_mode<=1;audio_open_pending<=1;
                        audio_index<=audio_file_index;open_req<=1;
                    end
                end
                FAILED: begin
                    open_req<=0;pixel_valid<=0;audio_mode<=0;
                    if(ON_DEMAND && load_request && !file_valid)begin
                        selected_image<=load_image;selected_slot<=load_slot;
                        selected_view<=ENABLE_VIEWPORT ? load_view : 8'd0;
                        error_code<=0;done<=0;state<=OPEN_FILE;
                    end
                end
                default: begin error_code<=15;state<=FAILED;end
            endcase
        end
    end
endmodule
