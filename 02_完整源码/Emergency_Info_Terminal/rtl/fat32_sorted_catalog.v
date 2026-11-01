`timescale 1ns/1ps

module fat32_sorted_catalog #(
    parameter integer MAX_FILES=32,
    parameter integer NAME_CHARS=256,
    parameter integer FIXED_NAMES=0,
    parameter integer FIXED_WAV_FILES=12,
    parameter integer HASH_NAMES=1
)(
    input wire clk,rst,scan_start,
    input wire byte_valid,input wire [7:0] byte_data,output wire byte_ready,
    input wire scan_finish,
    output reg catalog_valid,output reg [1:0] catalog_type,
    output reg [5:0] catalog_index,output reg long_name,
    output reg [31:0] name_hash,output reg [7:0] name_length,
    output reg [31:0] start_cluster,file_size,
    output reg [7:0] attributes,
    output reg scan_complete,output reg [5:0] file_count,
    output wire [7:0] malformed_count,output wire overflow
);
    localparam POS_BITS=$clog2(NAME_CHARS);
    localparam COMPACT_META=FIXED_NAMES&&!HASH_NAMES;
    localparam COLLECT=0,COPY_NAME=1,SELECT=2,SEARCH=3,READ_A=4,
        READ_B=5,COMPARE=6,EMIT=7,READ_META=8,FINISH=9;
    reg [3:0] state;
    wire raw_ready,raw_valid,raw_done,raw_long;
    wire [1:0] raw_type;
    wire [31:0] raw_hash,raw_cluster,raw_size;
    wire [7:0] raw_length,raw_attributes,raw_malformed;
    wire [NAME_CHARS*16-1:0] raw_name;
    wire [87:0] raw_short_name;
    reg [7:0] invalid_names;
    wire [4:0] decimal_id=(raw_short_name[47:40]=="1" ? 5'd10 : 5'd0)+
        (raw_short_name[39:32]-8'h30);
    wire digits_valid=(raw_short_name[47:40]=="0"||raw_short_name[47:40]=="1")&&
        raw_short_name[39:32]>="0"&&raw_short_name[39:32]<="9";
    wire fixed_bmp=raw_type==1&&raw_short_name[87:48]=="IMAGE"&&
        raw_short_name[31:0]==" BMP"&&digits_valid&&decimal_id>=1&&decimal_id<=16;
    wire fixed_wav=raw_type==2&&raw_short_name[87:48]=="AUDIO"&&
        raw_short_name[31:0]==" WAV"&&digits_valid&&decimal_id<FIXED_WAV_FILES;

    wire fixed_config=FIXED_WAV_FILES<16&&raw_type==3&&raw_short_name=="CONFIG  BIN";
    wire fixed_known=fixed_bmp||fixed_wav||fixed_config;
    wire [4:0] fixed_rank=fixed_bmp ? decimal_id-1'b1 : fixed_wav ? decimal_id+5'd16 : 16+FIXED_WAV_FILES;
    reg [POS_BITS-1:0] name_position,char_position;
    reg [5:0] entries,candidate;
    reg [4:0] copy_index,best;
    reg best_valid,finished_input;
    reg [31:0] used,duplicates;
    reg [7:0] duplicate_count;
    wire [15:0] name_q,meta_q;
    reg [15:0] char_a;
    reg [(COMPACT_META ? 80 : 128)-1:0] metadata_shift;
    reg [3:0] meta_step;
    wire [9:0] malformed_sum={2'd0,raw_malformed}+{2'd0,duplicate_count}+{2'd0,invalid_names};
    assign malformed_count=|malformed_sum[9:8] ? 8'hff : malformed_sum[7:0];
    assign byte_ready=state==COLLECT&&raw_ready&&!raw_valid;
    fat32_root_catalog #(.MAX_FILES(MAX_FILES),.STREAMING(FIXED_NAMES),.NAME_CHARS(NAME_CHARS),.ALLOW_LONG_NAMES(!FIXED_NAMES),.HASH_NAMES(HASH_NAMES)) scanner(.clk(clk),.rst(rst),.scan_start(scan_start),
        .byte_valid(byte_valid&&byte_ready),.byte_data(byte_data),.byte_ready(raw_ready),.scan_finish(scan_finish),
        .catalog_valid(raw_valid),.catalog_type(raw_type),.long_name(raw_long),
        .name_hash(raw_hash),.name_length(raw_length),.start_cluster(raw_cluster),.file_size(raw_size),
        .attributes(raw_attributes),.scan_complete(raw_done),.malformed_count(raw_malformed),
        .overflow(overflow),.normalized_name(raw_name),.short_name(raw_short_name));
    generate if(!FIXED_NAMES)begin: general_names
      buffer_ram #(.DATA_WIDTH(16),.ADDR_WIDTH(5+POS_BITS)) names(
        .clk(clk),.we(state==COPY_NAME),.wa({copy_index,name_position}),
        .ra({state==READ_A ? candidate[4:0] : best,char_position}),
        .d(raw_name[NAME_CHARS*16-1-name_position*16 -:16]),.q(name_q));
    end else begin: fixed_names
        assign name_q=0;
    end endgenerate
    wire [15:0] compare_a=char_a;
    wire [15:0] compare_b=name_q;
    buffer_ram #(.DATA_WIDTH(16),.ADDR_WIDTH(8)) metadata(
        .clk(clk),.we(state==COPY_NAME&&name_position<(COMPACT_META ? 5 : 8)),
        .wa({copy_index,name_position[2:0]}),.ra({best,meta_step[2:0]}),
        .d(metadata_shift[15:0]),.q(meta_q));
    always @(posedge clk or posedge rst)begin
        if(rst)begin
            state<=COLLECT;name_position<=0;char_position<=0;
            metadata_shift<=0;meta_step<=0;char_a<=0;
            entries<=0;candidate<=0;copy_index<=0;best<=0;best_valid<=0;finished_input<=0;
            used<=0;duplicates<=0;duplicate_count<=0;
            invalid_names<=0;
            catalog_valid<=0;catalog_type<=0;catalog_index<=0;long_name<=0;
            name_hash<=0;name_length<=0;start_cluster<=0;file_size<=0;attributes<=0;
            scan_complete<=0;file_count<=0;
        end else begin
            catalog_valid<=0;scan_complete<=0;
            if(raw_done)finished_input<=1;
            if(scan_start)begin
                state<=COLLECT;entries<=0;used<=0;duplicates<=0;duplicate_count<=0;
                invalid_names<=0;
                file_count<=0;finished_input<=0;best_valid<=0;
            end else case(state)
                COLLECT:begin
                    if(raw_valid)begin
                        if(FIXED_NAMES&&!fixed_known)begin
                            if(invalid_names!=255)invalid_names<=invalid_names+1'b1;
                        end else begin

                        copy_index<=FIXED_NAMES ? fixed_rank : entries[4:0];
                        entries<=entries+1'b1;
                        if(FIXED_NAMES)begin
                            used[fixed_rank]<=1;
                            if(used[fixed_rank])begin
                                duplicates[fixed_rank]<=1;
                                duplicate_count<=duplicate_count+(duplicates[fixed_rank] ? 8'd1 : 8'd2);
                            end
                        end
                        name_position<=0;state<=COPY_NAME;
                        metadata_shift<=COMPACT_META ? {raw_attributes,8'd0,raw_size,raw_cluster} :
                            {13'd0,raw_long,raw_type,raw_attributes,raw_length,raw_hash,raw_size,raw_cluster};
                        end
                    end else if(finished_input)state<=SELECT;
                end
                COPY_NAME:begin
                    if(name_position<8)metadata_shift<=metadata_shift>>16;
                    if(name_position==(FIXED_NAMES ? 7 : NAME_CHARS-1))state<=COLLECT;
                    else name_position<=name_position+1'b1;
                end
                SELECT:begin candidate<=0;best_valid<=0;state<=SEARCH;end
                SEARCH:begin
                    if(FIXED_NAMES)begin
                        if(candidate==(FIXED_WAV_FILES==16 ? 32 : 17+FIXED_WAV_FILES))state<=FINISH;
                        else if(used[candidate[4:0]]&&!duplicates[candidate[4:0]])begin
                            best<=candidate[4:0];state<=EMIT;
                        end else candidate<=candidate+1'b1;
                    end else if(candidate>=entries)state<=best_valid ? EMIT : FINISH;
                    else if(used[candidate[4:0]])candidate<=candidate+1'b1;
                    else if(!best_valid)begin
                        best<=candidate[4:0];best_valid<=1;candidate<=candidate+1'b1;
                    end else begin char_position<=0;state<=READ_A;end
                end
                READ_A:state<=READ_B;
                READ_B:begin char_a<=name_q;state<=COMPARE;end
                COMPARE:begin
                    if(compare_a<compare_b)begin best<=candidate[4:0];candidate<=candidate+1'b1;state<=SEARCH;end
                    else if(compare_a>compare_b)begin candidate<=candidate+1'b1;state<=SEARCH;end
                    else if(FIXED_NAMES||compare_a==0||char_position==NAME_CHARS-1)begin
                        duplicates[candidate[4:0]]<=1;duplicates[best]<=1;
                        candidate<=candidate+1'b1;state<=SEARCH;
                    end else begin char_position<=char_position+1'b1;state<=READ_A;end
                end
                EMIT:begin
                    used[best]<=!FIXED_NAMES;meta_step<=0;
                    if(!FIXED_NAMES&&duplicates[best])begin duplicate_count<=duplicate_count+1'b1;state<=SELECT;end
                    else state<=READ_META;
                end
                READ_META:begin
                    meta_step<=meta_step+1'b1;
                    case(meta_step)
                        1:start_cluster[15:0]<=meta_q;
                        2:start_cluster[31:16]<=meta_q;
                        3:file_size[15:0]<=meta_q;
                        4:file_size[31:16]<=meta_q;
                        5:if(COMPACT_META)begin attributes<=meta_q[15:8];name_length<=11;end
                            else name_hash[15:0]<=meta_q;
                        6:if(!COMPACT_META)name_hash[31:16]<=meta_q;
                        7:if(!COMPACT_META)begin attributes<=meta_q[15:8];name_length<=meta_q[7:0];end
                        8:begin
                            long_name<=COMPACT_META ? 1'b0 : meta_q[2];
                            catalog_type<=COMPACT_META ? (best<16 ? 2'd1 : best<16+FIXED_WAV_FILES ? 2'd2 : 2'd3) : meta_q[1:0];
                        end
                    endcase
                    if(meta_step==9)begin
                        catalog_valid<=1;catalog_index<=file_count;
                        file_count<=file_count+1'b1;state<=SELECT;
                    end
                end
                FINISH:begin scan_complete<=1;finished_input<=0;state<=COLLECT;end
                default:state<=COLLECT;
            endcase
        end
    end
endmodule
