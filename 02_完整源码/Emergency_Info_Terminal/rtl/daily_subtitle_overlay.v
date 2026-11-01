// 根据实际播放进度读取字幕条，在视频图层中生成滚动字幕。
`timescale 1ns/1ps

module daily_subtitle_overlay #(
    parameter integer WIDTH=640, HEIGHT=480
)(
    input wire clk,rst,frame_tick,
    input wire active,
    input wire [2:0] track,
    input wire [31:0] elapsed_samples,
    input wire [10:0] x,y,
    input wire [7:0] subtitle_id,
    input wire [23:0] rgb_in,
    output wire [23:0] rgb_out
);
    localparam integer PANEL_Y=HEIGHT>48 ? HEIGHT-48 : 0;
    wire [7:0] time_bin=|elapsed_samples[31:19] ? 8'hff : elapsed_samples[18:11];
    wire [10:0] position_q;
    daily_subtitle_position_rom timing(.clk(clk),.address({track,time_bin}),.position(position_q));
    reg active_q,frame_active;
    reg [2:0] track_q,frame_track;
    reg [31:0] samples_q,frame_samples;
    reg [10:0] frame_offset;
    always @(posedge clk or posedge rst)begin
        if(rst)begin
            active_q<=0;track_q<=0;samples_q<=0;
            frame_active<=0;frame_track<=0;frame_samples<=0;frame_offset<=0;
        end else begin
            active_q<=active;track_q<=track;samples_q<=elapsed_samples;
            if(frame_tick)begin
                frame_active<=active_q;frame_track<=track_q;
                frame_samples<=samples_q;frame_offset<=position_q;
            end
        end
    end

    wire show=active&&frame_active&&track==frame_track&&elapsed_samples>=frame_samples;
    wire panel=show&&x>=16&&x<WIDTH-16&&y>=PANEL_Y&&y<PANEL_Y+32;

    wire [11:0] strip_x={1'b0,frame_offset}+{1'b0,x}-(WIDTH-16);
    wire [10:0] local_y=y-PANEL_Y;
    wire glyph_enable=panel&&strip_x<1024&&local_y>=8&&local_y<24;
    wire [3:0] row=local_y[3:0]-4'd8;
    wire glyph;
    daily_subtitle_strip_rom bitmap(.clk(clk),.track(frame_track),.row(row),
        .pixel_x(strip_x[9:0]),.pixel(glyph));

    wire [7:0] legacy_id=subtitle_id>=1&&subtitle_id<=8 ? 8'd0 : subtitle_id;
    wire [23:0] legacy_rgb;
    subtitle_overlay_renderer #(.WIDTH(WIDTH),.HEIGHT(HEIGHT)) legacy(
        .clk(clk),.x(x),.y(y),.subtitle_id(legacy_id),.rgb_in(rgb_in),.rgb_out(legacy_rgb));
    reg panel_q,glyph_enable_q;
    reg [23:0] rgb_q;
    always @(posedge clk)begin
        panel_q<=panel;glyph_enable_q<=glyph_enable;rgb_q<=rgb_in;
    end
    wire [23:0] dark={1'b0,rgb_q[23:17],1'b0,rgb_q[15:9],1'b0,rgb_q[7:1]};
    assign rgb_out=panel_q ? (glyph_enable_q&&glyph ? 24'hffffff : dark) : legacy_rgb;
endmodule
