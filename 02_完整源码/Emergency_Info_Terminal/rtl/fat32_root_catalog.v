`timescale 1ns/1ps

module fat32_root_catalog #(
    parameter integer MAX_FILES=32,

    parameter integer STREAMING=0,
    parameter integer NAME_CHARS=256,
    parameter integer ALLOW_LONG_NAMES=1,
    parameter integer HASH_NAMES=1
)(
    input wire clk,input wire rst,input wire scan_start,
    input wire byte_valid,input wire [7:0] byte_data,output wire byte_ready,
    input wire scan_finish,
    output reg catalog_valid,output reg [1:0] catalog_type,
    output reg [5:0] catalog_index,output reg long_name,
    output reg [31:0] name_hash,output reg [7:0] name_length,
    output reg [31:0] start_cluster,output reg [31:0] file_size,
    output reg [7:0] attributes,
    output reg scan_complete,output reg [5:0] file_count,
    output reg [7:0] malformed_count,output reg overflow,
    output wire [NAME_CHARS*16-1:0] normalized_name,
    output wire [87:0] short_name
);
    localparam ACCEPT=0,EVALUATE=1,LFN_LOW=2,LFN_HIGH=3,SFN_CHAR=4,PUBLISH=5;
    reg [2:0] state;
    reg [7:0] entry [0:31];
    assign short_name={entry[0],entry[1],entry[2],entry[3],entry[4],entry[5],
        entry[6],entry[7],entry[8],entry[9],entry[10]};
    reg [4:0] entry_index;
    reg finish_pending,scanning,lfn_valid,lfn_rejected;
    reg [4:0] lfn_expected;
    reg [7:0] lfn_checksum,checksum_acc,lfn_length;
    reg [31:0] lfn_hash,hash_acc;
    reg [NAME_CHARS*16-1:0] lfn_key;
    reg [207:0] short_key;

    assign normalized_name=long_name ? lfn_key :
        {short_key,{(NAME_CHARS-13)*16{1'b0}}};
    reg [3:0] char_index,key_position;
    reg dot_written;
    reg [8:0] lfn_base;
    wire [8:0] lfn_position=lfn_base+char_index;
    function [4:0] lfn_low_offset;
        input [3:0] index;
        begin case(index)
            0:lfn_low_offset=1;1:lfn_low_offset=3;2:lfn_low_offset=5;
            3:lfn_low_offset=7;4:lfn_low_offset=9;5:lfn_low_offset=14;
            6:lfn_low_offset=16;7:lfn_low_offset=18;8:lfn_low_offset=20;
            9:lfn_low_offset=22;10:lfn_low_offset=24;
            11:lfn_low_offset=28;default:lfn_low_offset=30;
        endcase end
    endfunction
    function [15:0] normalized_char;
        input [15:0] value;
        begin normalized_char=value>=16'h0061&&value<=16'h007a ? value-16'h0020 : value;end
    endfunction
    function upper_equal;
        input [7:0] value,upper;
        begin upper_equal=value==upper||value==upper+8'h20;end
    endfunction
    wire [4:0] char_offset=lfn_low_offset(char_index);
    wire [15:0] long_char={entry[char_offset+5'd1],entry[char_offset]};
    wire long_is_char=long_char!=0&&long_char!=16'hffff;
    wire [7:0] short_char=entry[{1'b0,char_index}];
    wire [7:0] hash_byte=state==LFN_LOW ? long_char[7:0] :
        state==LFN_HIGH ? long_char[15:8] : short_char;
    wire [31:0] hash_xor=hash_acc^{24'd0,hash_byte};

    wire [31:0] hash_next=(hash_xor<<24)+(hash_xor<<8)+(hash_xor<<7)+
        (hash_xor<<4)+(hash_xor<<1)+hash_xor;
    wire valid_lfn_header=entry[0][4:0]!=0&&entry[0][4:0]<=20&&
        !entry[0][7]&&!entry[0][5]&&entry[12]==0&&entry[26]==0&&entry[27]==0;
    wire lfn_match=lfn_valid&&lfn_expected==0&&lfn_checksum==checksum_acc;
    wire [1:0] item_type=
        upper_equal(entry[8],"B")&&upper_equal(entry[9],"M")&&upper_equal(entry[10],"P") ? 2'd1 :
        upper_equal(entry[8],"W")&&upper_equal(entry[9],"A")&&upper_equal(entry[10],"V") ? 2'd2 :
        upper_equal(entry[0],"C")&&upper_equal(entry[1],"O")&&upper_equal(entry[2],"N")&&
        upper_equal(entry[3],"F")&&upper_equal(entry[4],"I")&&upper_equal(entry[5],"G")&&
        entry[6]==" "&&entry[7]==" "&&upper_equal(entry[8],"B")&&
        upper_equal(entry[9],"I")&&upper_equal(entry[10],"N") ? 2'd3 : 2'd0;
    assign byte_ready=scanning&&state==ACCEPT&&!finish_pending;
    always @(posedge clk or posedge rst)begin
        if(rst)begin
            state<=ACCEPT;entry_index<=0;finish_pending<=0;scanning<=0;
            catalog_valid<=0;catalog_type<=0;catalog_index<=0;long_name<=0;
            name_hash<=0;name_length<=0;start_cluster<=0;file_size<=0;attributes<=0;
            scan_complete<=0;file_count<=0;malformed_count<=0;overflow<=0;
            lfn_valid<=0;lfn_rejected<=0;lfn_expected<=0;lfn_checksum<=0;
            checksum_acc<=0;lfn_length<=0;lfn_hash<=32'h811c9dc5;hash_acc<=32'h811c9dc5;
            lfn_key<=0;short_key<=0;
            char_index<=0;key_position<=0;dot_written<=0;lfn_base<=0;
        end else begin
            catalog_valid<=0;scan_complete<=0;
            if(scan_start)begin
                state<=ACCEPT;entry_index<=0;finish_pending<=0;scanning<=1;
                file_count<=0;malformed_count<=0;overflow<=0;
                lfn_valid<=0;lfn_rejected<=0;lfn_expected<=0;
                lfn_hash<=32'h811c9dc5;lfn_length<=0;lfn_key<=0;
            end else begin
                if(scan_finish&&scanning)finish_pending<=1;
                case(state)
                    ACCEPT:begin
                        if(byte_valid&&byte_ready)begin
                            entry[entry_index]<=byte_data;
                            if(entry_index==31)begin entry_index<=0;state<=EVALUATE;end
                            else entry_index<=entry_index+1'b1;
                        end
                        if(finish_pending)begin
                            scanning<=0;finish_pending<=0;scan_complete<=1;
                            if(entry_index!=0)malformed_count<=malformed_count+1'b1;
                            entry_index<=0;lfn_valid<=0;lfn_rejected<=0;
                        end
                    end
                    EVALUATE:begin
                        if(entry[0]==0)begin
                            state<=ACCEPT;scanning<=0;finish_pending<=0;scan_complete<=1;
                            lfn_valid<=0;lfn_rejected<=0;
                        end else if(entry[0]==8'he5)begin
                            state<=ACCEPT;lfn_valid<=0;lfn_rejected<=0;
                        end else if(entry[11]==8'h0f)begin
                            if(!ALLOW_LONG_NAMES)begin

                                lfn_valid<=0;lfn_rejected<=0;state<=ACCEPT;
                            end else begin
                            char_index<=0;state<=LFN_LOW;
                            lfn_base<=({4'd0,entry[0][4:0]}-9'd1)*9'd13;
                            if(entry[0][6])begin
                                lfn_valid<=valid_lfn_header;lfn_rejected<=0;
                                lfn_expected<=entry[0][4:0]-1'b1;lfn_checksum<=entry[13];
                                lfn_key<=0;lfn_length<=0;hash_acc<=32'h811c9dc5;
                                if(!valid_lfn_header)malformed_count<=malformed_count+1'b1;
                            end else begin
                                hash_acc<=lfn_hash;
                                if(!lfn_valid||!valid_lfn_header||entry[0][4:0]!=lfn_expected||entry[13]!=lfn_checksum)begin
                                    lfn_valid<=0;malformed_count<=malformed_count+1'b1;
                                end
                                if(lfn_expected!=0)lfn_expected<=lfn_expected-1'b1;
                            end
                            end
                        end else begin
                            hash_acc<=32'h811c9dc5;checksum_acc<=0;short_key<=0;
                            char_index<=0;key_position<=0;dot_written<=0;state<=SFN_CHAR;
                        end
                    end
                    LFN_LOW:begin
                        if(lfn_position<NAME_CHARS-1)
                            lfn_key[NAME_CHARS*16-1-lfn_position*16 -:16]<=
                                long_is_char ? normalized_char(long_char) : 16'd0;
                        else if(long_is_char)begin
                            lfn_valid<=0;lfn_rejected<=1;
                            if(!lfn_rejected)malformed_count<=malformed_count+1'b1;
                        end
                        if(long_is_char)begin
                            hash_acc<=hash_next;
                            if(lfn_length!=255)lfn_length<=lfn_length+1'b1;
                            state<=LFN_HIGH;
                        end else if(char_index==12)begin lfn_hash<=hash_acc;state<=ACCEPT;end
                        else char_index<=char_index+1'b1;
                    end
                    LFN_HIGH:begin
                        hash_acc<=hash_next;
                        if(char_index==12)begin lfn_hash<=hash_next;state<=ACCEPT;end
                        else begin char_index<=char_index+1'b1;state<=LFN_LOW;end
                    end
                    SFN_CHAR:begin
                        if(char_index==8&&!dot_written)begin
                            short_key[207-key_position*16 -:16]<=16'h002e;
                            key_position<=key_position+1'b1;dot_written<=1;
                        end else begin
                            checksum_acc<={checksum_acc[0],checksum_acc[7:1]}+short_char;
                            hash_acc<=hash_next;
                            if(short_char!=" ")begin
                                short_key[207-key_position*16 -:16]<=normalized_char({8'd0,short_char});
                                key_position<=key_position+1'b1;
                            end
                            if(char_index==10)state<=PUBLISH;
                            else char_index<=char_index+1'b1;
                        end
                    end
                    PUBLISH:begin
                        if(lfn_valid&&!lfn_match)malformed_count<=malformed_count+1'b1;
                        if(!(entry[11][4]||entry[11][3])&&item_type!=0&&!lfn_rejected)begin
                            if(STREAMING||file_count<MAX_FILES)begin
                                catalog_valid<=1;catalog_type<=item_type;catalog_index<=file_count;
                                long_name<=lfn_match;name_hash<=HASH_NAMES ? (lfn_match ? lfn_hash : hash_acc) : 0;
                                name_length<=lfn_match ? lfn_length : 8'd11;
                                start_cluster<={entry[21],entry[20],entry[27],entry[26]};
                                file_size<={entry[31],entry[30],entry[29],entry[28]};attributes<=entry[11];
                                if(!STREAMING||file_count!=63)file_count<=file_count+1'b1;
                            end else overflow<=1;
                        end
                        lfn_valid<=0;lfn_rejected<=0;lfn_expected<=0;lfn_length<=0;
                        lfn_hash<=32'h811c9dc5;state<=ACCEPT;
                    end
                    default:state<=ACCEPT;
                endcase
            end
        end
    end
endmodule
