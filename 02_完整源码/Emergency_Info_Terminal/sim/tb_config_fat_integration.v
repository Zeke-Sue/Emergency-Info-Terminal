`timescale 1ns/1ps
module tb_config_fat_integration;
    reg sys_clk=0,pixel_clk=0,rst=1,open_req=0;
    always #4 sys_clk=~sys_clk;always #10 pixel_clk=~pixel_clk;
    wire sector_req,sector_valid,sector_end,mounted,open_done,open_not_found;
    wire [31:0] sector_lba,file_size;wire [7:0] sector_data,file_data;
    wire file_valid,file_ready,file_end;wire [3:0] fat_error;
    wire [5:0] catalog_count;wire [4:0] bmp_count,wav_count;
    wire config_found;wire [7:0] malformed;wire overflow;
    fat32_file_reader #(.IO_TIMEOUT(10000),.INIT_TIMEOUT(10000)) reader(
        .clk(sys_clk),.rst(rst),.start_ready(!rst),.sd_ready(!rst),
        .sector_req(sector_req),.sector_lba(sector_lba),
        .sector_data(sector_data),.sector_valid(sector_valid),.sector_end(sector_end),
        .open_req(open_req),.open_type(2'd3),.file_index(6'd0),
        .open_done(open_done),.open_not_found(open_not_found),.file_size(file_size),
        .file_data(file_data),.file_valid(file_valid),.file_ready(file_ready),
        .file_end(file_end),.mounted(mounted),.catalog_file_count(catalog_count),
        .bmp_file_count(bmp_count),.wav_file_count(wav_count),
        .config_found(config_found),.catalog_malformed_count(malformed),
        .catalog_overflow(overflow),.error_code(fat_error));

    wire cfg_write,cfg_commit,cfg_crc_ok,cfg_checked,cfg_assets,config_done,cfg_ready;
    wire [7:0] cfg_key;wire [31:0] cfg_segments,cfg_directions,cfg_crc;
    wire [2:0] cfg_exit;wire [1:0] cfg_status;wire [15:0] cfg_version;
    wire config_valid;wire [3:0] config_error;
    config_route_stream_parser parser(.clk(sys_clk),.rst(rst),
        .file_start(open_done),.byte_valid(file_valid),.byte_data(file_data),
        .byte_ready(file_ready),.cfg_ready(cfg_ready),.file_end(file_end),
        .cfg_write(cfg_write),
        .cfg_blocked_key(cfg_key),.cfg_segment_mask(cfg_segments),
        .cfg_direction_mask(cfg_directions),.cfg_exit(cfg_exit),
        .cfg_status(cfg_status),.cfg_commit(cfg_commit),.cfg_crc_ok(cfg_crc_ok),
        .cfg_checked(cfg_checked),.cfg_assets_match(cfg_assets),
        .cfg_version(cfg_version),.cfg_crc32(cfg_crc),.done(config_done),
        .valid(config_valid),.error_reason(config_error));

    wire route_write,route_commit,route_crc_ok,route_checked,route_assets;
    wire [7:0] route_key;wire [31:0] route_segments,route_directions,route_crc;
    wire [2:0] route_exit;wire [1:0] route_status;wire [15:0] route_version;
    wire cdc_overflow;
    route_config_cdc cdc(.src_clk(sys_clk),.src_rst(rst),
        .src_write(cfg_write),.src_key(cfg_key),.src_segments(cfg_segments),
        .src_directions(cfg_directions),.src_exit(cfg_exit),.src_status(cfg_status),
        .src_commit(cfg_commit),.src_crc_ok(cfg_crc_ok),.src_checked(cfg_checked),
        .src_assets_match(cfg_assets),.src_version(cfg_version),.src_crc32(cfg_crc),
        .src_ready(cfg_ready),.src_overflow(cdc_overflow),
        .dst_clk(pixel_clk),.dst_rst(rst),
        .dst_write(route_write),.dst_key(route_key),.dst_segments(route_segments),
        .dst_directions(route_directions),.dst_exit(route_exit),
        .dst_status(route_status),.dst_commit(route_commit),
        .dst_crc_ok(route_crc_ok),.dst_checked(route_checked),
        .dst_assets_match(route_assets),.dst_version(route_version),
        .dst_crc32(route_crc));

    reg frame_tick=0;reg [7:0] blocked=0;
    wire route_valid,reachable,all_blocked,unreachable,overlay_valid,fallback,changed;
    wire [2:0] selected_exit;wire [1:0] selected_status;
    wire [31:0] selected_segments,selected_directions;wire [23:0] overlay_rgb;
    wire [15:0] active_version;wire [31:0] active_crc;
    n10_route_engine routes(.clk(pixel_clk),.rst(rst),.frame_tick(frame_tick),
        .cfg_write(route_write),.cfg_blocked_key(route_key),
        .cfg_segment_mask(route_segments),.cfg_direction_mask(route_directions),
        .cfg_exit(route_exit),.cfg_status(route_status),.cfg_commit(route_commit),
        .cfg_crc_ok(route_crc_ok),.cfg_checked(route_checked),
        .cfg_assets_match(route_assets),.cfg_version(route_version),
        .cfg_crc32(route_crc),.blocked_set(blocked),.pixel_valid(1'b0),
        .segment_id(6'd0),.segment_phase(8'd0),.blocked_exit_pixel(1'b0),
        .flash_on(1'b0),.route_valid(route_valid),.route_reachable(reachable),
        .all_exits_blocked(all_blocked),.route_unreachable(unreachable),
        .selected_exit(selected_exit),.selected_status(selected_status),
        .selected_segment_mask(selected_segments),
        .selected_direction_mask(selected_directions),.overlay_valid(overlay_valid),
        .overlay_rgb(overlay_rgb),.safe_fallback(fallback),.route_changed(changed),
        .active_version(active_version),.active_crc32(active_crc));

    reg [7:0] config_bytes [0:2335];
    reg [31:0] payload_crc;integer i;
    function [31:0] crc32_byte;input [31:0] current;input [7:0] value;
        integer bit_index;reg [31:0] work;begin work=current^value;
        for(bit_index=0;bit_index<8;bit_index=bit_index+1)
            work=work[0]?(work>>1)^32'hedb88320:work>>1;
        crc32_byte=work;end endfunction
    function [7:0] card_byte;input integer lba,pos;integer offset,cluster,value;
        begin
            card_byte=0;
            if(lba==0)begin
                case(pos)
                    11:card_byte=0;12:card_byte=2;13:card_byte=1;
                    14:card_byte=1;16:card_byte=1;36:card_byte=1;
                    44:card_byte=2;510:card_byte=8'h55;511:card_byte=8'haa;
                endcase
            end else if(lba==1)begin
                cluster=pos>>2;
                if(cluster==2||cluster==7)value=32'h0fffffff;
                else if(cluster>=3&&cluster<7)value=cluster+1;
                else value=0;
                card_byte=value>>((pos&3)*8);
            end else if(lba==2)begin
                case(pos)
                    0:card_byte="C";1:card_byte="O";2:card_byte="N";
                    3:card_byte="F";4:card_byte="I";5:card_byte="G";
                    6,7:card_byte=" ";8:card_byte="B";9:card_byte="I";
                    10:card_byte="N";11:card_byte=8'h20;26:card_byte=3;
                    28:card_byte=8'h20;29:card_byte=8'h09;
                endcase
            end else if(lba>=3&&lba<=7)begin
                offset=(lba-3)*512+pos;
                if(offset<2336)card_byte=config_bytes[offset];
            end
        end
    endfunction
    reg sd_valid=0,sd_end=0;reg [7:0] sd_data=0;
    integer sd_state=0,sd_pos=0,sd_lba=0;
    assign sector_valid=sd_valid;assign sector_end=sd_end;assign sector_data=sd_data;
    always @(posedge sys_clk)begin
        sd_valid<=0;sd_end<=0;
        if(rst)sd_state<=0;
        else case(sd_state)
            0:if(sector_req)begin sd_lba<=sector_lba;sd_pos<=0;sd_state<=1;end
            1:begin sd_data<=card_byte(sd_lba,sd_pos);sd_valid<=1;
                if(sd_pos==511)sd_state<=2;else sd_pos<=sd_pos+1;end
            2:begin sd_end<=1;sd_state<=3;end
            3:if(!sector_req)sd_state<=0;
        endcase
    end
    task fail;input [8*100-1:0] msg;begin
        $display("TEST_FAIL tb_config_fat_integration: %0s",msg);$finish;end endtask
    task put16;input integer offset;input [15:0] value;begin
        config_bytes[offset]=value[7:0];config_bytes[offset+1]=value[15:8];end endtask
    task put32;input integer offset;input [31:0] value;begin
        config_bytes[offset]=value[7:0];config_bytes[offset+1]=value[15:8];
        config_bytes[offset+2]=value[23:16];config_bytes[offset+3]=value[31:24];end endtask
    initial begin
        for(i=0;i<2336;i=i+1)config_bytes[i]=0;
        for(i=0;i<256;i=i+1)begin
            put32(32+i*9,32'h00000001<<i[4:0]);
            put32(36+i*9,32'h80000000>>i[4:0]);
            config_bytes[40+i*9]={3'd0,(i==255?2'd1:2'd0),i[2:0]};
        end
        payload_crc=32'hffffffff;
        for(i=32;i<2336;i=i+1)payload_crc=crc32_byte(payload_crc,config_bytes[i]);
        payload_crc=~payload_crc;
        config_bytes[0]="E";config_bytes[1]="I";config_bytes[2]="T";config_bytes[3]="4";
        put16(4,16'h4101);put16(6,16'd32);put32(8,32'd2336);
        put32(12,payload_crc);put32(16,payload_crc);put32(20,32'hda11eb23);
        put32(24,32'd3);put32(28,32'd256);
        repeat(6)@(negedge sys_clk);rst=0;
        wait(mounted||fat_error!=0);
        if(fat_error||catalog_count!=1||!config_found||bmp_count||wav_count)
            fail("catalog mount or CONFIG classification");
        @(negedge sys_clk);open_req=1;@(negedge sys_clk);open_req=0;
        wait(config_done||fat_error!=0);
        if(fat_error||open_not_found||!config_valid||config_error||cdc_overflow)begin
            $display("DEBUG stream fat=%0d missing=%b valid=%b err=%0d overflow=%b records=%0d crc=%08x expected=%08x",
                fat_error,open_not_found,config_valid,config_error,cdc_overflow,
                parser.records_seen,cfg_crc,payload_crc);
            fail("CONFIG file stream or CRC validation");
        end
        wait(route_commit);repeat(3)@(negedge pixel_clk);
        frame_tick=1;@(negedge pixel_clk);frame_tick=0;
        repeat(3)@(posedge pixel_clk);#1;
        if(!route_valid||active_version!=16'h4101||active_crc!=payload_crc)
            fail("atomic route table commit");
        blocked=8'hff;repeat(2)@(posedge pixel_clk);#1;
        if(selected_status!=0||selected_segments!=1)fail("route changed inside frame");
        @(negedge pixel_clk);frame_tick=1;
        @(negedge pixel_clk);frame_tick=0;
        repeat(2)@(posedge pixel_clk);#1;
        if(!all_blocked||selected_status!=1||selected_exit!=7||
                selected_segments!=32'h80000000)
            fail("last route table entry");
        $display("TEST_PASS tb_config_fat_integration FAT catalog -> CONFIG CRC -> CDC -> atomic N10 bank");
        $finish;
    end
    initial begin #10000000;
        $display("DEBUG mounted=%b fat=%0d reader_state=%0d lba=%0d sd=%0d cfg_done=%b cfg_err=%0d records=%0d cdc_req=%b ack=%b commit=%b",
            mounted,fat_error,reader.state,sector_lba,sd_state,config_done,
            config_error,parser.records_seen,cdc.write_request,cdc.write_ack_sync[1],
            route_commit);
        fail("timeout");
    end
endmodule
