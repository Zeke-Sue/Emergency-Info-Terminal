`timescale 1ns/1ps
module tb_dual_scanout #(parameter integer TEST_AUX=0, TEST_PRELOADED=0);
    localparam W=640,H=8;
    reg clk=0,pclk=0,rst=1;
    always #10 clk=~clk;
    always #20 pclk=~pclk;
    reg [2:0] mode=0;
    reg [1:0] zoom_scale=0;
    wire frame,req,ack,bank,dual,hslide;
    wire [3:0] image,second;
    wire [9:0] row,split;
    wire [1:0] zoom;
    wire [10:0] ra,rb;
    wire [23:0] qa,qb,rgb;
    wire rd,valid,user,last,underflow,overflow;
    wire [20:0] address;
    reg [5:0] response_valid=0;
    reg [31:0] response_data[0:5];
    wire [3:0] error;
    wire aux_ready,aux_done;
    wire [31:0] aux_rdata;
    reg aux_pending=0,aux_write=1;
    reg [31:0] aux_data=32'h01234567,aux_memory[0:3];
    integer aux_completed=0;
    wire wr;
    wire [20:0] wa;
    wire [31:0] wd;
    always @(posedge clk)if(!rst&&TEST_AUX)begin
        if(!aux_pending&&aux_ready)aux_pending<=1;
        if(aux_done)begin
            if(!aux_write&&aux_rdata!==aux_data)fail("aux data response");
            aux_pending<=0;aux_write<=!aux_write;aux_completed<=aux_completed+1;
            if(!aux_write)aux_data<=aux_data+32'h01020304;
        end
        if(wr)begin
            if(wa<21'h1e0000||wa>21'h1e0003)fail("aux burst write address");
            aux_memory[wa[1:0]]<=wd;
        end
    end
    function [23:0] pixel;
        input integer im,py,px;
        reg [7:0] r,g,b;
        begin r=im ? 255-(px%256) : px%256;g=py+im*50;b=im ? 200 : 1;pixel={r,g,b};end
    endfunction
    function [31:0] word_at;
        input integer a;
        integer im,py,px,phase;
        reg [23:0] p0,p1,p2,p3;
        begin
            im=a/(W*H*3/4);py=(a%(W*H*3/4))/(W*3/4);
            px=((a%(W*3/4))/3)*4;phase=a%3;
            p0=pixel(im,py,px);p1=pixel(im,py,px+1);
            p2=pixel(im,py,px+2);p3=pixel(im,py,px+3);
            case(phase)0:word_at={p1[23:16],p0};1:word_at={p2[15:0],p1[15:0]};default:word_at={p3,p2[23:16]};endcase
        end
    endfunction
    integer n;
    always @(posedge clk)begin
        response_valid<={response_valid[4:0],rd};
        response_data[0]<=address>=21'h1e0000&&address<=21'h1e0003 ? aux_memory[address[1:0]] : word_at(address);
        for(n=1;n<6;n=n+1)response_data[n]<=response_data[n-1];
    end
    frame_store #(.WIDTH(W),.HEIGHT(H),.BURST(128),.DRAIN_CYCLES(32),
        .STREAMING(1),.DUAL_SOURCE(1),.ENABLE_AUX(TEST_AUX)) memory(
        .clk(clk),.rst(rst),.pixel_clk(pclk),.mem_init(1'b1),.mem_busy(1'b0),
        .load_done(1'b0),.pixel_valid(1'b0),.pixel_addr(22'd0),.pixel_rgb(24'd0),
        .reads_enabled(1'b1),.error_code(error),.line_req_toggle(req),
        .line_image(image),.line_row(row),.line_bank(bank),.line_second_image(second),
        .line_split(split),.line_horizontal_slide(hslide),.line_zoom(zoom),
        .line_ack_toggle(ack),.line_dual(dual),.line_ram_addr(ra),.line_ram_q(qa),
        .second_ram_addr(rb),.second_ram_q(qb),.rd_en(rd),.rd_addr(address),
        .rd_valid(response_valid[5]),.rd_data(response_data[5]),
        .wr_en(wr),.wr_addr(wa),.wr_data(wd),
        .aux_valid(TEST_AUX&&!aux_pending),.aux_write(aux_write),.aux_addr(21'h1e0000),
        .aux_wdata(aux_data),.aux_ready(aux_ready),.aux_done(aux_done),.aux_rdata(aux_rdata));
    video_scanout #(.WIDTH(W),.HEIGHT(H),.HTOTAL(800),.VTOTAL(12),.HSTART(160),
        .VSTART(4),.ENABLE_EFFECTS(0),.FIXED_RATE_AXIS(1),.DUAL_SOURCE(1),.PRELOADED_VIEW(TEST_PRELOADED)) video(
        .clk(pclk),.rst(rst),.cache_ready(1'b1),.image_index(4'd0),.fade_gain(5'd16),
        .zoom_mode(zoom_scale!=0),.zoom_scale(zoom_scale),.zoom_pan_x(TEST_PRELOADED ? 11'd160 : 11'd320),.zoom_pan_y(TEST_PRELOADED ? 11'd2 : 11'd4),
        .grayscale_enable(1'b0),.overlay_enable(1'b0),.transition_mode(mode),
        .transition_target(4'd1),.slide_progress(5'd8),.slide_active(1'b1),
        .transition_phase(7'd32),.brightness_level(3'd2),.contrast_level(3'd2),
        .saturation_level(3'd2),.gamma_mode(2'd1),.temperature_mode(2'd1),
        .quality_selection(3'd0),.osd_visible(1'b0),.quality_enable(1'b0),
        .quality_auto_enable(1'b0),.analysis_view(2'd0),.narration_subtitle(8'd0),
        .e5_peak_frequency_q8(24'd0),.e5_waterfall_value(8'd0),.audio_sample_valid(1'b0),
        .audio_sample(16'd0),.console_proxy_valid(1'b0),.console_proxy_status(96'd0),
        .alarm_active(1'b0),.alarm_level(3'd0),.alarm_drill(1'b0),
        .alarm_cancel_notice(1'b0),.alarm_flash_on(1'b0),.alarm_countdown_trusted(1'b0),
        .alarm_countdown_seconds(16'd0),.alarm_latency_valid(1'b0),
        .alarm_pixel_latency_us(24'd0),.alarm_audio_latency_us(24'd0),.alarm_blocked_set(8'd0),
        .route_cfg_write(1'b0),.route_cfg_key(8'd0),.route_cfg_segments(32'd0),
        .route_cfg_directions(32'd0),.route_cfg_exit(3'd0),.route_cfg_status(2'd0),
        .route_cfg_commit(1'b0),.route_cfg_crc_ok(1'b0),.route_cfg_checked(1'b0),
        .route_cfg_assets_match(1'b0),.route_cfg_version(16'd0),.route_cfg_crc32(32'd0),
        .frame_tick(frame),.line_req_toggle(req),.line_image(image),.line_row(row),
        .line_bank(bank),.line_second_image(second),.line_split(split),
        .line_horizontal_slide(hslide),.line_zoom(zoom),.line_ack_toggle(ack),
        .line_ram_addr(ra),.line_ram_q(qa),.second_ram_addr(rb),.second_ram_q(qb),
        .line_dual(dual),.axis_valid(valid),.axis_user(user),.axis_last(last),
        .axis_data(rgb),.axis_ready(1'b1),.underflow(underflow),.overflow(overflow));
    task fail;input [255:0] why;begin $display("TEST_FAIL scanout: %0s",why);$finish;end endtask
    integer f=0,x=0,y=0,count=0,selected,hash_value,rank,dx,dy,c,frame_mode,frame_zoom,px,py;
    reg checking=0;
    reg [23:0] a,b,expected;
    always @(posedge pclk)begin
        if(!rst&&frame)begin
            f=f+1;
            if(f>=3&&f<=9)mode<=f-3;
            if(f==10)begin mode<=2;zoom_scale<=1;end
            if(f==11)begin mode<=2;zoom_scale<=2;end
        end
        #1;
        if(valid&&(checking||(user&&f>=3)))begin
            if(user)begin x=0;y=0;frame_mode=mode;frame_zoom=zoom_scale;checking=1;end
            a=pixel(0,y,x);b=pixel(1,y,x);selected=0;
            hash_value=(x*73)^(y*151)^((x%256)*256+(y%256));
            rank=((x>>4)&3)*64+((y>>4)&3)*16+(((x>>6)^(y>>6))&3)*4+(((x>>8)^(y>>8))&3);
            dx=x-W/2;dy=y-H/2;
            case(frame_mode)
                0:begin
                    for(c=0;c<3;c=c+1)expected[c*8+:8]=(a[c*8+:8]+b[c*8+:8]+1)/2;
                end
                1:expected=x<320 ? b : a;
                2:begin
                    px=x<320 ? x+320 : x-320;
                    px=W/2-((W/2)>>(TEST_PRELOADED ? 0 : frame_zoom))+(px>>(TEST_PRELOADED ? 0 : frame_zoom));
                    py=H/2-((H/2)>>(TEST_PRELOADED ? 0 : frame_zoom))+(y>>(TEST_PRELOADED ? 0 : frame_zoom));
                    expected=pixel(x>=320,py,px);
                end
                3:expected=(hash_value&255)<=131 ? b : a;
                4:expected=rank<128 ? b : a;
                5:expected=(x%32)<16 ? b : a;
                6:expected=dx*dx+dy*dy<=162*162 ? b : a;
            endcase
            if(rgb!==expected)begin
                $display("mode=%0d x=%0d y=%0d actual=%h expected=%h",frame_mode,x,y,rgb,expected);fail("pixel mismatch");
            end
            count=count+1;
            if(last)begin
                if(x!=W-1)fail("last marker");
                if(y==H-1&&frame_zoom==2)begin
                    if(underflow||overflow||error!=0||count!=9*W*H)fail("deadline or pixel count");
                    if(TEST_AUX&&aux_completed<100)fail("aux starvation");
                    if(TEST_AUX)$display("PASS: %0d background SDRAM transactions concurrent with dual-source video",aux_completed);
                    $display("TEST_PASS tb_dual_scanout seven effects plus 2x/4x push, %0d pixels, 1600-cycle deadline",count);$finish;
                end
                x=0;y=y+1;
            end
            else x=x+1;
        end
    end
    initial begin repeat(4)@(negedge clk);rst=0;end
    initial begin #5000000;fail("timeout");end
endmodule

module tb_dual_scanout_audio;
    tb_dual_scanout #(.TEST_AUX(1)) test();
endmodule

module tb_preloaded_scanout_pixels;
    tb_dual_scanout #(.TEST_AUX(1),.TEST_PRELOADED(1)) test();
endmodule
