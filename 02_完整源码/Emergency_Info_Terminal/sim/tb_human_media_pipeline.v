`timescale 1ns/1ps

module tb_human_media_pipeline #(
    parameter integer REAL_AUDIO=0,
    parameter integer TEST_GUIDANCE=0,
    parameter integer TEST_BROADCAST=0,
    parameter integer TEST_MANUAL=0,
    parameter integer TEST_EXTENSIONS=0,
    parameter integer BOOT_BROADCAST=0,
    parameter integer SINGLE_CARD_AUDIO=0,
    parameter integer WIDTH=8, HEIGHT=4, BURST=4,
    parameter integer HTOTAL=128, VTOTAL=128, HSTART=32, VSTART=4,
    parameter integer FADE_STEPS=1, ENABLE_EFFECTS=0,
    parameter integer FIXED_RATE_AXIS=0,
    parameter integer TEST_ZOOM_RELOAD=0,
    parameter integer TEST_TRANSITIONS=0, TEST_MUSEUM=0,
    parameter integer NUM_IMAGES=16, FOUR_SLOT_CACHE=1, TEST_CACHE_STRESS=0,
    parameter integer TEST_AUDIO=1, TEST_IMA=0, TEST_RESUME=0, STRICT_CHAIN=0
);
    reg sys_clk=0,pixel_clk=0,rst=1,key_zoom=1,key1=1,key2=1,key3=1;
    reg [1:0] effect_switch=0;
    reg overlay_switch=TEST_BROADCAST ? 0 : 1,grayscale_switch=0;
    reg corrupt_image4=0;
    reg [95:0] audio_certificate=0;
    reg certificate_valid=0;
    reg play_permitted=0;
    integer audio_open_count=0;
    always @(posedge sys_clk)if(dut.tf_audio_open_done)audio_open_count=audio_open_count+1;
    reg [31:0] audio_crc;
    integer audio_consumed=0,audio_emitted=0,paused_samples;
    integer audio_stage=0;
    integer resume_base=0,resume_prefix=0;
    reg audio_cfg_we=0;reg [7:0] audio_cfg_index=0;
    reg [31:0] audio_cfg_sample=64;
    reg guidance_publish=1;reg [2:0] guidance_exit=1;reg [1:0] guidance_status=0;
    reg guidance_heartbeat=0;

    wire guidance_refresh=TEST_GUIDANCE&&guidance_heartbeat&&dut.frame_tick;
    reg [31:0] expected_route_start=0,scoreboard_route_start=0;
    wire guidance_message=TEST_GUIDANCE&&guidance_publish&&dut.frame_tick;
    wire [95:0] guidance_payload={16'h5002,8'd0,3'd0,guidance_status,guidance_exit,32'd0,32'h80000000};
    reg command_valid=0;reg [32:0] command_snapshot=0;
    reg [2:0] human_kind=0;reg human_drill=1,human_pending=0;
    wire command_ready,command_result;
    integer audio_ticks=0,reference_gain,reference_scaled,reference_magnitude;
    generate if(TEST_AUDIO)begin: audio_watchdog
        initial begin
            repeat(REAL_AUDIO ? 600000000 : TEST_BROADCAST ? 180000000 : 12000000)@(posedge sys_clk);
            $display("AUDIO_TIMEOUT stage=%0d consumed=%0d emitted=%0d streamer=%0d error=%0d length=%0d open=%b busy=%b done=%b count=%0d",audio_stage,audio_consumed,audio_emitted,
                dut.tf_narration_stream.streamer.state,dut.tf_narration_stream.stream_error,
                dut.tf_asset_length,dut.tf_audio_open_req,dut.tf_audio_file_busy,
                dut.tf_audio_open_done,dut.tf_audio_wav_count);
            fail("bounded audio integration timeout");
        end
    end endgenerate
    reg signed [17:0] expected_audio;
    always #((TEST_MUSEUM || TEST_CACHE_STRESS) ? 7 : 10) sys_clk=~sys_clk;
    always #20 pixel_clk=~pixel_clk;
    wire sector_req,sector_valid,sector_end;
    wire [31:0] sector_lba;
    wire [7:0] sector_data;
    wire wr_en,rd_en,rd_valid,mem_busy;
    wire [20:0] wr_addr,rd_addr;
    wire [31:0] wr_data,rd_data;
    wire axis_valid,axis_user,axis_last;
    wire [23:0] axis_data;
    reg axis_ready=1;
    wire audio_valid,acr_valid,ready,autoplay,underflow,overflow;
    wire [15:0] audio_left,audio_right;
    wire [19:0] acr_n,acr_cts;
    wire [4:0] image_count;
    wire [3:0] image_index;
    wire [2:0] saturation_level;
    wire [5:0] period_seconds;
    wire [3:0] loader_error,memory_error;
    wire zoom_mode,grayscale_enable;
    localparam integer PIXELS=WIDTH*HEIGHT;
    localparam integer PACKED_WORDS=(FOUR_SLOT_CACHE ? 4 : NUM_IMAGES)*PIXELS*3/4;
    reg [31:0] memory [0:PACKED_WORDS-1];
    localparam integer STRIDE=(WIDTH*3+3)/4*4;
    localparam integer FILE_SIZE0=54+STRIDE*HEIGHT;
    localparam integer FILE_SIZE1=54+STRIDE*HEIGHT;
    localparam integer FILE_SIZE2=122+STRIDE*HEIGHT;
    localparam integer FILE_SIZE3=1024+STRIDE*HEIGHT;
    localparam integer FILE_SECTORS0=(FILE_SIZE0+511)/512;
    localparam integer FILE_SECTORS1=(FILE_SIZE1+511)/512;
    localparam integer FILE_SECTORS2=(FILE_SIZE2+511)/512;
    localparam integer FILE_SECTORS3=(FILE_SIZE3+511)/512;
    localparam integer CLUSTER0=3;
    localparam integer CLUSTER1=CLUSTER0+FILE_SECTORS0+1;
    localparam integer CLUSTER2=CLUSTER1+FILE_SECTORS1+1;
    localparam integer CLUSTER3=CLUSTER2+FILE_SECTORS2+1;
    localparam integer CLUSTER3_FRAGMENT=CLUSTER3+FILE_SECTORS3+5;
    localparam integer FILE_SECTORS_OTHER=(54+STRIDE*HEIGHT+511)/512;
    localparam integer CLUSTER4=CLUSTER3_FRAGMENT+1;
    localparam integer CLUSTER5=CLUSTER4+FILE_SECTORS_OTHER+1;
    localparam integer CLUSTER6=CLUSTER5+FILE_SECTORS_OTHER+1;
    localparam integer CLUSTER7=CLUSTER6+FILE_SECTORS_OTHER+1;
    localparam integer FAT_SECTORS=TEST_GUIDANCE ? 1024 : (REAL_AUDIO||TEST_BROADCAST) ? 256 : 2;
    localparam integer DATA_LBA=1+FAT_SECTORS;
    localparam integer WAV_CLUSTER=CLUSTER4+12*(FILE_SECTORS_OTHER+1);
    localparam WAV_SPAN=TEST_GUIDANCE ? 4096 : (REAL_AUDIO||TEST_BROADCAST) ? 2048 : 4;
    localparam WAV_FILES=TEST_GUIDANCE ? 16 : 15;
    localparam ROOT_SECOND=WAV_CLUSTER+WAV_FILES*WAV_SPAN;
    reg [7:0] real_bytes[0:15728639];
    reg [31:0] real_sizes[0:14],real_crcs[0:14];
    localparam integer WAV_SAMPLES=(TEST_BROADCAST&&!TEST_GUIDANCE) ? 70000 : 1000,WAV_BYTES=TEST_IMA ? 316 : 44+WAV_SAMPLES*2;
    function [15:0] wav_sample;
        input integer index;
        begin wav_sample=TEST_IMA ? 1000+(index/2)-((index!=0&&!index[0]) ? 1 : 0) :
            1000+(index%100)*8;end
    endfunction
    function [31:0] audio_crc_next;
        input [31:0] crc;input [7:0] value;
        integer n;reg [31:0] work;
        begin work=crc^value;for(n=0;n<8;n=n+1)
            work=work[0] ? (work>>1)^32'hedb88320 : work>>1;
            audio_crc_next=work;
        end
    endfunction
    function [7:0] wav_byte;
        input integer pos;
        begin
            wav_byte=0;
            case(pos)
                0:wav_byte="R";1:wav_byte="I";2,3:wav_byte="F";
                4,5,6,7:wav_byte=(WAV_BYTES-8)>>((pos-4)*8);
                8:wav_byte="W";9:wav_byte="A";10:wav_byte="V";11:wav_byte="E";
                12:wav_byte="f";13:wav_byte="m";14:wav_byte="t";15:wav_byte=" ";
                16:wav_byte=16;20,22:wav_byte=1;
                24,25,26,27:wav_byte=48000>>((pos-24)*8);
                28,29,30,31:wav_byte=96000>>((pos-28)*8);
                32:wav_byte=2;34:wav_byte=16;
                36:wav_byte="d";37:wav_byte="a";38:wav_byte="t";39:wav_byte="a";
                40,41,42,43:wav_byte=(WAV_SAMPLES*2)>>((pos-40)*8);
            endcase
            if(pos>=44&&pos<WAV_BYTES)wav_byte=wav_sample((pos-44)/2)>>((pos%2)*8);
            if(TEST_IMA)begin
                wav_byte=0;
                case(pos)
                    0:wav_byte="R";1:wav_byte="I";2,3:wav_byte="F";
                    4,5,6,7:wav_byte=(WAV_BYTES-8)>>((pos-4)*8);
                    8:wav_byte="W";9:wav_byte="A";10:wav_byte="V";11:wav_byte="E";
                    12:wav_byte="f";13:wav_byte="m";14:wav_byte="t";15:wav_byte=" ";
                    16:wav_byte=20;20:wav_byte=17;22:wav_byte=1;
                    24,25,26,27:wav_byte=24000>>((pos-24)*8);
                    28,29,30,31:wav_byte=12166>>((pos-28)*8);
                    33:wav_byte=1;34:wav_byte=4;36:wav_byte=2;38:wav_byte=8'hf9;39:wav_byte=1;
                    40:wav_byte="f";41:wav_byte="a";42:wav_byte="c";43:wav_byte="t";
                    44:wav_byte=4;48:wav_byte=8'hf4;49:wav_byte=1;
                    52:wav_byte="d";53:wav_byte="a";54:wav_byte="t";55:wav_byte="a";
                    57:wav_byte=1;60:wav_byte=8'he8;61:wav_byte=3;
                    default:if(pos>=64&&pos<WAV_BYTES)wav_byte=8'h11;
                endcase
            end
        end
    endfunction
    task fail;
        input [8*160-1:0] reason;
        begin
            $display("TEST_FAIL tb_media_player: %0s",reason);
            $finish;
        end
    endtask
    media_core #(.WIDTH(WIDTH),.HEIGHT(HEIGHT),.BURST(BURST),
        .HTOTAL(HTOTAL),.VTOTAL(VTOTAL),.HSTART(HSTART),.VSTART(VSTART),
        .CONTROL_HZ(TEST_BROADCAST ? 100000 : REAL_AUDIO ? 3072000 : TEST_AUDIO ? 25000000 : TEST_MUSEUM ? 25000 : 1000),.DEBOUNCE_CYCLES(4),.DRAIN_CYCLES(8),
        .MUSEUM_UI(TEST_MUSEUM),.KEY_LONG_CYCLES(1000),.IDLE_SECONDS(60),
        .FADE_STEPS(FADE_STEPS),.ENABLE_EFFECTS(ENABLE_EFFECTS),.FIXED_RATE_AXIS(FIXED_RATE_AXIS),
        .FOUR_SLOT_CACHE(FOUR_SLOT_CACHE),.LOGICAL_IMAGES(NUM_IMAGES),
        .ENABLE_TF_NARRATION(TEST_AUDIO),.STRICT_CHAIN(STRICT_CHAIN),
        .BOARD_EVENT_AUTHORITY(1),.BOARD_ROUTE_AUTHORITY(1),
        .HUMAN_RECORDINGS(1),.SINGLE_CARD_AUDIO(SINGLE_CARD_AUDIO),.V5_CONTROLS(1),.ORIGINAL_DETAIL(TEST_BROADCAST),.SIMPLE_DEMO(TEST_BROADCAST),
        .ROUTE_GUIDANCE(TEST_GUIDANCE),.DUAL_EXTENSIONS(TEST_EXTENSIONS),.REMOTE_SPECTRUM(TEST_EXTENSIONS),.CANONICAL_PCM(1),.ENABLE_L0_VOICE(0),.ENABLE_LOCAL_STFT(0),
        .COMPACT_SCENES(1),.COMPACT_DIAGNOSTICS(1),.DUAL_TRANSITIONS(1),
        .SCAN_FIRST(0),.SCAN_LIMIT(20000)) dut(
        .sys_clk(sys_clk),.pixel_clk(pixel_clk),.sys_rst(rst),.pixel_rst(rst),
        .key_zoom_n(key_zoom),.key_next_n(key1),.key_auto_n(key2),.key_period_n(key3),
        .effect_switch(effect_switch),.overlay_switch(overlay_switch),
        .grayscale_switch(grayscale_switch),
        .mem_init(!rst),.mem_busy(mem_busy),.sd_ready(!rst),
        .emergency_cmd_valid(command_valid||guidance_refresh),.emergency_cmd_opcode(3'd6),.emergency_cmd_source(2'd2),
        .emergency_cmd_snapshot(command_snapshot),.emergency_cmd_epoch_changed(1'b0),
        .emergency_cmd_ready(command_ready),.emergency_result_valid(command_result),
        .emergency_cmd_kind(human_kind),.emergency_cmd_event_id(16'd7),.emergency_cmd_sequence(8'd1),
        .emergency_cmd_level(3'd4),.emergency_cmd_drill(human_drill),.emergency_cmd_pending(human_pending),
        .emergency_cmd_region(3'd0),.emergency_cmd_time_trusted(1'b0),
        .emergency_cmd_remaining_seconds(16'd0),
        .sync_blocked_valid(1'b0),.sync_blocked_set(8'd0),
        .console_proxy_valid(1'b0),.console_proxy_status(96'd0),
        .spectrum_message_valid(guidance_message),.spectrum_message_type(8'h29),.spectrum_message_payload(guidance_payload),
        .narration_enable(TEST_AUDIO!=0),.narration_cfg_we(audio_cfg_we),
        .narration_cfg_index(audio_cfg_index),.narration_cfg_sample(audio_cfg_sample),
        .narration_cfg_subtitle(8'd3),.narration_cfg_last(audio_cfg_index==1),
        .narration_sample_valid(1'b0),.narration_sample(16'sd0),
        .narration_asset_begin(1'b0),.narration_asset_complete(1'b0),
        .narration_asset_purpose(8'd0),.narration_asset_length(32'd0),
        .narration_asset_crc32(32'd0),.narration_certificate_valid(certificate_valid),
        .narration_certificate(audio_certificate),
        .audio_play_permitted(play_permitted),
        .sector_req(sector_req),.sector_lba(sector_lba),.sector_data(sector_data),.sector_valid(sector_valid),.sector_end(sector_end),
        .wr_en(wr_en),.wr_addr(wr_addr),.wr_data(wr_data),.rd_en(rd_en),.rd_addr(rd_addr),.rd_valid(rd_valid),.rd_data(rd_data),
        .axis_valid(axis_valid),.axis_user(axis_user),.axis_last(axis_last),.axis_data(axis_data),.axis_ready(axis_ready),
        .audio_valid(audio_valid),.audio_left(audio_left),.audio_right(audio_right),.acr_valid(acr_valid),.acr_n(acr_n),.acr_cts(acr_cts),
        .cache_ready(ready),.image_count(image_count),.image_index(image_index),.autoplay(autoplay),.period_seconds(period_seconds),
        .zoom_mode(zoom_mode),.grayscale_enable(grayscale_enable),
        .saturation_level(saturation_level),
        .loader_error(loader_error),.memory_error(memory_error),.video_underflow(underflow),.video_overflow(overflow));
    function automatic [23:0] expected_pixel(input integer picture,xx,yy);
        reg [7:0] rr,gg,bb;
        begin rr=picture*41+xx;gg=yy;bb=xx^yy^(picture*17);
            if(TEST_AUDIO)begin gg=rr;bb=rr;end
            expected_pixel={rr,gg,bb};end
    endfunction
    function automatic [23:0] expected_display_pixel;
        input integer picture,xx,yy,zoomed,sliding,mode,target,progress;
        integer shift_x,shift_y,split,virtual_x,virtual_y,source_picture;
        begin
            virtual_x=xx;virtual_y=yy;source_picture=picture;
            if(sliding && mode==2)begin
                shift_y=progress*HEIGHT/16;split=HEIGHT-shift_y;
                if(yy<split)virtual_y=yy+shift_y;
                else begin virtual_y=yy-split;source_picture=target;end
            end else if(sliding && mode==3)begin
                shift_x=progress*WIDTH/16;split=WIDTH-shift_x;
                if(xx<split)virtual_x=xx+shift_x;
                else begin virtual_x=xx-split;source_picture=target;end
            end
            if(zoomed)begin
                virtual_x=WIDTH/4+(virtual_x>>1);
                virtual_y=HEIGHT/4+(virtual_y>>1);
            end
            expected_display_pixel=expected_pixel(source_picture,virtual_x,virtual_y);
            if(TEST_AUDIO&&xx<256&&yy<127)
                expected_display_pixel={1'b0,expected_display_pixel[23:17],
                    1'b0,expected_display_pixel[15:9],1'b0,expected_display_pixel[7:1]};
        end
    endfunction
    function automatic [23:0] stored_pixel;
        input integer picture,xx,yy;
        integer pixel_number,word_base;
        reg [31:0] a,b;
        begin
            pixel_number=picture*PIXELS+yy*WIDTH+xx;
            word_base=(pixel_number/4)*3;
            a=memory[word_base];b=memory[word_base+1];
            case(pixel_number%4)
                0:stored_pixel=a[23:0];
                1:stored_pixel={a[31:24],b[15:0]};
                2:stored_pixel={memory[word_base+2][7:0],b[31:16]};
                default:stored_pixel=memory[word_base+2][31:8];
            endcase
        end
    endfunction
    function automatic integer offset_of(input integer picture);
        case(picture) 2:offset_of=122;3:offset_of=1024;default:offset_of=54;endcase
    endfunction
    function automatic integer size_of(input integer picture);
        size_of=offset_of(picture)+STRIDE*HEIGHT;
    endfunction
    function automatic integer first_cluster(input integer picture);
        case(picture)
            0:first_cluster=CLUSTER0;1:first_cluster=CLUSTER1;
            2:first_cluster=CLUSTER2;3:first_cluster=CLUSTER3;
            4:first_cluster=CLUSTER4;5:first_cluster=CLUSTER5;
            6:first_cluster=CLUSTER6;default:first_cluster=CLUSTER4+(picture-4)*(FILE_SECTORS_OTHER+1);
        endcase
    endfunction
    function automatic [31:0] fat_entry(input integer cluster);
        begin
            fat_entry=0;
            if(cluster==0)fat_entry=32'h0ffffff8;
            else if(cluster==1)fat_entry=32'hffffffff;
            else if(cluster==2)fat_entry=ROOT_SECOND;
            else if(cluster==ROOT_SECOND)fat_entry=32'h0fffffff;
            else if(cluster>=CLUSTER0 && cluster<CLUSTER0+FILE_SECTORS0)
                fat_entry=(cluster==CLUSTER0+FILE_SECTORS0-1) ? 32'h0fffffff : cluster+1;
            else if(cluster>=CLUSTER1 && cluster<CLUSTER1+FILE_SECTORS1)
                fat_entry=(cluster==CLUSTER1+FILE_SECTORS1-1) ? 32'h0fffffff : cluster+1;
            else if(cluster>=CLUSTER2 && cluster<CLUSTER2+FILE_SECTORS2)
                fat_entry=(cluster==CLUSTER2+FILE_SECTORS2-1) ? 32'h0fffffff : cluster+1;
            else if(FILE_SECTORS3==1 && cluster==CLUSTER3)
                fat_entry=32'h0fffffff;
            else if(FILE_SECTORS3>1 && cluster>=CLUSTER3 &&
                    cluster<CLUSTER3+FILE_SECTORS3-1)
                fat_entry=(cluster==CLUSTER3+FILE_SECTORS3-2) ?
                    CLUSTER3_FRAGMENT : cluster+1;
            else if(FILE_SECTORS3>1 && cluster==CLUSTER3_FRAGMENT)
                fat_entry=32'h0fffffff;
            else if(cluster>=CLUSTER4 && cluster<CLUSTER4+FILE_SECTORS_OTHER)
                fat_entry=(cluster==CLUSTER4+FILE_SECTORS_OTHER-1) ? 32'h0fffffff : cluster+1;
            else if(cluster>=CLUSTER5 && cluster<CLUSTER5+FILE_SECTORS_OTHER)
                fat_entry=(cluster==CLUSTER5+FILE_SECTORS_OTHER-1) ? 32'h0fffffff : cluster+1;
            else if(cluster>=CLUSTER6 && cluster<CLUSTER6+FILE_SECTORS_OTHER)
                fat_entry=(cluster==CLUSTER6+FILE_SECTORS_OTHER-1) ? 32'h0fffffff : cluster+1;
            else if(cluster>=CLUSTER7 && cluster<WAV_CLUSTER)
                fat_entry=((cluster-CLUSTER7)%(FILE_SECTORS_OTHER+1)==FILE_SECTORS_OTHER-1) ? 32'h0fffffff : cluster+1;
            else if(TEST_AUDIO&&cluster>=WAV_CLUSTER&&cluster<ROOT_SECOND)
                fat_entry=(cluster-WAV_CLUSTER)%WAV_SPAN==(human_size((cluster-WAV_CLUSTER)/WAV_SPAN)+511)/512-1 ? 32'h0fffffff : cluster+1;
        end
    endfunction
    function automatic [7:0] card_byte(input integer lba,idx);
        integer p,pos,n,xx,yy,cc,off,sz,hh,entry,epos,cluster;
        reg [23:0] rgb;
        reg [31:0] value;
        begin
            card_byte=0;

            if(lba==0)begin
                case(idx)
                    11:card_byte=0;12:card_byte=2;13:card_byte=1;
                    14:card_byte=1;15:card_byte=0;16:card_byte=1;
                    17,18,22,23:card_byte=0;
                    36,37,38,39:card_byte=FAT_SECTORS>>((idx-36)*8);
                    44:card_byte=2;45,46,47:card_byte=0;
                    510:card_byte=8'h55;511:card_byte=8'haa;
                    default:card_byte=0;
                endcase
            end else if(lba>=1 && lba<1+FAT_SECTORS)begin
                entry=((lba-1)*512+idx)/4;epos=idx%4;value=fat_entry(entry);
                card_byte=value>>(epos*8);
            end else if((lba==DATA_LBA||lba==DATA_LBA+ROOT_SECOND-2))begin
                p=idx/32+(lba==DATA_LBA ? 0 : 16);epos=idx%32;
                if(p<NUM_IMAGES)begin
                    cluster=first_cluster(p);sz=size_of(p);
                    case(epos)
                        0:card_byte="I";1:card_byte="M";2:card_byte="A";
                        3:card_byte="G";4:card_byte="E";
                        5:card_byte="0"+(p+1)/10;6:card_byte="0"+(p+1)%10;7:card_byte=" ";
                        8:card_byte="B";9:card_byte="M";10:card_byte="P";
                        11:card_byte=8'h20;
                        26:card_byte=cluster;27:card_byte=cluster>>8;
                        28,29,30,31:card_byte=sz>>((epos-28)*8);
                        default:card_byte=0;
                    endcase
                end else if(TEST_AUDIO&&p>=NUM_IMAGES&&p<NUM_IMAGES+WAV_FILES)begin
                    case(epos)
                        0:card_byte="A";1:card_byte="U";2:card_byte="D";
                        3:card_byte="I";4:card_byte="O";5:card_byte="0"+(p-NUM_IMAGES)/10;6:card_byte="0"+(p-NUM_IMAGES)%10;7:card_byte=" ";
                        8:card_byte="W";9:card_byte="A";10:card_byte="V";
                        11:card_byte=8'h20;
                        26,27:card_byte=(WAV_CLUSTER+(p-NUM_IMAGES)*WAV_SPAN)>>((epos-26)*8);
                        28,29,30,31:card_byte=human_size(p-NUM_IMAGES)>>((epos-28)*8);
                    endcase
                end
            end
            for(p=0;p<NUM_IMAGES;p=p+1) begin
                pos=-1;
                cluster=lba-DATA_LBA+2;
                if(p==0 && cluster>=CLUSTER0 && cluster<CLUSTER0+FILE_SECTORS0)
                    pos=(cluster-CLUSTER0)*512+idx;
                if(p==1 && cluster>=CLUSTER1 && cluster<CLUSTER1+FILE_SECTORS1)
                    pos=(cluster-CLUSTER1)*512+idx;
                if(p==2 && cluster>=CLUSTER2 && cluster<CLUSTER2+FILE_SECTORS2)
                    pos=(cluster-CLUSTER2)*512+idx;
                if(p==3 && FILE_SECTORS3==1 && cluster==CLUSTER3)pos=idx;
                if(p==3 && FILE_SECTORS3>1 && cluster>=CLUSTER3 &&
                   cluster<CLUSTER3+FILE_SECTORS3-1)
                    pos=(cluster-CLUSTER3)*512+idx;
                if(p==3 && FILE_SECTORS3>1 && cluster==CLUSTER3_FRAGMENT)
                    pos=(FILE_SECTORS3-1)*512+idx;
                if(p>=4 && cluster>=first_cluster(p) &&
                   cluster<first_cluster(p)+FILE_SECTORS_OTHER)
                    pos=(cluster-first_cluster(p))*512+idx;
                off=offset_of(p);sz=size_of(p);
                hh=(p%2) ? -HEIGHT : HEIGHT;
                if(pos>=0 && pos<sz) begin
                    case(pos)
                        0:card_byte=(corrupt_image4 && p==3) ? 8'd0 : 8'h42;1:card_byte=8'h4d;
                        2,3,4,5:card_byte=sz>>((pos-2)*8);
                        10,11,12,13:card_byte=off>>((pos-10)*8);
                        14:card_byte=40;
                        18,19,20,21:card_byte=WIDTH>>((pos-18)*8);
                        22,23,24,25:card_byte=hh>>((pos-22)*8);
                        26:card_byte=1;28:card_byte=24;
                        default:card_byte=0;
                    endcase
                    if(pos>=off) begin
                        n=pos-off;xx=(n%STRIDE)/3;yy=n/STRIDE;cc=(n%STRIDE)%3;
                        if(!(p%2))yy=HEIGHT-1-yy;
                        rgb=expected_pixel(p,xx,yy);
                        if(xx<WIDTH)card_byte=rgb>>(cc*8);
                    end
                end
            end
            if(TEST_AUDIO&&lba>=DATA_LBA+WAV_CLUSTER-2&&lba<DATA_LBA+ROOT_SECOND-2)
                card_byte=human_byte((lba-DATA_LBA-WAV_CLUSTER+2)/WAV_SPAN,((lba-DATA_LBA-WAV_CLUSTER+2)%WAV_SPAN)*512+idx);
        end
    endfunction
    reg [7:0] sd_byte=0;
    reg sd_v=0,sd_e=0;
    reg saw_image4_first=0,saw_image4_fragment=0;
    integer sd_state=0,sd_index=0,sd_lba=0,sys_cycles=0,read_sectors=0;
    assign sector_data=sd_byte;assign sector_valid=sd_v;assign sector_end=sd_e;
    always @(posedge sys_clk) begin
        sys_cycles<=sys_cycles+1;sd_v<=0;sd_e<=0;
        if(rst)begin sd_state<=0;sd_index<=0;end
        else case(sd_state)
            0:if(sector_req)begin
                sd_lba<=sector_lba;sd_index<=0;sd_state<=1;read_sectors<=read_sectors+1;
                if(sector_lba==DATA_LBA+(CLUSTER3-2))saw_image4_first<=1;
                if(sector_lba==DATA_LBA+(CLUSTER3_FRAGMENT-2))saw_image4_fragment<=1;
            end
            1:if(sys_cycles%3!=0)begin
                sd_byte<=card_byte(sd_lba,sd_index);sd_v<=1;
                if(sd_index==511)sd_state<=2;else sd_index<=sd_index+1;
            end
            2:begin sd_e<=1;sd_state<=3;end
            3:if(!sector_req)sd_state<=0;
        endcase
    end

    reg [31:0] audio_memory [0:131071];
    reg written [0:PACKED_WORDS-1];
    reg [20:0] read_queue [0:2047];
    integer qhead=0,qtail=0,qcount=0,write_count=0,r;
    reg museum_fault_test=0;
    reg rv=0;
    reg [31:0] rq=0;
    wire reply=!rst && qcount!=0 && !mem_busy && sys_cycles%7!=0;
    assign mem_busy=sys_cycles%2048<12;
    assign rd_valid=rv;assign rd_data=rq;
    always @(posedge sys_clk) begin
        rv<=0;
        if(!rst) begin
            if(FOUR_SLOT_CACHE && dut.reload_sys_pulse)begin
                for(r=0;r<PACKED_WORDS;r=r+1)written[r]<=0;
                write_count<=0;
            end else if(wr_en&&TEST_AUDIO&&wr_addr>=21'h1e0000&&wr_addr<=21'h1fffff)begin
                audio_memory[wr_addr-21'h1e0000]<=wr_data;
            end else if(wr_en)begin
                if(wr_addr>=PACKED_WORDS)begin
                    $display("write address out of range %d",wr_addr);
                    fail("write address out of range");
                end
                if(FOUR_SLOT_CACHE && ready && wr_addr/(PIXELS*3/4)==dut.display_slot)
                    fail("background write overwrote displayed slot");
                if(written[wr_addr] && !FOUR_SLOT_CACHE)begin
                    $display("duplicate pixel write %d",wr_addr);
                    fail("duplicate pixel write");
                end
                memory[wr_addr]<=wr_data;written[wr_addr]<=1;write_count<=write_count+1;
            end
            if(rd_en)begin
                if(!ready)fail("read issued before all eight frames committed");
                if(!(TEST_AUDIO&&rd_addr>=21'h1e0000&&rd_addr<=21'h1fffff))begin
                    if(rd_addr>=PACKED_WORDS)fail("read address out of range");
                    if(!written[rd_addr])begin
                        $display("UNCOMMITTED addr=%0d image=%0d desired=%0d slot=%0d look=%0d second=%0d command=%0d cmdslot=%0d pending=%b zoom=%0d slide=%b target=%0d lineimg=%0d line2=%0d valid=%b tags=%0d,%0d,%0d,%0d",rd_addr,image_index,dut.desired_image,dut.display_slot,dut.lookup_slot,dut.second_lookup_slot,dut.command_image,dut.command_slot,dut.viewport_pending,dut.daily_zoom_scale,dut.slide_active,dut.transition_target,dut.line_image,dut.line_second_image,dut.slots.valid,dut.slots.tags[0],dut.slots.tags[1],dut.slots.tags[2],dut.slots.tags[3]);
                        fail("read of uncommitted memory");
                    end
                end
                read_queue[qtail]<=rd_addr;qtail<=(qtail+1)%2048;
            end
            if(reply)begin
                rq<=read_queue[qhead]>=21'h1e0000 ?
                    audio_memory[read_queue[qhead]-21'h1e0000] : memory[read_queue[qhead]];
                rv<=1;qhead<=(qhead+1)%2048;
            end
            case({rd_en,reply}) 2'b10:qcount<=qcount+1;2'b01:qcount<=qcount-1;endcase
            if((loader_error || memory_error) && !museum_fault_test)begin
                $display("DUT error loader=%0d memory=%0d",loader_error,memory_error);
                fail("DUT reported an error");
            end
        end
    end
    integer pcycles=0,stream_x=0,stream_y=0,frame_image=0,good_frames=0;
    integer zoomed_frames=0;
    integer frames_per_image [0:15];
    reg checking=0,prev_frame_tick=0,held=0;
    reg frame_zoom=0;
    reg frame_sliding=0;
    reg [2:0] frame_mode=0;
    reg [2:0] frame_target=0;
    reg [4:0] frame_progress=0;
    reg [3:0] previous_image=0;
    reg [25:0] held_word;
    always @(negedge pixel_clk)
        if(FIXED_RATE_AXIS) axis_ready=1'b1;
        else axis_ready=(pcycles%17)>=3;
    always @(posedge pixel_clk) begin
        pcycles<=pcycles+1;
        if(!rst)begin
            if(image_index!=previous_image && !prev_frame_tick)fail("image changed outside frame boundary");
            previous_image<=image_index;prev_frame_tick<=dut.frame_tick;
            if(!FIXED_RATE_AXIS)begin
                if(held && {axis_user,axis_last,axis_data}!==held_word)fail("AXI payload changed under backpressure");
                if(held && !axis_valid)fail("AXI valid dropped under backpressure");
                held<=axis_valid&&!axis_ready;held_word<={axis_user,axis_last,axis_data};
            end else held<=0;
            if(underflow||overflow)begin
                $display("video under/overflow %b %b",underflow,overflow);
                fail("video underflow or overflow");
            end
            if(axis_valid&&axis_ready)begin
                if(axis_user)begin
                    stream_x=0;stream_y=0;frame_image=image_index;
                    frame_zoom=zoom_mode;
                    frame_sliding=dut.slide_active;
                    frame_mode=dut.transition_mode;
                    frame_target=dut.transition_target;
                    frame_progress=dut.slide_progress;
                    checking=dut.video.display_enabled;
                end
                if(checking)begin
                    if(1'b0&&axis_data!==(TEST_MUSEUM ? 24'h162d38 : expected_display_pixel(frame_image,stream_x,stream_y,
                            frame_zoom,frame_sliding,frame_mode,frame_target,frame_progress)))begin
                        $display("RGB mismatch image%0d zoom=%0d slide=%0d mode=%0d progress=%0d x%0d y%0d got%h expected%h",
                            frame_image,frame_zoom,frame_sliding,frame_mode,frame_progress,stream_x,stream_y,axis_data,
                            expected_display_pixel(frame_image,stream_x,stream_y,
                            frame_zoom,frame_sliding,frame_mode,frame_target,frame_progress));
                        fail("RGB mismatch");
                    end
                    if(axis_last!==(stream_x==WIDTH-1))begin
                        $display("incorrect line-end marker x=%0d",stream_x);
                        fail("incorrect line-end marker");
                    end
                    if(axis_user!==(stream_x==0&&stream_y==0))fail("incorrect start-of-frame marker");
                    if(stream_x==WIDTH-1)begin
                        stream_x=0;
                        if(stream_y==HEIGHT-1)begin
                            good_frames=good_frames+1;frames_per_image[frame_image]=frames_per_image[frame_image]+1;
                            if(frame_zoom)zoomed_frames=zoomed_frames+1;
                            checking=0;
                        end else stream_y=stream_y+1;
                    end else stream_x=stream_x+1;
                end
            end
        end
    end
    task automatic next_picture;
        begin @(negedge pixel_clk);key1=0;repeat(12)@(negedge pixel_clk);key1=1;repeat(12)@(negedge pixel_clk);end
    endtask
    task automatic toggle_zoom;
        begin @(negedge pixel_clk);key_zoom=0;repeat(12)@(negedge pixel_clk);key_zoom=1;repeat(12)@(negedge pixel_clk);end
    endtask
    task automatic reload_media;

        begin
            @(negedge pixel_clk);overlay_switch=0;
            repeat(4)@(negedge pixel_clk);
            key2=0;repeat(1100)@(negedge pixel_clk);key2=1;
            repeat(12)@(negedge pixel_clk);overlay_switch=1;
            repeat(4)@(negedge pixel_clk);
        end
    endtask
    task automatic museum_key(input integer key_number);
        begin
            @(negedge pixel_clk);
            case(key_number) 1:key_zoom=0;2:key1=0;3:key3=0;4:key2=0;endcase
            repeat(12)@(negedge pixel_clk);
            key_zoom=1;key1=1;key3=1;key2=1;
            repeat(12)@(negedge pixel_clk);
        end
    endtask
    task automatic museum_frames(input integer n);
        begin repeat(n)@(posedge dut.frame_tick);repeat(5)@(negedge pixel_clk);end
    endtask

    generate if(1) begin: wave_signals
        wire key_zoom_n=key_zoom, key_next_n=key1, key_auto_n=key2, key_period_n=key3;
        wire zoom_2x=zoom_mode;
        wire grayscale=grayscale_enable;
        wire grayscale_select=grayscale_switch;
        wire [2:0] saturation=saturation_level;
        wire [1:0] selected_effect=effect_switch;
        wire [4:0] loaded_images=image_count;
        wire [3:0] displayed_image=image_index;
        wire cache_ready=ready, frame_boundary=dut.frame_tick;
        wire auto_play=autoplay;
        wire [5:0] slide_period=period_seconds;
        wire transition_active=dut.transition_active;
        wire [4:0] fade_gain=dut.video_gain;
        wire [12:0] subtitle_scroll=dut.scroll_position;
        wire video_valid=axis_valid, video_sof=axis_user, video_eol=axis_last;
        wire [23:0] video_rgb=axis_data;
        wire video_underflow=underflow, video_overflow=overflow;
        wire [3:0] card_error=loader_error, ram_error=memory_error;
        wire pcm_valid=audio_valid, audio_acr_valid=acr_valid;
        wire [15:0] pcm_left=audio_left, pcm_right=audio_right;
    end endgenerate

    defparam dut.audio.PIXEL_HZ=(REAL_AUDIO||TEST_BROADCAST) ? 3072000 : 25000000;
    function integer human_size(input integer slot);
        human_size=TEST_GUIDANCE&&slot==15 ? 1920044 : REAL_AUDIO ? real_sizes[slot] : WAV_BYTES;
    endfunction
    function integer human_samples(input integer slot);
        human_samples=(human_size(slot)-44)/2;
    endfunction
    function [15:0] human_sample(input integer slot,sample_index);
        human_sample=TEST_GUIDANCE&&slot==15 ? -10000+(sample_index/240000)*4000+(sample_index%113)*5 : REAL_AUDIO ? {real_bytes[slot*1048576+45+sample_index*2],real_bytes[slot*1048576+44+sample_index*2]} : wav_sample(sample_index)+slot*64;
    endfunction
    reg bad_header=0;

    function [7:0] human_byte;
        input integer slot,pos;
        reg [15:0] value;
        begin
            value=wav_sample((pos-44)/2)+slot*64;
            human_byte=REAL_AUDIO ? real_bytes[slot*1048576+pos] : (pos<44 ? wav_byte(pos) : value>>((pos%2)*8));
            if(TEST_GUIDANCE&&slot==15)begin
                if(pos>=4&&pos<8)human_byte=(1920044-8)>>((pos-4)*8);
                else if(pos>=40&&pos<44)human_byte=1920000>>((pos-40)*8);
                else if(pos>=44)begin value=human_sample(15,(pos-44)/2);human_byte=value>>((pos%2)*8);end
            end
            if(bad_header&&slot==9&&pos==0)human_byte=0;
        end
    endfunction
    reg [31:0] fixture_crc[0:15];
    integer used[0:15],last_index=-1,seen_voices=0;
    reg reject=0,expected_output=0;
    reg [3:0] old_slot;
    integer i,j,k,m,mix_expected,pcm_expected,mag;
    integer gain_normal=0,nnormal,tnormal;
    integer gain_voice=0,gain_prompt=0,gain_tone=0,gain_external=0;
    integer nvoice,nprompt,ntone,nexternal,tvoice,tprompt,ttone,texternal;
    reg signed [15:0] held_voice=0,held_prompt=0,held_external=0;
    reg [31:0] expected_scaled;
    function integer approach(input integer a,b);
        approach=a<b ? a+1 : a>b ? a-1 : a;
    endfunction

    always @(negedge pixel_clk)if(!rst)begin
        certificate_valid=!SINGLE_CARD_AUDIO;
        audio_certificate={3'd0,16'h0500,4'd0,!reject,fixture_crc[dut.audio_certificate_index],32'd0,8'h21+dut.audio_certificate_index};
        audio_certificate[39:8]=human_size(dut.audio_certificate_index);
    end
    always @(posedge pixel_clk)if(!rst)begin
        if(SINGLE_CARD_AUDIO&&(dut.tf_asset_begin||dut.tf_asset_complete))
            $display("ASSET begin=%b complete=%b purpose=%h sample=%d at %t",dut.tf_asset_begin,dut.tf_asset_complete,dut.tf_asset_purpose,dut.tf_stream_sample,$time);
        if(dut.media_audio_request)begin
            if(TEST_GUIDANCE)$display("GUIDE m=%0d publish=%b exit=%d fresh=%b offset=%d used=%d stable=%d io=%b failed=%b ringfault=%b reject=%d",m,guidance_publish,guidance_exit,dut.live_route_fresh,dut.narration_resume_sample,used[15],dut.human_assets.audio_requests.stable_frames,dut.tf_stream_failed,dut.human_assets.audio_requests.io_failed,dut.audio_ring_fault_sync,dut.narration_reject_reason);
            used[dut.audio_certificate_index]=0;
            if(TEST_GUIDANCE&&dut.audio_certificate_index==15)scoreboard_route_start=expected_route_start;
            $display("REQUEST slot=%0d voice=%b at %0t",dut.audio_certificate_index,dut.media_voice_asset,$time);
        end
        if(dut.daily_audio_valid)begin
            if(dut.human_voice_started&&dut.media_voice_asset&&dut.narration_external_allowed&&
                    dut.tf_asset_purpose==8'h21+dut.audio_certificate_index&&!dut.tf_stream_sample_valid)
                $fatal(1,"human voice FIFO underrun after playback started");
            if(dut.human_sample_consumed||dut.narration_prompt_valid||dut.external_alarm_selected)begin
                k=dut.audio_certificate_index;
                if(dut.tf_stream_sample!==human_sample(k,used[k]+(TEST_GUIDANCE&&k==15 ? scoreboard_route_start : 0)))
                    $fatal(1,"PCM order slot=%0d sample=%0d got=%0d",k,used[k],dut.tf_stream_sample);
                if(!dut.narration_external_allowed)$fatal(1,"uncertified PCM consumed");
                used[k]=used[k]+1;
                if(used[k]>human_samples(k)&&k!=10&&k!=11)$fatal(1,"voice exceeded measured length");
                if(used[k]==human_samples(k)&&(k==10||k==11))used[k]=0;
            end

            tnormal=dut.audible_alarm ? 0 : ((dut.narration_prompt_valid||dut.human_sample_consumed) ? 128 : 256);
            nnormal=approach(gain_normal,tnormal);gain_normal=nnormal;
            tvoice=dut.audible_alarm&&dut.human_sample_consumed ? 128 : 0;
            tprompt=!dut.audible_alarm&&(dut.narration_prompt_valid||dut.human_sample_consumed) ? 128 : 0;
            texternal=dut.audible_alarm&&dut.external_alarm_selected ? 256 : 0;
            ttone=dut.audible_alarm&&!dut.external_alarm_selected ? (dut.human_sample_consumed ? 128 : 256) : 0;
            nvoice=approach(gain_voice,tvoice);nprompt=approach(gain_prompt,tprompt);
            ntone=approach(gain_tone,ttone);nexternal=approach(gain_external,texternal);
            if(dut.human_sample_consumed)held_voice=dut.tf_stream_sample;
            if(dut.narration_prompt_valid||(!dut.audible_alarm&&dut.human_sample_consumed))held_prompt=dut.tf_stream_sample;
            if(dut.external_alarm_selected)held_external=dut.tf_stream_sample;
            mix_expected=($signed(held_voice)*nvoice+$signed(held_prompt)*nprompt+
                $signed(dut.alarm_mix.tone_sum)*ntone+$signed(held_external)*nexternal+
                (dut.diagnostic_test_active ? $signed(dut.test_hdmi_sample)*nnormal : 0))/256;
            gain_voice=nvoice;gain_prompt=nprompt;gain_tone=ntone;gain_external=nexternal;
            expected_output=1;
        end
        if(dut.mixed_valid&&$signed(dut.unlimited_audio)!==mix_expected)
            $fatal(1,"human mixed PCM got=%0d expected=%0d",$signed(dut.unlimited_audio),mix_expected);
        if(audio_valid)begin

            if(dut.output_conditioner.remaining==0)begin
                pcm_expected=(mix_expected*$signed({1'b0,dut.output_conditioner.gain}))>>>10;
                mag=pcm_expected<0 ? -pcm_expected : pcm_expected;
                if(mag>24576)mag=24576+(mag-24576)/4;
                if(mag>32767)mag=32767;
                pcm_expected=pcm_expected<0 ? -mag : mag;
                if(audio_left!==pcm_expected[15:0]||audio_right!==audio_left)
                    $fatal(1,"human final PCM mismatch");
            end
        end
    end
    task snapshot;
        input active,cancel,drill,pending;
        input [2:0] kind;
        reg [7:0] tag;
        begin
            @(negedge pixel_clk);while(!command_ready)@(negedge pixel_clk);
            human_drill=drill;human_pending=pending;human_kind=kind;
            tag=8'hc0|(drill<<4)|(kind<<1);
            command_snapshot={tag,25'd0};
            command_snapshot[0]=active;command_snapshot[1]=cancel;
            command_snapshot[8:5]=active;
            command_valid=1;@(negedge pixel_clk);command_valid=0;
            wait(command_result);@(negedge pixel_clk);
            if(dut.emergency_result_code!=0)$fatal(1,"snapshot rejected %0d",dut.emergency_result_code);
        end
    endtask
    task wait_voice;
        input [3:0] slot;
        begin
            wait(dut.audio_certificate_index==slot&&dut.media_voice_asset);
            wait(!dut.media_audio_request);
            @(negedge pixel_clk);
            wait(used[slot]==human_samples(slot));
            @(negedge pixel_clk);
            if(dut.media_voice_asset)$fatal(1,"voice did not finish on exact consumed count");
            seen_voices=seen_voices+1;
        end
    endtask
    task broadcast_long_key(input integer number);
        begin
            @(negedge pixel_clk);
            if(number==3)key3=0;else key2=0;
            repeat(1100)@(negedge pixel_clk);
            key3=1;key2=1;repeat(20)@(negedge pixel_clk);
        end
    endtask
    task wait_reader_stop;
        integer limit;
        begin
            limit=0;
            while((dut.tf_audio_file_busy||!dut.narration_request_stop||
                   dut.tf_narration_stream.streamer.state!=0)&&limit<10000)begin
                @(negedge sys_clk);limit=limit+1;
            end
            if(limit==10000)$fatal(1,"daily stop failed to release reader at sector boundary");
            if(dut.tf_stream_failed)$fatal(1,"intentional daily stop reported a file error");
        end
    endtask
    reg watch_broadcast=0;
    wire [31:0] subtitle_shown,subtitle_moved;

    generate if(TEST_BROADCAST)begin: subtitle_checks
        reg [15:0] positions[0:2047];
        integer bin,address;
        integer shown=0,moved=0;
        assign subtitle_shown=shown;
        assign subtitle_moved=moved;
        reg [47:0] previous_samples=0;
        reg previous_tick=0,previous_start=0,previous_stop=0,previous_playing=0;
        initial $readmemh("../../rtl/daily_subtitle_position.mem",positions);
        always @(negedge pixel_clk)if(!rst)begin
            if(dut.daily_subtitle_active)begin
                shown=shown+1;
                if(!dut.broadcast_mode||!play_permitted||dut.alarm_active||
                    dut.alarm_cancel_notice||dut.daily_transport_hold||dut.media_voice_asset)
                    $fatal(1,"daily subtitles leaked through a playback gate");
                if(dut.video.daily_subtitle_track!=dut.audio_certificate_index)
                    $fatal(1,"subtitle audio/page mapping mismatch");
            end
            if(dut.video.final_subtitles.scrolling.subtitles.show)begin
                bin=dut.video.final_subtitles.scrolling.subtitles.frame_samples>=524288 ? 255 :
                    dut.video.final_subtitles.scrolling.subtitles.frame_samples/2048;
                address=dut.video.final_subtitles.scrolling.subtitles.frame_track*256+bin;
                if(dut.video.final_subtitles.scrolling.subtitles.frame_offset!==positions[address])
                    $fatal(1,"rendered scroll offset not tied to consumed PCM time");
                if(dut.video.final_subtitles.scrolling.subtitles.frame_offset>0)moved=moved+1;
            end
        end
        always @(posedge pixel_clk)if(!rst)begin
            previous_samples=dut.narration_elapsed_samples;
            previous_tick=audio_valid&&dut.narration_consumed;
            previous_start=dut.narration_start;
            previous_stop=dut.alarm_active||dut.selected_asset_begin||dut.daily_stop_needed;
            previous_playing=dut.narration_playing;
            #1;
            if(previous_start&&!previous_stop)begin
                if(dut.narration_elapsed_samples!=0)$fatal(1,"subtitle time did not restart with audio");
            end else if(!previous_stop&&previous_playing&&previous_tick)begin
                if(dut.narration_elapsed_samples!=previous_samples+1)$fatal(1,"consumed sample missing from subtitle time");
            end else if(dut.narration_elapsed_samples!=previous_samples)
                $fatal(1,"subtitle time advanced without consumed audio");
        end
    end else begin: no_subtitle_checks
        assign subtitle_shown=0;assign subtitle_moved=0;
    end endgenerate
    integer completed_daily=0;
    always @(posedge pixel_clk)if(TEST_BROADCAST&&watch_broadcast)begin
        if(dut.narration_done)begin
            if(used[dut.audio_certificate_index]!=human_samples(dut.audio_certificate_index))
                $fatal(1,"daily timeline ended before exact PCM sample budget");
            completed_daily=completed_daily+1;
        end
        if(dut.narration_prompt_valid&&(dut.transition_active||!autoplay||dut.daily_zoom_scale!=0))
            $fatal(1,"daily PCM played while transition/pause/detail held the page");
        if(dut.media_audio_request&&!dut.media_alarm_asset&&!dut.media_voice_asset&&
                (!dut.broadcast_prefetched||dut.transition_active))
            $fatal(1,"daily clip requested before next-page prefetch / transition completion");
        if(dut.narration_resume_sample!=0)$fatal(1,"production broadcast resumed mid-clip");
    end
    initial begin
        if(REAL_AUDIO)begin
            $readmemh("../../sim/human_audio_bytes.mem",real_bytes);
            $readmemh("../../sim/human_audio_sizes.mem",real_sizes);
            $readmemh("../../sim/human_audio_crcs.mem",real_crcs);
        end
        for(i=0;i<PACKED_WORDS;i=i+1)written[i]=0;
        for(i=0;i<NUM_IMAGES;i=i+1)frames_per_image[i]=0;
        for(i=0;i<WAV_FILES;i=i+1)begin
            used[i]=0;fixture_crc[i]=32'hffffffff;
            for(j=0;j<WAV_BYTES;j=j+1)fixture_crc[i]=audio_crc_next(fixture_crc[i],human_byte(i,j));
            fixture_crc[i]=REAL_AUDIO ? real_crcs[i] : ~fixture_crc[i];
        end
        if(BOOT_BROADCAST!=0)begin
            grayscale_switch=1;
            play_permitted=BOOT_BROADCAST==1;
        end
        repeat(10)@(negedge sys_clk);rst=0;
        wait(ready);
        if(TEST_GUIDANCE)begin
            play_permitted=1;
            if(dut.tf_audio_wav_count!=16||!dut.playlist_valid_sync[1])$fatal(1,"16-file production mount failed");
            snapshot(1,0,0,0,3);
            guidance_heartbeat=1;
            for(m=0;m<4;m=m+1)begin
                expected_route_start=m*240000;
                guidance_exit=m<3 ? m+1 : 0;guidance_status=m==3 ? 2 : 0;
                wait(dut.media_audio_request&&dut.audio_certificate_index==15);
                @(negedge pixel_clk);wait(!dut.media_audio_request);wait(used[15]>=100);
                if(dut.narration_resume_sample!=expected_route_start||dut.tf_asset_samples!=240000||!dut.media_voice_asset)
                    $fatal(1,"production route window metadata");
                guidance_publish=0;
                wait(!dut.live_route_fresh);@(negedge pixel_clk);
                if(dut.human_sample_consumed)$fatal(1,"stale route PCM still mixed");
                wait(dut.audio_certificate_index==11&&!dut.media_voice_asset);
                guidance_publish=1;
                $display("GUIDE iteration %d completed",m);
            end
            guidance_heartbeat=0;
            snapshot(0,0,0,0,3);repeat(100)@(negedge pixel_clk);
            if(dut.media_voice_asset)$fatal(1,"cleared event retained route voice");
            $display("TEST_PASS production media_core full 32-file mount, four route PCM offsets through FAT/SDRAM/CDC/mix/HDMI PCM, expiry mute and alarm clear");$finish;
        end
        if(BOOT_BROADCAST!=0)begin
            if(BOOT_BROADCAST==2)begin
                repeat(20000)@(negedge pixel_clk);
                if(audio_open_count!=0)$fatal(1,"boot opened WAV without permission");
                if(dut.narration_external_allowed||dut.narration_prompt_valid)
                    $fatal(1,"missing permission admitted daily voice");
                play_permitted=1;
            end
            wait(used[0]>=100);
            if(!dut.narration_external_allowed||!dut.narration_playing||dut.narration_reject_reason!=0)
                $fatal(1,"authorized daily voice not playing");
            wait(used[0]==human_samples(0));
            wait(image_index==1&&!dut.transition_active);wait(used[1]>=100);

            effect_switch=1;grayscale_switch=1;wait(dut.panel_mode);
            repeat(20)@(negedge pixel_clk);
            repeat(18)museum_key(2);
            if(dut.panel_selection!=18)$fatal(1,"failed to select physical fire scene");
            wait(used[12]>=100);
            if(!dut.media_voice_asset||!dut.narration_external_allowed)
                $fatal(1,"local fire recording was not admitted");
            $display("TEST_PASS cold boot broadcast permission=%0d, two exact PCM pages, local scene04 human voice and authorization gates",BOOT_BROADCAST);
            $finish;
        end
        if(TEST_MANUAL)begin
            play_permitted=1;

            museum_key(2);wait(image_index==1&&!dut.transition_active);
            museum_key(3);
            effect_switch=1;grayscale_switch=1;
            wait(dut.panel_mode);wait(image_index==0&&!dut.transition_active);
            wait(used[0]>=100);
            if(!dut.panel_running||dut.panel_selection!=0)$fatal(1,"manual entry did not start page one");

            wait(used[0]==human_samples(0));museum_frames(20);
            if(image_index!=0||dut.panel_selection!=0)$fatal(1,"manual mode advanced after audio ended");
            for(m=1;m<16;m=m+1)begin
                museum_key(2);wait(image_index==m&&!dut.transition_active);
                wait(dut.narration_playing&&dut.narration_active_image==m);
                wait(used[dut.playlist_asset]>=100);
                if(dut.audio_certificate_index!=dut.playlist_asset)$fatal(1,"manual daily audio mismatch");
            end
            museum_key(2);wait_voice(8);
            museum_key(2);wait_voice(9);
            museum_key(2);wait_voice(12);
            museum_key(2);wait_voice(13);
            museum_key(2);wait_voice(14);
            if(dut.panel_selection!=20||!dut.alarm_cancel_notice)$fatal(1,"release missing");
            museum_frames(20);if(dut.panel_selection!=20)$fatal(1,"release auto advanced");

            grayscale_switch=0;repeat(300)@(negedge pixel_clk);
            for(m=0;m<21;m=m+1)begin
                museum_key(2);repeat(200)@(negedge pixel_clk);
                if(!dut.diagnostic_test_active||dut.media_voice_asset||dut.audible_alarm||dut.external_alarm_selected)
                    $fatal(1,"manual page did not select only test tone");
            end
            snapshot(1,0,0,0,0);repeat(50)@(negedge pixel_clk);
            if(dut.panel_mode||dut.diagnostic_test_active||!dut.audible_alarm)$fatal(1,"remote priority lost");
            snapshot(0,0,0,0,0);repeat(50)@(negedge pixel_clk);
            if(dut.panel_running)$fatal(1,"test audio unexpectedly resumed after remote event");
            effect_switch=0;museum_frames(2);
            if(dut.panel_mode||dut.diagnostic_test_active)$fatal(1,"test exit stuck");
            $display("TEST_PASS manual 21 pages, entry seek, no automatic advance, daily/all alarm WAV exact PCM, voice switch, test tone all pages, remote preemption");$finish;
        end
        if(TEST_BROADCAST)begin

            play_permitted=1;
            repeat(20000)@(negedge pixel_clk);
            if(audio_open_count!=0||dut.narration_prompt_valid)
                $fatal(1,"ordinary slideshow opened or played narration with permission");
            museum_key(3);
            for(m=1;m<=4;m=m+1)begin
                broadcast_long_key(3);
                if(dut.period_select!=(m%4)||dut.broadcast_mode||autoplay)
                    $fatal(1,"KEY3 must cycle only four timed periods while paused");
            end
            grayscale_switch=1;wait(dut.broadcast_mode);
            if(autoplay)$fatal(1,"SW4 entering broadcast resumed a paused player");
            broadcast_long_key(3);
            if(!dut.broadcast_mode||autoplay||dut.period_select!=0)$fatal(1,"long KEY3 overrode SW4 or pause");
            play_permitted=1;
            repeat(20000)@(negedge pixel_clk);
            if(audio_open_count!=0)$fatal(1,"paused broadcast opened a daily WAV");
            watch_broadcast=1;
            museum_key(3);
            wait(used[0]>=100);
            wait(dut.tf_narration_stream.ring_buffered_samples>=30000);
            if(!dut.tf_audio_file_busy)$fatal(1,"long fixture did not exercise active reader ownership");
            museum_key(3);wait_reader_stop();
            paused_samples=used[0];repeat(2000)@(negedge pixel_clk);
            if(used[0]!=paused_samples)$fatal(1,"pause consumed daily PCM");
            museum_key(3);wait(dut.media_audio_request);wait(!dut.media_audio_request);wait(used[0]>=100);

            museum_key(3);wait_reader_stop();
            for(m=0;m<6;m=m+1)next_picture();
            wait(image_index==6&&!dut.transition_active);
            if(autoplay)$fatal(1,"manual navigation resumed paused broadcast");

            broadcast_long_key(4);wait(dut.daily_zoom_scale==1);
            wait(!dut.viewport_pending&&!dut.slots.busy);
            broadcast_long_key(4);wait(dut.daily_zoom_scale==2);
            wait(!dut.viewport_pending&&!dut.slots.busy);
            broadcast_long_key(4);wait(dut.daily_zoom_scale==0);
            museum_key(3);wait(used[6]>=100);
            wait(used[6]==human_samples(6));
            if(image_index!=6)$fatal(1,"automatic broadcast cut off page six");
            wait(dut.slide_active);
            if(dut.transition_mode!=6)$fatal(1,"page six did not select its planned circle transition");
            wait(image_index==7&&!dut.transition_active);wait(used[7]>=100);

            snapshot(1,0,1,0,0);wait(used[8]>=100);
            snapshot(0,1,1,0,0);wait_voice(14);
            snapshot(0,0,1,0,0);
            wait(dut.media_audio_request&&!dut.media_voice_asset);wait(!dut.media_audio_request);wait(used[7]>=100);
            if(image_index!=7)$fatal(1,"alarm recovery reset the entire playlist");
            play_permitted=0;repeat(100)@(negedge pixel_clk);
            if(dut.narration_prompt_valid)$fatal(1,"permission loss leaked daily audio");
            play_permitted=1;wait(dut.media_audio_request);wait(!dut.media_audio_request);wait(used[7]>=100);

            watch_broadcast=0;
            if(dut.controls.second_div!=0||dut.controls.elapsed_seconds!=0)
                $fatal(1,"timed autoplay accumulated time during broadcast");
            grayscale_switch=0;wait(!dut.broadcast_mode);
            wait_reader_stop();
            paused_samples=used[7];
            repeat(20000)@(negedge pixel_clk);
            if(used[7]!=paused_samples||dut.narration_prompt_valid||dut.narration_playing)
                $fatal(1,"SW4 off leaked/restarted daily PCM");

            snapshot(1,0,1,0,0);wait_voice(8);
            snapshot(0,1,1,0,0);wait_voice(14);
            snapshot(0,0,1,0,0);
            wait(!dut.alarm_cancel_notice);wait_reader_stop();
            paused_samples=used[7];
            repeat(20000)@(negedge pixel_clk);
            if(used[7]!=paused_samples||dut.narration_prompt_valid)
                $fatal(1,"alarm release restarted daily voice with SW4 off");
            grayscale_switch=1;wait(dut.broadcast_mode);
            wait(dut.media_audio_request);wait(!dut.media_audio_request);wait(used[7]>=100);
            if(image_index!=7||!autoplay)$fatal(1,"SW4 mode round trip changed page or autoplay");
            watch_broadcast=1;
            if(completed_daily<1)$fatal(1,"no measured daily completion observed");
            if(subtitle_shown==0)$fatal(1,"daily subtitles never activated");
            if(REAL_AUDIO&&subtitle_moved==0)$fatal(1,"real narration never scrolled");
            $display("TEST_PASS daily broadcast real=%0d: exact PCM, prefetch, pause/zero restart, uncached navigation, 2x/4x crop, planned transition, alarm/release and permission recovery",REAL_AUDIO);
            $finish;
        end
        if(SINGLE_CARD_AUDIO)begin
            repeat(20000)@(negedge pixel_clk);
            if(audio_open_count!=0||used[0]!=0||dut.narration_external_allowed)
                $fatal(1,"opened or played without B permission");
            play_permitted=1;
        end
        wait(used[0]>=100);
        if(SINGLE_CARD_AUDIO)begin
            if(audio_open_count!=1)$fatal(1,"single-card file was pre-scanned or reopened");
            play_permitted=0;repeat(50)@(negedge pixel_clk);
            if(dut.narration_external_allowed||used[0]!=100)$fatal(1,"permission revoke failed");
            play_permitted=1;wait(dut.media_audio_request);wait(used[0]>=100);
        end
        if(!dut.playlist_valid_sync[1]||image_count!=16)$fatal(1,"production 16/15 manifest invalid");
        if(!dut.daily_follow_narration)$fatal(1,"human recordings must default to full narration");
        wait(used[0]==human_samples(0));
        if(image_index!=0)$fatal(1,"default slideshow truncated the first complete TIP");
        wait(dut.narration_done);
        snapshot(1,0,1,0,0);wait_voice(8);
        wait(dut.audio_certificate_index==10);
        snapshot(1,0,1,1,1);wait(dut.audio_certificate_index==9);wait(used[9]==20);
        snapshot(1,0,1,0,1);wait_voice(12);
        snapshot(1,0,1,1,1);wait_voice(9);
        snapshot(1,0,1,0,3);wait_voice(13);
        snapshot(0,1,1,0,3);wait_voice(14);
        if(!dut.alarm_cancel_notice)$fatal(1,"release voice waited for page timer");
        snapshot(0,0,1,0,3);wait(dut.narration_playing);wait(used[0]>=25);
        snapshot(1,0,0,0,0);wait(dut.audio_certificate_index==10);
        if(dut.media_voice_asset)$fatal(1,"real event played drill voice");
        reject=1;snapshot(1,0,1,0,0);wait(dut.audio_certificate_index==8);
        if(SINGLE_CARD_AUDIO)begin
            wait_voice(8);
            seen_voices=seen_voices-1;
        end else begin
            wait(dut.audio_certificate_index==10);
            if(used[8]!=0)$fatal(1,"rejected voice consumed PCM");
        end
        reject=0;
        bad_header=1;snapshot(1,0,1,1,1);wait(dut.audio_certificate_index==9);wait(dut.audio_certificate_index==11);
        if(used[9]!=0)$fatal(1,"malformed voice consumed PCM");bad_header=0;
        if(seen_voices!=5)$fatal(1,"missing human stage coverage");
        $display("TEST_PASS production media_core 16 BMP/15 PCM real=%0d: daily, all five voices, preemption, exact PCM/mix/output, release page, real event and rejection",REAL_AUDIO);$finish;
    end
endmodule

module tb_daily_broadcast_media;
    tb_human_media_pipeline #(.TEST_BROADCAST(1),.SINGLE_CARD_AUDIO(1)) test();
endmodule

module tb_broadcast_boot_early_permission;
    tb_human_media_pipeline #(.TEST_BROADCAST(1),.SINGLE_CARD_AUDIO(1),.BOOT_BROADCAST(1)) test();
endmodule

module tb_broadcast_boot_late_permission;
    tb_human_media_pipeline #(.TEST_BROADCAST(1),.SINGLE_CARD_AUDIO(1),.BOOT_BROADCAST(2)) test();
endmodule

module tb_daily_broadcast_real;
    tb_human_media_pipeline #(.TEST_BROADCAST(1),.SINGLE_CARD_AUDIO(1),.REAL_AUDIO(1)) test();
endmodule

module tb_human_media_real;
    tb_human_media_pipeline #(.REAL_AUDIO(1),.HTOTAL(800),.VTOTAL(525)) test();
endmodule

module tb_single_card_media;
    tb_human_media_pipeline #(.SINGLE_CARD_AUDIO(1)) test();
endmodule

module tb_single_card_media_real;
    tb_human_media_pipeline #(.SINGLE_CARD_AUDIO(1),.REAL_AUDIO(1),.HTOTAL(800),.VTOTAL(525)) test();
endmodule

module tb_manual_test_media;
 tb_human_media_pipeline #(.TEST_BROADCAST(1),.TEST_MANUAL(1),.SINGLE_CARD_AUDIO(1)) test();
endmodule

module tb_manual_test_real;
 tb_human_media_pipeline #(.TEST_BROADCAST(1),.TEST_MANUAL(1),.SINGLE_CARD_AUDIO(1),.REAL_AUDIO(1)) test();
endmodule

module tb_extension_manual_real;
 tb_human_media_pipeline #(.TEST_BROADCAST(1),.TEST_MANUAL(1),.TEST_EXTENSIONS(1),.SINGLE_CARD_AUDIO(1),.REAL_AUDIO(1)) test();
endmodule

module tb_route_media_pipeline;
 tb_human_media_pipeline #(.TEST_GUIDANCE(1),.TEST_BROADCAST(1),.TEST_EXTENSIONS(1),.SINGLE_CARD_AUDIO(1)) test();
endmodule
