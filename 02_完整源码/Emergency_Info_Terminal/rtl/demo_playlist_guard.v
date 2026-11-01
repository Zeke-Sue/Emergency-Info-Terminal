`timescale 1ns/1ps

module demo_playlist_guard(
    input wire clk,rst,mounted,entry_valid,entry_wav,entry_long,
    input wire [4:0] entry_ordinal,bmp_count,wav_count,
    input wire [31:0] entry_hash,
    input wire [7:0] entry_length,malformed_count,
    input wire overflow,
    output wire valid
);
    wire [31:0] expected_short,expected_long;
    wire [7:0] expected_length;
    wire known;
    reg names_ok;
    demo_playlist_names names(.wav(entry_wav),.ordinal(entry_ordinal),
        .short_hash(expected_short),.long_hash(expected_long),
        .name_length(expected_length),.known(known));
    always @(posedge clk or posedge rst)
        if(rst)names_ok<=1;
        else if(entry_valid && (!known ||
            (entry_long ? (entry_hash!=expected_long || entry_length!=expected_length) :
                          (entry_hash!=expected_short || entry_length!=11))))names_ok<=0;
    assign valid=mounted&&names_ok&&bmp_count==16&&wav_count==12&&
        malformed_count==0&&!overflow;
endmodule
