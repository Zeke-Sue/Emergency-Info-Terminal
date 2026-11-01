`timescale 1ns/1ps

module tb_media_player #(
    parameter integer WIDTH=8, HEIGHT=4, BURST=4,
    parameter integer HTOTAL=128, VTOTAL=16, HSTART=32, VSTART=4,
    parameter integer FADE_STEPS=1, ENABLE_EFFECTS=0,
    parameter integer FIXED_RATE_AXIS=0,
    parameter integer TEST_ZOOM_RELOAD=0,
    parameter integer TEST_TRANSITIONS=0, TEST_MUSEUM=0,
    parameter integer NUM_IMAGES=8, FOUR_SLOT_CACHE=1, TEST_CACHE_STRESS=0,
    parameter integer TEST_AUDIO=0, TEST_IMA=0, TEST_RESUME=0, STRICT_CHAIN=0
);
    reg sys_clk=0,pixel_clk=0,rst=1,key_zoom=1,key1=1,key2=1,key3=1;
    reg [1:0] effect_switch=0;
    reg overlay_switch=1,grayscale_switch=0;
    reg corrupt_image4=0;
    reg [95:0] audio_certificate=0;
    reg certificate_valid=0;
    reg [31:0] audio_crc;
    integer audio_consumed=0,audio_emitted=0,paused_samples;
    integer audio_stage=0;
    integer resume_base=0,resume_prefix=0;
    reg audio_cfg_we=0;reg [7:0] audio_cfg_index=0;
    reg [31:0] audio_cfg_sample=64;
    reg command_valid=0;reg [24:0] command_snapshot=0;
    wire command_ready,command_result;
    integer audio_ticks=0,reference_gain,reference_scaled,reference_magnitude;
    generate if(TEST_AUDIO)begin: audio_watchdog
        initial begin
            repeat(1500000)@(posedge sys_clk);
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
    localparam integer FAT_SECTORS=(CLUSTER7+FILE_SECTORS_OTHER+128)/128;
    localparam integer DATA_LBA=1+FAT_SECTORS;
    localparam integer WAV_CLUSTER=CLUSTER7+FILE_SECTORS_OTHER+2;
    localparam integer WAV_SAMPLES=1000,WAV_BYTES=TEST_IMA ? 316 : 44+WAV_SAMPLES*2;
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
        .CONTROL_HZ(TEST_AUDIO ? 25000000 : TEST_MUSEUM ? 25000 : 1000),.DEBOUNCE_CYCLES(4),.DRAIN_CYCLES(8),
        .MUSEUM_UI(TEST_MUSEUM),.KEY_LONG_CYCLES(1000),.IDLE_SECONDS(60),
        .FADE_STEPS(FADE_STEPS),.ENABLE_EFFECTS(ENABLE_EFFECTS),.FIXED_RATE_AXIS(FIXED_RATE_AXIS),
        .FOUR_SLOT_CACHE(FOUR_SLOT_CACHE),.LOGICAL_IMAGES(NUM_IMAGES),
        .ENABLE_TF_NARRATION(TEST_AUDIO),.STRICT_CHAIN(STRICT_CHAIN),
        .BOARD_EVENT_AUTHORITY(TEST_RESUME),
        .SCAN_FIRST(0),.SCAN_LIMIT(20000)) dut(
        .sys_clk(sys_clk),.pixel_clk(pixel_clk),.sys_rst(rst),.pixel_rst(rst),
        .key_zoom_n(key_zoom),.key_next_n(key1),.key_auto_n(key2),.key_period_n(key3),
        .effect_switch(effect_switch),.overlay_switch(overlay_switch),
        .grayscale_switch(grayscale_switch),
        .mem_init(!rst),.mem_busy(mem_busy),.sd_ready(!rst),
        .emergency_cmd_valid(command_valid),.emergency_cmd_opcode(3'd6),.emergency_cmd_source(2'd2),
        .emergency_cmd_snapshot(command_snapshot),.emergency_cmd_epoch_changed(1'b0),
        .emergency_cmd_ready(command_ready),.emergency_result_valid(command_result),
        .emergency_cmd_kind(3'd0),.emergency_cmd_event_id(16'd7),.emergency_cmd_sequence(8'd1),
        .emergency_cmd_level(3'd4),.emergency_cmd_drill(1'b0),.emergency_cmd_pending(1'b0),
        .emergency_cmd_region(3'd0),.emergency_cmd_time_trusted(1'b0),
        .emergency_cmd_remaining_seconds(16'd0),
        .sync_blocked_valid(1'b0),.sync_blocked_set(8'd0),
        .console_proxy_valid(1'b0),.console_proxy_status(96'd0),
        .narration_enable(TEST_AUDIO!=0),.narration_cfg_we(audio_cfg_we),
        .narration_cfg_index(audio_cfg_index),.narration_cfg_sample(audio_cfg_sample),
        .narration_cfg_subtitle(8'd3),.narration_cfg_last(audio_cfg_index==1),
        .narration_sample_valid(1'b0),.narration_sample(16'sd0),
        .narration_asset_begin(1'b0),.narration_asset_complete(1'b0),
        .narration_asset_purpose(8'd0),.narration_asset_length(32'd0),
        .narration_asset_crc32(32'd0),.narration_certificate_valid(certificate_valid),
        .narration_certificate(audio_certificate),
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
            6:first_cluster=CLUSTER6;default:first_cluster=CLUSTER7;
        endcase
    endfunction
    function automatic [31:0] fat_entry(input integer cluster);
        begin
            fat_entry=0;
            if(cluster==0)fat_entry=32'h0ffffff8;
            else if(cluster==1)fat_entry=32'hffffffff;
            else if(cluster==2)fat_entry=32'h0fffffff;
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
            else if(cluster>=CLUSTER7 && cluster<CLUSTER7+FILE_SECTORS_OTHER)
                fat_entry=(cluster==CLUSTER7+FILE_SECTORS_OTHER-1) ? 32'h0fffffff : cluster+1;
            else if(TEST_AUDIO&&cluster>=WAV_CLUSTER&&cluster<WAV_CLUSTER+4)
                fat_entry=cluster==WAV_CLUSTER+3 ? 32'h0fffffff : cluster+1;
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
            end else if(lba==DATA_LBA)begin
                p=idx/32;epos=idx%32;
                if(p<NUM_IMAGES)begin
                    cluster=first_cluster(p);sz=size_of(p);
                    case(epos)
                        0:card_byte="I";1:card_byte="M";2:card_byte="A";
                        3:card_byte="G";4:card_byte="E";
                        5:card_byte="1"+p;6,7:card_byte=" ";
                        8:card_byte="B";9:card_byte="M";10:card_byte="P";
                        11:card_byte=8'h20;
                        26:card_byte=cluster;27:card_byte=cluster>>8;
                        28,29,30,31:card_byte=sz>>((epos-28)*8);
                        default:card_byte=0;
                    endcase
                end else if(TEST_AUDIO&&p==NUM_IMAGES)begin
                    case(epos)
                        0:card_byte="A";1:card_byte="U";2:card_byte="D";
                        3:card_byte="I";4:card_byte="O";5,6,7:card_byte=" ";
                        8:card_byte="W";9:card_byte="A";10:card_byte="V";
                        11:card_byte=8'h20;
                        26,27:card_byte=WAV_CLUSTER>>((epos-26)*8);
                        28,29,30,31:card_byte=WAV_BYTES>>((epos-28)*8);
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
            if(TEST_AUDIO&&lba>=DATA_LBA+WAV_CLUSTER-2&&lba<DATA_LBA+WAV_CLUSTER+2)
                card_byte=wav_byte((lba-DATA_LBA-WAV_CLUSTER+2)*512+idx);
        end
    endfunction
    always @(posedge pixel_clk)if(TEST_AUDIO&&!rst)begin
        if(dut.daily_audio_valid)audio_ticks=audio_ticks+1;
        if(dut.daily_audio_valid&&dut.narration_prompt_valid)begin
            if(dut.tf_stream_sample!==wav_sample(audio_consumed-resume_base))
                fail("real FAT WAV FIFO sample order");
            expected_audio=$signed(dut.daily_audio_left)+($signed(dut.tf_stream_sample)>>>1);
            reference_gain=audio_ticks>=240 ? 1024 : (audio_ticks*1024)/240;
            reference_scaled=($signed(expected_audio)*reference_gain)>>>10;
            reference_magnitude=reference_scaled<0 ? -reference_scaled : reference_scaled;
            if(reference_magnitude>24576)
                reference_magnitude=24576+(reference_magnitude-24576)/4;
            if(reference_magnitude>32767)reference_magnitude=32767;
            expected_audio=reference_scaled<0 ? -reference_magnitude : reference_magnitude;
            audio_consumed=audio_consumed+1;
        end
        if(audio_valid&&dut.narration_consumed)begin
            if(audio_left!==expected_audio[15:0]||audio_right!==audio_left)begin
                $display("PCM sample=%0d actual=%0d expected=%0d tick=%0d gain=%0d",audio_emitted,$signed(audio_left),$signed(expected_audio),audio_ticks,reference_gain);
                fail("final HDMI PCM did not contain authorized WAV sample");
            end
            audio_emitted=audio_emitted+1;
        end
        if(dut.narration_underflow)fail("authorized narration underflow");
    end
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
                    if(!written[rd_addr])fail("read of uncommitted memory");
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
    integer frames_per_image [0:7];
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
                    if(!(TEST_RESUME&&audio_stage>=5)&&axis_data!==(TEST_MUSEUM ? 24'h162d38 : expected_display_pixel(frame_image,stream_x,stream_y,
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
    integer i,j,k;
    initial begin
        if($test$plusargs("waves"))begin
            if(TEST_MUSEUM) $dumpfile("tb_museum_integration.vcd");
            else $dumpfile("tb_media_player.vcd");
            if($test$plusargs("waves_all"))begin
                $dumpvars(1,dut);$dumpvars(1,dut.controls);$dumpvars(1,dut.video);
                $dumpvars(1,dut.loader);$dumpvars(1,dut.cache);
            end else $dumpvars(1,wave_signals);
        end
        for(i=0;i<PACKED_WORDS;i=i+1)written[i]=0;
        for(i=0;i<NUM_IMAGES;i=i+1)frames_per_image[i]=0;
        repeat(10)@(negedge sys_clk);rst=0;
        if(TEST_AUDIO)begin effect_switch=1;grayscale_switch=1;end
        wait(ready);#1;
        if(image_count!=NUM_IMAGES || write_count!=(FOUR_SLOT_CACHE ? PIXELS*3/4 : PACKED_WORDS))
            fail("wrong loaded image/packed word count");
        if(!FOUR_SLOT_CACHE && (!saw_image4_first || (FILE_SECTORS3>1 && !saw_image4_fragment)))
            fail("fragmented FAT cluster chain was not followed");
        for(i=0;i<(FOUR_SLOT_CACHE ? 0 : NUM_IMAGES);i=i+1)for(j=0;j<HEIGHT;j=j+1)for(k=0;k<WIDTH;k=k+1)
            if(stored_pixel(i,k,j)!==expected_pixel(i,k,j))
                fail("packed cache contents/row direction mismatch");
        $display("PASS: initial %0dx%0d BMP cache ready, four-slot=%0d, %0d packed writes",WIDTH,HEIGHT,FOUR_SLOT_CACHE,write_count);
        if(!autoplay)fail("autoplay was not active after load");
        museum_key(3);
        if(autoplay)fail("KEY3 short did not pause autoplay");
        if(TEST_AUDIO)begin
            if(TEST_RESUME)begin
                @(negedge pixel_clk);audio_cfg_we=1;
                @(negedge pixel_clk);audio_cfg_index=1;audio_cfg_sample=256;
                @(negedge pixel_clk);audio_cfg_we=0;
            end
            audio_stage=1;
            audio_crc=32'hffffffff;
            for(i=0;i<WAV_BYTES;i=i+1)audio_crc=audio_crc_next(audio_crc,wav_byte(i));
            wait(dut.tf_asset_length!=0);repeat(8)@(negedge pixel_clk);
            audio_stage=2;
            $display("AUDIO: pre-read complete");
            if(dut.tf_asset_crc32!==~audio_crc||dut.tf_asset_length!=WAV_BYTES||
                    dut.tf_asset_samples!=WAV_SAMPLES)
                fail("FAT WAV pre-read length/CRC");
            audio_certificate={3'd0,16'h0500,4'd0,1'b1,~audio_crc^32'd1,32'd0,8'h21};
            audio_certificate[39:8]=WAV_BYTES;
            certificate_valid=1;repeat(12000)@(negedge pixel_clk);
            if(dut.narration_external_allowed||audio_consumed!=0)fail("wrong certificate reached PCM");
            audio_certificate[71:40]=~audio_crc;
            audio_stage=3;
            wait(dut.narration_external_allowed);wait(dut.narration_playing);
            audio_stage=4;
            repeat(6000)@(negedge pixel_clk);
            if(audio_consumed!=0)fail("paused follow mode consumed WAV");
            museum_key(3);wait(audio_consumed==100);museum_key(3);
            audio_stage=5;
            paused_samples=audio_consumed;repeat(6000)@(negedge pixel_clk);
            if(audio_consumed!=paused_samples)fail("pause lost WAV position");
            if(TEST_RESUME)begin
                if(dut.narration_sentence_start!=64)fail("sentence cue not tracked before alarm");
                command_snapshot=25'h21;command_valid=1;
                @(negedge pixel_clk);command_valid=0;wait(command_result);
                wait(dut.alarm_active);repeat(200)@(negedge pixel_clk);
                if(!dut.saved_sentence_valid||dut.saved_sentence_sample!=64)
                    fail("alarm did not save interrupted sentence");
                resume_prefix=audio_consumed;resume_base=resume_prefix-64;
                while(!command_ready)@(negedge pixel_clk);
                command_snapshot=0;command_valid=1;
                @(negedge pixel_clk);command_valid=0;wait(command_result);
                wait(!dut.alarm_active);wait(dut.narration_playing);
                if(dut.narration_resume_sample!=64||dut.narration_elapsed_samples!=64)
                    fail("resume did not align decoder and subtitle timeline");
            end
            museum_key(3);wait(dut.narration_done);repeat(4)@(negedge pixel_clk);
            audio_stage=6;
            if(audio_consumed!=WAV_SAMPLES+resume_base||audio_emitted!=WAV_SAMPLES+resume_base||
                    dut.narration_elapsed_samples!=WAV_SAMPLES)
                fail("WAV output/timeline actual length mismatch");
            $display("TEST_PASS media_core FAT WAV -> CRC certificate -> async FIFO -> pause -> final PCM, %0d samples",audio_emitted);
            $finish;
        end
        if(TEST_MUSEUM)begin
            museum_frames(2);if(dut.museum_page!=2)fail("museum main after load");
            museum_key(2);museum_key(3);museum_frames(2);
            if(dut.museum_page!=4 || autoplay)fail("KEY2 next / KEY3 confirm mapping");
            museum_key(1);wait(image_index==3);wait(!dut.transition_active);
            museum_key(2);wait(image_index==0);wait(!dut.transition_active);
            museum_key(3);museum_frames(2);if(dut.museum_page!=5)fail("browse detail");
            museum_key(2);museum_frames(2);if(!zoom_mode)fail("museum zoom commit");
            museum_key(4);museum_frames(2);if(dut.museum_page!=4)fail("KEY4 parent return");
            museum_key(4);museum_frames(2);if(dut.museum_page!=2)fail("KEY4 main return");
            museum_key(3);museum_frames(2);if(!autoplay)fail("guide start");
            museum_key(3);museum_frames(2);if(autoplay)fail("guide pause");
            museum_key(3);museum_frames(2);if(!autoplay)fail("guide resume");
            @(negedge pixel_clk);key2=0;repeat(1100)@(negedge pixel_clk);key2=1;
            museum_frames(2);if(dut.museum_page!=2 || autoplay)fail("long KEY4 home");
            museum_key(1);museum_key(3);museum_frames(2);
            if(dut.museum_page!=7)fail("settings selection");
            museum_key(2);
            @(negedge sys_clk);for(i=0;i<4*PIXELS;i=i+1)written[i]=0;write_count=0;
            museum_key(3);wait(!ready);wait(ready);museum_frames(3);
            if(write_count!=4*PIXELS || dut.museum_page!=2)fail("museum reload handshake");
            if(underflow || overflow)fail("museum pipeline fault");
            museum_fault_test=1;
            #3;force dut.loader_error=4'd5;
            museum_frames(5);if(dut.museum_error!=5 || dut.museum_page!=8)fail("error snapshot CDC");
            museum_key(4);museum_frames(2);if(dut.museum_page!=2)fail("persistent fault return");
            #3;force dut.loader_error=4'd6;
            museum_frames(5);if(dut.museum_error!=6 || dut.museum_page!=8)fail("new fault after dismissal");
            release dut.loader_error;
            museum_frames(4);if(dut.museum_error!=0)fail("error snapshot recovery");
            museum_fault_test=0;
            $display("TEST_PASS tb_museum_integration physical keys, previous wrap, pause/resume, zoom, long home, reload and error CDC with unrelated clocks, %0d checked fixed-rate frames",good_frames);
            $finish;
        end
        wait(frames_per_image[0]>=1);
        if(TEST_CACHE_STRESS)begin
            next_picture();next_picture();next_picture();next_picture();
            wait(image_index==4);wait(frames_per_image[4]>=1);
            museum_key(1);museum_key(1);museum_key(1);
            wait(image_index==1);wait(frames_per_image[1]>=1);
            museum_key(1);wait(image_index==0);wait(!dut.transition_active);
            museum_key(1);wait(image_index==7);wait(frames_per_image[7]>=1);
            next_picture();wait(image_index==0);wait(!dut.transition_active);
            $display("PASS: coalesced distant misses, reverse navigation, previous wrap with unrelated clocks");
        end
        if(TEST_ZOOM_RELOAD)begin
            @(negedge sys_clk);
            if(!FOUR_SLOT_CACHE)begin
                for(i=0;i<PACKED_WORDS;i=i+1)written[i]=0;
                write_count=0;
            end
            fork
                reload_media();
                begin wait(!ready);#1;if(image_count!=0)fail("reload did not reset image count");end
            join
            wait(ready);#1;
            if(image_count!=NUM_IMAGES || (!FOUR_SLOT_CACHE && write_count!=PACKED_WORDS))
                fail("reload did not rebuild all eight packed frames");
            for(i=0;i<(FOUR_SLOT_CACHE ? 0 : NUM_IMAGES);i=i+1)for(j=0;j<HEIGHT;j=j+1)for(k=0;k<WIDTH;k=k+1)
                if(stored_pixel(i,k,j)!==expected_pixel(i,k,j))
                    fail("reloaded cache contents mismatch");
            if(!autoplay)fail("reload did not restore default autoplay");
            museum_key(3);
            if(autoplay)fail("KEY3 short did not pause autoplay after reload");
            $display("PASS: KEY4 long-press TF reload restored initial cache, four-slot=%0d",FOUR_SLOT_CACHE);
        end
        if(TEST_TRANSITIONS)begin
            grayscale_switch=1;repeat(5)@(negedge pixel_clk);
            if(!grayscale_enable||autoplay)fail("SW4 did not enable grayscale cleanly");
            grayscale_switch=0;repeat(5)@(negedge pixel_clk);
            if(grayscale_enable||autoplay)fail("SW4 did not restore colour");

            toggle_zoom();wait(zoom_mode);repeat(2)@(posedge dut.frame_tick);
            for(i=0;i<4;i=i+1)begin
                effect_switch=i;repeat(6)@(negedge pixel_clk);
                next_picture();wait(image_index==((i+1)&3));
                wait(frames_per_image[(i+1)&3]>=1);
            end
            toggle_zoom();wait(!zoom_mode);repeat(2)@(posedge dut.frame_tick);
            $display("PASS: switch-selected fade, curtain, vertical push and horizontal push transitions with 2x zoom");
        end else begin
            for(i=1;i<NUM_IMAGES;i=i+1)begin
                next_picture();wait(image_index==i);wait(frames_per_image[i]>=1);
                if(WIDTH>=640) $display("PASS: image%0d checked at %0t",i,$time);
            end
            next_picture();wait(image_index==0);wait(frames_per_image[0]>=2);
        end
        if(autoplay)fail("manual mode unexpectedly changed");
        if(!saw_image4_first || (FILE_SECTORS3>1 && !saw_image4_fragment))
            fail("fragmented FAT cluster chain was not followed");
        if(TEST_CACHE_STRESS)begin
            wait(!dut.slots.busy);museum_fault_test=1;corrupt_image4=1;
            next_picture();next_picture();next_picture();
            wait(loader_error!=0);
            if(loader_error!=7 || !ready || image_index!=0 || dut.resident[3])
                fail("failed replacement was published or discarded the current image");
            wait(dut.failed_images[3]);
            while(!dut.resident[4])begin
                @(negedge pixel_clk);
                if(!ready || image_index!=0 || dut.resident[3])
                    fail("old frame lost before valid replacement finished");
            end
            wait(image_index==4);museum_frames(3);
            if(loader_error!=0 || !ready || dut.resident[3] || !dut.failed_images[3])
                fail("bad image skip did not recover the real FAT/cache pipeline");
            $display("PASS: corrupt replacement rejected, old frame protected, next good image loaded without remount or underflow");
        end
        if(acr_n!=6144||acr_cts!=25000)fail("wrong ACR constants");
        if(FIXED_RATE_AXIS)
            $display("PASS: %0d complete fixed-rate vendor HDMI frames checked pixel-by-pixel, manual wrap, atomic frame switch",good_frames);
        else
            $display("PASS: %0d complete frames checked pixel-by-pixel, manual wrap, atomic frame switch, AXI backpressure, zero under/overflow",good_frames);
        $display("TEST_PASS tb_media_player eight images %0dx%0d sectors=%0d",WIDTH,HEIGHT,read_sectors);
        $finish;
    end
    initial begin
        repeat(WIDTH>=640 ? 100000000 : 60000000)@(posedge sys_clk);
        $display("integration timeout t=%0t loader=%0d cache=%0d ready=%b image=%0d requested=%0d resident=%b frames=%0d reads=%0d writes=%0d",
            $time,dut.loader.state,dut.cache.state,ready,image_index,dut.desired_image,dut.resident,
            good_frames,read_sectors,write_count);
        $display("frame counts: %0d %0d %0d %0d %0d %0d %0d %0d; display=%b h=%0d v=%0d line_req=%b line_ack=%b",
            frames_per_image[0],frames_per_image[1],frames_per_image[2],frames_per_image[3],
            frames_per_image[4],frames_per_image[5],frames_per_image[6],frames_per_image[7],
            dut.video.display_enabled,dut.video.h,dut.video.v,dut.line_req,dut.line_ack);
        fail("integration timeout");
    end
endmodule

module tb_cache_stress;
    tb_media_player #(.TEST_CACHE_STRESS(1),.TEST_ZOOM_RELOAD(1),.FIXED_RATE_AXIS(1)) test();
endmodule

module tb_media_audio_pipeline;
    tb_media_player #(.TEST_AUDIO(1),.FIXED_RATE_AXIS(1)) test();
endmodule

module tb_media_ima_pipeline;
    tb_media_player #(.TEST_AUDIO(1),.TEST_IMA(1),.FIXED_RATE_AXIS(1)) test();
endmodule

module tb_media_sentence_resume;
    tb_media_player #(.TEST_AUDIO(1),.TEST_IMA(1),.TEST_RESUME(1),.FIXED_RATE_AXIS(1)) test();
endmodule

module tb_media_strict_chain;
    tb_media_player #(.TEST_AUDIO(1),.STRICT_CHAIN(1),.FIXED_RATE_AXIS(1)) test();
endmodule
