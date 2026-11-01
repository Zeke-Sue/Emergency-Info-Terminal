`timescale 1ns/1ps

module fat32_file_reader #(
    parameter integer IO_TIMEOUT = 25000000,
    parameter integer INIT_TIMEOUT = 500000000,
    parameter integer CACHE_BMP = 1,
    parameter integer CACHE_WAV = 1,
    parameter integer CACHE_CONFIG = 1,
    parameter integer PHYSICAL_HOLD_BUFFERS = 0,
    parameter integer MAX_BMP_FILES = 16,
    parameter integer MAX_WAV_FILES = 16,

    parameter integer CATALOG_NAME_CHARS = 32,
    parameter integer FIXED_PLAYLIST = 0,
    parameter integer FIXED_WAV_FILES = 12,
    parameter integer HASH_NAMES = 1,
    parameter integer STRICT_CHAIN = 0,
    parameter integer MAX_SECTOR_RETRIES = 3
)(
    input wire clk,
    input wire rst,
    input wire start_ready,
    input wire sd_ready,

    output wire sector_req,
    output wire [31:0] sector_lba,
    input wire [7:0] sector_data,
    input wire sector_valid,
    input wire sector_end,

    input wire open_req,
    input wire abort_file,

    input wire [1:0] open_type,
    input wire [5:0] file_index,
    output reg open_done,
    output reg open_not_found,
    output reg [31:0] file_size,
    output wire [7:0] file_data,
    output wire file_valid,
    input wire file_ready,
    output reg file_end,
    output wire mounted,
    output wire [5:0] catalog_file_count,
    output reg [4:0] bmp_file_count,
    output reg [4:0] wav_file_count,
    output reg config_found,
    output wire [7:0] catalog_malformed_count,
    output wire catalog_overflow,
    output reg [3:0] error_code,
    output wire media_entry_valid,media_entry_wav,media_entry_long,
    output wire [4:0] media_entry_ordinal,
    output wire [31:0] media_entry_hash,
    output wire [7:0] media_entry_length
);
    localparam [4:0] WAIT_INIT=0, REQUEST=1, RECEIVE=2, COMPLETE=3,
        WAIT_OPEN=4, STREAM=5, FAILED=6, MOUNT_SUM=7, STREAM_PRIME=8,
        CATALOG_BEGIN=9, CATALOG_PRIME=10, CATALOG_STREAM=11,
        CATALOG_NEXT=12, CATALOG_WAIT=13, OPEN_META=14,
        CHECK_FILE=15, RETRY_GAP=16, MOUNT_LIMIT=17;
    localparam [2:0] READ_SECTOR0=0, READ_BOOT=1,
        READ_FILE=4, READ_FAT_FILE=5,
        READ_CATALOG=6, READ_FAT_CATALOG=7;

    reg [4:0] state;
    reg reader_req;
    reg [31:0] reader_lba;
    reg chain_start;
    wire chain_req,chain_done,chain_valid;
    wire [31:0] chain_lba;
    wire [3:0] chain_error;
    reg [2:0] sector_retries;
    reg [31:0] directory_anchor;
    reg [20:0] directory_power;
    reg [19:0] directory_distance,directory_steps;
    reg [2:0] read_kind;
    reg [9:0] rx_count;
    reg [8:0] stream_index;
    reg [8:0] catalog_stream_index;
    localparam integer WATCHDOG_LIMIT=INIT_TIMEOUT>IO_TIMEOUT ? INIT_TIMEOUT : IO_TIMEOUT;
    localparam integer WATCHDOG_BITS=WATCHDOG_LIMIT>1 ? $clog2(WATCHDOG_LIMIT) : 1;
    reg [WATCHDOG_BITS-1:0] watchdog;
    reg mount_ok;

    reg [15:0] boot_signature;
    reg [15:0] bytes_per_sector;
    reg [7:0] sectors_per_cluster;
    reg [15:0] reserved_sectors;
    reg [7:0] number_of_fats;
    reg [15:0] root_entry_count;
    reg [15:0] fat16_size;
    reg [31:0] fat32_size;
    reg [31:0] root_cluster;
    reg [7:0] mbr_partition_type;
    reg [31:0] mbr_partition_lba;
    reg [31:0] partition_lba;
    reg [31:0] fat_lba;
    reg [31:0] data_lba;
    reg [31:0] fat_span, fat_addend;
    reg [7:0] fat_multiplier;
    reg [3:0] fat_bit;
    reg [2:0] cluster_shift;

    reg [5:0] requested_index;
    reg [31:0] current_cluster;
    reg [7:0] sector_in_cluster;
    reg [8:0] fat_byte_offset;
    reg [31:0] fat_value;
    reg [31:0] file_pos;

    reg catalog_scan_start,catalog_scan_finish;
    wire catalog_byte_ready,catalog_item_valid,catalog_long_name;
    wire [1:0] catalog_item_type;
    wire [5:0] catalog_item_index;
    wire [31:0] catalog_name_hash,catalog_start_cluster,catalog_item_size;
    wire [7:0] catalog_name_length,catalog_attributes;
    wire catalog_scan_complete;

    reg catalog_finished;
    wire catalog_complete=catalog_scan_complete||catalog_finished;
    always @(posedge clk or posedge rst)
        if(rst)catalog_finished<=0;
        else if(catalog_scan_start)catalog_finished<=0;
        else if(catalog_scan_complete)catalog_finished<=1;
    assign media_entry_valid=catalog_item_valid &&
        (catalog_item_type==1 || catalog_item_type==2);
    assign media_entry_wav=catalog_item_type==2;
    assign media_entry_long=catalog_long_name;
    assign media_entry_ordinal=catalog_item_type==2 ? wav_file_count : bmp_file_count;
    assign media_entry_hash=catalog_name_hash;
    assign media_entry_length=catalog_name_length;
    wire [5:0] catalog_count;
    wire bmp_meta_we=catalog_item_valid&&CACHE_BMP!=0&&
        catalog_item_type==2'd1&&bmp_file_count<MAX_BMP_FILES;
    wire wav_meta_we=catalog_item_valid&&CACHE_WAV!=0&&
        catalog_item_type==2'd2&&wav_file_count<MAX_WAV_FILES;
    reg [1:0] pending_open_type;

    wire metadata_we=bmp_meta_we||wav_meta_we;
    wire [4:0] metadata_write_address=bmp_meta_we ?
        {1'b0,bmp_file_count[3:0]} : {1'b1,wav_file_count[3:0]};
    reg [6:0] metadata_wa;
    reg [63:0] metadata_shift;
    reg [2:0] metadata_write_left,metadata_read_step;
    reg [31:0] metadata_cluster,metadata_size;
    wire [15:0] metadata_q;
    wire [6:0] metadata_ra={pending_open_type==2'd2,requested_index[3:0],
        metadata_read_step[1:0]};
    buffer_ram #(.DATA_WIDTH(16),.ADDR_WIDTH(7)) metadata_memory(
        .clk(clk),.we(metadata_write_left!=0),.wa(metadata_wa),
        .ra(metadata_ra),.d(metadata_shift[15:0]),.q(metadata_q));
    always @(posedge clk or posedge rst)begin
        if(rst)begin
            metadata_wa<=0;metadata_shift<=0;metadata_write_left<=0;
            metadata_read_step<=0;metadata_cluster<=0;metadata_size<=0;
        end else begin
            if(metadata_we)begin
                metadata_wa<={metadata_write_address,2'd0};
                metadata_shift<={catalog_item_size,catalog_start_cluster};
                metadata_write_left<=4;
            end else if(metadata_write_left!=0)begin
                metadata_wa<=metadata_wa+1'b1;metadata_shift<=metadata_shift>>16;
                metadata_write_left<=metadata_write_left-1'b1;
            end
            if(state!=OPEN_META||metadata_write_left!=0)metadata_read_step<=0;
            else if(metadata_read_step<5)begin
                metadata_read_step<=metadata_read_step+1'b1;
                case(metadata_read_step)
                    1:metadata_cluster[15:0]<=metadata_q;
                    2:metadata_cluster[31:16]<=metadata_q;
                    3:metadata_size[15:0]<=metadata_q;
                    4:metadata_size[31:16]<=metadata_q;
                endcase
            end
        end
    end
    reg [31:0] config_cluster,config_size;
    wire checking=state==CHECK_FILE;
    assign sector_req=checking ? chain_req : reader_req;
    assign sector_lba=checking ? chain_lba : reader_lba;
    fat32_chain_preflight #(.IO_TIMEOUT(IO_TIMEOUT),.MAX_RETRIES(MAX_SECTOR_RETRIES)) chain_check(
        .clk(clk),.rst(rst),.start(chain_start),.first_cluster(current_cluster),
        .file_size(file_size),.fat_lba(fat_lba),.fat_sectors(fat32_size),
        .data_lba(data_lba),.cluster_shift(cluster_shift),
        .sector_req(chain_req),.sector_lba(chain_lba),.sector_data(sector_data),
        .sector_valid(sector_valid&&checking),.sector_end(sector_end&&checking),
        .busy(),.done(chain_done),.valid(chain_valid),.error_code(chain_error));

    wire [31:0] next_cluster = fat_value & 32'h0fff_ffff;
    wire [31:0] root_cluster_handoff,next_cluster_handoff;
    wire [4:0] wav_count_handoff;
    generate if(PHYSICAL_HOLD_BUFFERS)begin: short_paths
        physical_hold_buffer #(.WIDTH(32)) root_hold(.d(root_cluster),.q(root_cluster_handoff));
        physical_hold_buffer #(.WIDTH(32)) next_hold(.d(next_cluster),.q(next_cluster_handoff));
        physical_hold_buffer #(.WIDTH(5)) count_hold(.d(wav_file_count),.q(wav_count_handoff));
    end else begin: direct_paths
        assign root_cluster_handoff=root_cluster;
        assign next_cluster_handoff=next_cluster;
        assign wav_count_handoff=wav_file_count;
    end endgenerate
    wire boot_fields_valid = boot_signature==16'haa55 &&
        bytes_per_sector==16'd512 && sectors_per_cluster!=0 &&
        ((sectors_per_cluster & (sectors_per_cluster-1'b1))==0) &&
        reserved_sectors!=0 && number_of_fats!=0 &&
        root_entry_count==0 && fat16_size==0 && fat32_size!=0 && fat32_size<=32'h00200000 &&
        root_cluster>=2&&root_cluster<32'h0ffffff0&&(root_cluster>>7)<fat32_size;
    wire mbr_partition_valid = mbr_partition_type==8'h0b ||
        mbr_partition_type==8'h0c || mbr_partition_type==8'h1b ||
        mbr_partition_type==8'h1c;

    wire catalog_streaming=state==CATALOG_PRIME||state==CATALOG_STREAM;
    wire [8:0] buffer_ra=catalog_streaming ?
        (state==CATALOG_STREAM&&catalog_byte_ready ?
            catalog_stream_index+1'b1 : catalog_stream_index) :
        ((state==STREAM && file_ready) ? stream_index+1'b1 : stream_index);
    buffer_ram sector_memory(.clk(clk),
        .we(state==RECEIVE && sector_valid && rx_count<512),
        .wa(rx_count[8:0]),.ra(buffer_ra),.d(sector_data),.q(file_data));
    assign file_valid = state==STREAM;
    assign mounted = mount_ok && state!=FAILED;
    assign catalog_file_count=catalog_count;

    fat32_sorted_catalog #(.MAX_FILES(32),.NAME_CHARS(CATALOG_NAME_CHARS),.FIXED_NAMES(FIXED_PLAYLIST),.FIXED_WAV_FILES(FIXED_WAV_FILES),.HASH_NAMES(HASH_NAMES)) root_catalog(
        .clk(clk),.rst(rst),.scan_start(catalog_scan_start),
        .byte_valid(state==CATALOG_STREAM),.byte_data(file_data),
        .byte_ready(catalog_byte_ready),.scan_finish(catalog_scan_finish),
        .catalog_valid(catalog_item_valid),.catalog_type(catalog_item_type),
        .catalog_index(catalog_item_index),.long_name(catalog_long_name),
        .name_hash(catalog_name_hash),.name_length(catalog_name_length),
        .start_cluster(catalog_start_cluster),.file_size(catalog_item_size),
        .attributes(catalog_attributes),.scan_complete(catalog_scan_complete),
        .file_count(catalog_count),.malformed_count(catalog_malformed_count),
        .overflow(catalog_overflow));

    wire [31:0] address_cluster=state==CATALOG_BEGIN ? root_cluster :
        state==WAIT_OPEN ? config_cluster :
        state==OPEN_META ? metadata_cluster : next_cluster;
    wire advance_sector=state==CATALOG_NEXT||state==STREAM;
    wire inside_cluster=sector_in_cluster+1'b1<sectors_per_cluster;
    wire [31:0] sector_base=advance_sector ?
        (inside_cluster ? reader_lba : fat_lba) : data_lba;
    wire [31:0] sector_offset=advance_sector ?
        (inside_cluster ? 32'd1 : current_cluster>>7) :
        ((address_cluster-32'd2)<<cluster_shift);
    wire [31:0] computed_sector_lba=sector_base+sector_offset;
    wire [32:0] mounted_fat_base={1'b0,partition_lba}+reserved_sectors;
    wire [32:0] mounted_data_base={1'b0,data_lba}+fat_span;

    wire [32:0] available_clusters=(33'h100000000-{1'b0,data_lba})>>cluster_shift;
    reg [28:0] address_cluster_limit;
    wire cluster_address_overflow=address_cluster>address_cluster_limit;
    wire open_cluster_valid=address_cluster>=2&&address_cluster<32'h0ffffff0&&
        (address_cluster>>7)<fat32_size&&!cluster_address_overflow;

    always @(posedge clk)begin
        case(state)
            WAIT_INIT:reader_lba<=0;
            COMPLETE:begin
                if(read_kind==READ_SECTOR0&&!boot_fields_valid&&
                        boot_signature==16'haa55&&mbr_partition_valid&&mbr_partition_lba!=0)
                    reader_lba<=mbr_partition_lba;
                else if(read_kind==READ_FAT_FILE||read_kind==READ_FAT_CATALOG)
                    reader_lba<=computed_sector_lba;
            end
            CATALOG_BEGIN:reader_lba<=computed_sector_lba;
            CATALOG_NEXT:if(!catalog_complete)reader_lba<=computed_sector_lba;
            WAIT_OPEN:if(open_req&&open_type==3&&config_found&&config_cluster>=2&&config_size!=0)
                reader_lba<=computed_sector_lba;
            OPEN_META:if(metadata_read_step==5)reader_lba<=computed_sector_lba;
            STREAM:begin
                if(abort_file)reader_lba<=reader_lba;
                else if(file_ready&&file_pos+1'b1<file_size&&stream_index==511)
                    reader_lba<=computed_sector_lba;
            end
        endcase
    end

    task clear_boot_fields;
        begin
            boot_signature <= 0;
            bytes_per_sector <= 0;
            sectors_per_cluster <= 0;
            reserved_sectors <= 0;
            number_of_fats <= 0;
            root_entry_count <= 0;
            fat16_size <= 0;
            fat32_size <= 0;
            root_cluster <= 0;
        end
    endtask

    task fail_with;
        input [3:0] code;
        begin
            error_code <= code;
            reader_req <= 0;

            if(mount_ok && code!=4 && (read_kind==READ_FILE || read_kind==READ_FAT_FILE))begin
                file_end<=1;
                state<=WAIT_OPEN;
            end else state <= FAILED;
        end
    endtask

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= WAIT_INIT;
            read_kind <= READ_SECTOR0;
            reader_req <= 0;
            chain_start<=0;sector_retries<=0;
            directory_anchor<=0;directory_power<=1;directory_distance<=0;directory_steps<=0;
            rx_count <= 0;
            stream_index <= 0;
            catalog_stream_index <= 0;
            watchdog <= 0;
            mount_ok <= 0;
            open_done <= 0;
            open_not_found <= 0;
            file_size <= 0;
            file_end <= 0;
            error_code <= 0;
            boot_signature <= 0;
            bytes_per_sector <= 0;
            sectors_per_cluster <= 0;
            reserved_sectors <= 0;
            number_of_fats <= 0;
            root_entry_count <= 0;
            fat16_size <= 0;
            fat32_size <= 0;
            root_cluster <= 0;
            mbr_partition_type <= 0;
            mbr_partition_lba <= 0;
            partition_lba <= 0;
            fat_lba <= 0;
            data_lba <= 0;
            address_cluster_limit<=0;
            fat_span<=0;fat_addend<=0;fat_multiplier<=0;fat_bit<=0;cluster_shift<=0;
            requested_index <= 0;
            pending_open_type<=0;
            current_cluster <= 0;
            sector_in_cluster <= 0;
            fat_byte_offset <= 0;
            fat_value <= 0;
            file_pos <= 0;
            catalog_scan_start<=0;
            catalog_scan_finish<=0;
            bmp_file_count<=0;
            wav_file_count<=0;
            config_found<=0;
            config_cluster<=0;
            config_size<=0;
        end else begin
            open_done <= 0;
            open_not_found <= 0;
            catalog_scan_start<=0;
            catalog_scan_finish<=0;
            chain_start<=0;
            if(catalog_item_valid)begin
                if(CACHE_BMP!=0&&catalog_item_type==2'd1&&
                        bmp_file_count<MAX_BMP_FILES)begin
                    bmp_file_count<=bmp_file_count+1'b1;
                end else if(CACHE_WAV!=0&&catalog_item_type==2'd2&&
                        wav_file_count<MAX_WAV_FILES)begin
                    wav_file_count<=wav_count_handoff+1'b1;
                end else if(CACHE_CONFIG&&catalog_item_type==2'd3&&!config_found)begin
                    config_found<=1;
                    config_cluster<=catalog_start_cluster;
                    config_size<=catalog_item_size;
                end
            end
            case (state)
                WAIT_INIT: begin
                    if (start_ready && sd_ready) begin
                        read_kind <= READ_SECTOR0;
                        mbr_partition_type <= 0;
                        mbr_partition_lba <= 0;
                        clear_boot_fields;
                        watchdog <= 0;
                        state <= REQUEST;
                    end else if (watchdog==INIT_TIMEOUT-1) fail_with(1);
                    else watchdog <= watchdog+1'b1;
                end

                REQUEST: begin
                    reader_req <= 1;
                    rx_count <= 0;
                    watchdog <= 0;
                    if (read_kind==READ_FAT_FILE ||
                            read_kind==READ_FAT_CATALOG)
                        fat_value <= 0;
                    state <= RECEIVE;
                end

                RECEIVE: begin
                    watchdog <= watchdog+1'b1;
                    if (sector_valid) begin
                        if(rx_count<513)rx_count <= rx_count+1'b1;

                        if (read_kind==READ_SECTOR0 || read_kind==READ_BOOT) begin
                            case (rx_count)
                                11: bytes_per_sector[7:0] <= sector_data;
                                12: bytes_per_sector[15:8] <= sector_data;
                                13: sectors_per_cluster <= sector_data;
                                14: reserved_sectors[7:0] <= sector_data;
                                15: reserved_sectors[15:8] <= sector_data;
                                16: number_of_fats <= sector_data;
                                17: root_entry_count[7:0] <= sector_data;
                                18: root_entry_count[15:8] <= sector_data;
                                22: fat16_size[7:0] <= sector_data;
                                23: fat16_size[15:8] <= sector_data;
                                36,37,38,39: fat32_size <= {sector_data,fat32_size[31:8]};
                                44,45,46,47: root_cluster <= {sector_data,root_cluster[31:8]};
                                510: boot_signature[7:0] <= sector_data;
                                511: boot_signature[15:8] <= sector_data;
                            endcase
                            if (read_kind==READ_SECTOR0) begin
                                case (rx_count)
                                    450: mbr_partition_type <= sector_data;
                                    454,455,456,457:
                                        mbr_partition_lba <= {sector_data,mbr_partition_lba[31:8]};
                                endcase
                            end
                        end else if (read_kind==READ_FAT_FILE ||
                                read_kind==READ_FAT_CATALOG) begin
                            if (rx_count==fat_byte_offset)
                                fat_value[7:0] <= sector_data;
                            else if (rx_count==fat_byte_offset+1'b1)
                                fat_value[15:8] <= sector_data;
                            else if (rx_count==fat_byte_offset+2'd2)
                                fat_value[23:16] <= sector_data;
                            else if (rx_count==fat_byte_offset+2'd3)
                                fat_value[31:24] <= sector_data;
                        end
                    end

                    if (sector_end) begin
                        reader_req <= 0;
                        if ((rx_count+(sector_valid ? 10'd1 : 10'd0))!=512)begin
                            if(sector_retries==MAX_SECTOR_RETRIES)begin sector_retries<=0;fail_with(5);end
                            else begin
                                sector_retries<=sector_retries+1'b1;state<=RETRY_GAP;
                                if(read_kind==READ_SECTOR0||read_kind==READ_BOOT)clear_boot_fields;
                            end
                        end else begin sector_retries<=0;state <= COMPLETE;end
                    end else if (watchdog==IO_TIMEOUT-1) fail_with(4);
                end

                COMPLETE: begin
                    case (read_kind)
                        READ_SECTOR0: begin
                            if (boot_fields_valid) begin
                                partition_lba <= 0;
                                fat_lba <= reserved_sectors;
                                data_lba <= reserved_sectors;
                                fat_span<=0;fat_addend<=fat32_size;
                                fat_multiplier<=number_of_fats;fat_bit<=0;
                                state <= MOUNT_SUM;
                            end else if (boot_signature==16'haa55 &&
                                         mbr_partition_valid && mbr_partition_lba!=0) begin
                                partition_lba <= mbr_partition_lba;
                                read_kind <= READ_BOOT;
                                clear_boot_fields;
                                state <= REQUEST;
                            end else fail_with(2);
                        end
                        READ_BOOT: begin
                            if (boot_fields_valid&&!mounted_fat_base[32]) begin
                                fat_lba <= partition_lba+reserved_sectors;
                                data_lba <= partition_lba+reserved_sectors;
                                fat_span<=0;fat_addend<=fat32_size;
                                fat_multiplier<=number_of_fats;fat_bit<=0;
                                state <= MOUNT_SUM;
                            end else fail_with(2);
                        end
                        READ_FILE: begin
                            stream_index <= 0;

                            open_done <= file_pos==0;
                            state <= STREAM_PRIME;
                        end
                        READ_FAT_FILE: begin
                            if (next_cluster>=32'h0fff_fff0 || next_cluster<2 ||
                                (next_cluster>>7)>=fat32_size||cluster_address_overflow) fail_with(6);
                            else begin
                                current_cluster <= next_cluster_handoff;
                                sector_in_cluster <= 0;
                                read_kind <= READ_FILE;
                                state <= REQUEST;
                            end
                        end
                        READ_CATALOG: begin
                            catalog_stream_index<=0;
                            state<=CATALOG_PRIME;
                        end
                        READ_FAT_CATALOG: begin
                            if(next_cluster>=32'h0fff_fff8)begin
                                catalog_scan_finish<=1;
                                state<=CATALOG_WAIT;
                            end else if(next_cluster<2||next_cluster>=32'h0fff_fff0||
                                (next_cluster>>7)>=fat32_size||cluster_address_overflow)
                                fail_with(6);
                            else if(next_cluster==directory_anchor||directory_steps==1048575)
                                fail_with(7);
                            else begin
                                directory_steps<=directory_steps+1'b1;
                                if(directory_distance+1'b1==directory_power)begin
                                    directory_anchor<=next_cluster_handoff;directory_power<=directory_power<<1;
                                    directory_distance<=0;
                                end else directory_distance<=directory_distance+1'b1;
                                current_cluster<=next_cluster_handoff;
                                sector_in_cluster<=0;
                                read_kind<=READ_CATALOG;
                                state<=REQUEST;
                            end
                        end
                        default: fail_with(15);
                    endcase
                end

                MOUNT_SUM: begin
                    if(fat_bit==8)begin
                        if(mounted_data_base[32])fail_with(2);
                        else begin data_lba<=mounted_data_base[31:0];state<=MOUNT_LIMIT;end
                        case(sectors_per_cluster)
                            1:cluster_shift<=0;2:cluster_shift<=1;4:cluster_shift<=2;
                            8:cluster_shift<=3;16:cluster_shift<=4;32:cluster_shift<=5;
                            64:cluster_shift<=6;default:cluster_shift<=7;
                        endcase
                    end else begin
                        if(fat_multiplier[0])fat_span<=fat_span+fat_addend;
                        fat_addend<=fat_addend<<1;fat_multiplier<=fat_multiplier>>1;
                        fat_bit<=fat_bit+1'b1;
                    end
                end
                MOUNT_LIMIT:begin
                    address_cluster_limit<=|available_clusters[32:28] ?
                        29'h10000000 : {1'b0,available_clusters[27:0]}+1'b1;
                    state<=CATALOG_BEGIN;
                end
                CATALOG_BEGIN: begin
                    if(cluster_address_overflow)fail_with(6);
                    else begin
                    catalog_scan_start<=1;
                    bmp_file_count<=0;
                    wav_file_count<=0;
                    config_found<=0;
                    current_cluster<=root_cluster;
                    directory_anchor<=root_cluster_handoff;directory_power<=1;directory_distance<=0;directory_steps<=0;
                    sector_in_cluster<=0;
                    read_kind<=READ_CATALOG;
                    state<=REQUEST;
                    end
                end
                CATALOG_PRIME: begin
                    catalog_stream_index<=0;
                    state<=CATALOG_STREAM;
                end
                CATALOG_STREAM: begin
                    if(catalog_complete)begin
                        mount_ok<=1;
                        state<=WAIT_OPEN;
                    end else if(catalog_byte_ready)begin
                        if(catalog_stream_index==511)state<=CATALOG_NEXT;
                        else catalog_stream_index<=catalog_stream_index+1'b1;
                    end
                end
                CATALOG_NEXT: begin
                    if(catalog_complete)begin
                        mount_ok<=1;
                        state<=WAIT_OPEN;
                    end else if(sector_in_cluster+1'b1<sectors_per_cluster)begin
                        sector_in_cluster<=sector_in_cluster+1'b1;
                        read_kind<=READ_CATALOG;
                        state<=REQUEST;
                    end else begin
                        fat_byte_offset<={current_cluster[6:0],2'b00};
                        read_kind<=READ_FAT_CATALOG;
                        state<=REQUEST;
                    end
                end
                CATALOG_WAIT: begin
                    if(catalog_complete)begin
                        mount_ok<=1;
                        state<=WAIT_OPEN;
                    end
                end
                STREAM_PRIME: state<=STREAM;
                WAIT_OPEN: begin
                    reader_req <= 0;
                    if (open_req) begin
                        error_code<=0;
                        requested_index <= file_index;
                        sector_in_cluster <= 0;
                        file_end <= 0;
                        file_pos<=0;
                        if(open_type==2'd3)begin
                            if(CACHE_CONFIG&&config_found&&open_cluster_valid&&config_size!=0)begin
                                current_cluster<=config_cluster;
                                file_size<=config_size;
                                read_kind<=READ_FILE;
                                chain_start<=STRICT_CHAIN!=0;
                                state<=STRICT_CHAIN ? CHECK_FILE : REQUEST;
                            end else open_not_found<=1;
                        end else if(open_type==2'd2)begin
                            if(CACHE_WAV!=0&&file_index<MAX_WAV_FILES&&
                                    file_index<wav_file_count)begin
                                pending_open_type<=2'd2;state<=OPEN_META;
                            end else open_not_found<=1;
                        end else begin
                            if(CACHE_BMP!=0&&file_index<MAX_BMP_FILES&&
                                    file_index<bmp_file_count)begin
                                pending_open_type<=2'd1;state<=OPEN_META;
                            end else open_not_found<=1;
                        end
                    end
                end

                OPEN_META: if(metadata_read_step==5)begin
                    if(pending_open_type==2'd2)begin
                        if(open_cluster_valid&&metadata_size!=0)begin
                            current_cluster<=metadata_cluster;
                            file_size<=metadata_size;
                            read_kind<=READ_FILE;chain_start<=STRICT_CHAIN!=0;
                            state<=STRICT_CHAIN ? CHECK_FILE : REQUEST;
                        end else begin open_not_found<=1;state<=WAIT_OPEN;end
                    end else begin
                        if(open_cluster_valid&&metadata_size>=54)begin
                            current_cluster<=metadata_cluster;
                            file_size<=metadata_size;
                            read_kind<=READ_FILE;chain_start<=STRICT_CHAIN!=0;
                            state<=STRICT_CHAIN ? CHECK_FILE : REQUEST;
                        end else begin open_not_found<=1;state<=WAIT_OPEN;end
                    end
                end

                STREAM: begin

                    if(abort_file)begin
                        file_end<=1;state<=WAIT_OPEN;
                    end else if (file_ready) begin
                        if (file_pos+1'b1>=file_size) begin
                            file_pos <= file_pos+1'b1;
                            file_end <= 1;
                            state <= WAIT_OPEN;
                        end else if (stream_index==511) begin
                            file_pos <= file_pos+1'b1;
                            if (sector_in_cluster+1'b1<sectors_per_cluster) begin
                                sector_in_cluster <= sector_in_cluster+1'b1;
                                read_kind <= READ_FILE;
                                state <= REQUEST;
                            end else begin
                                fat_byte_offset <= {current_cluster[6:0],2'b00};
                                read_kind <= READ_FAT_FILE;
                                state <= REQUEST;
                            end
                        end else begin
                            stream_index <= stream_index+1'b1;
                            file_pos <= file_pos+1'b1;
                        end
                    end
                end

                CHECK_FILE:if(chain_done)begin
                    if(chain_valid)state<=REQUEST;
                    else fail_with(chain_error);
                end
                RETRY_GAP:state<=REQUEST;
                FAILED: begin
                    reader_req <= 0;
                end
                default: fail_with(15);
            endcase
        end
    end
endmodule
