module human_playlist_rom(input wire [3:0] image_id,input wire [5:0] cue_address,
    output reg [3:0] asset_index,output wire [31:0] cue_sample,
    output reg [7:0] cue_subtitle,output wire cue_last);
    assign cue_sample=0;assign cue_last=1;
    always @* begin
        case(image_id)
            4'd0: asset_index=4'd0;
            4'd1: asset_index=4'd1;
            4'd2: asset_index=4'd2;
            4'd3: asset_index=4'd3;
            4'd4: asset_index=4'd4;
            4'd5: asset_index=4'd5;
            4'd6: asset_index=4'd6;
            4'd7: asset_index=4'd7;
            4'd8: asset_index=4'd4;
            4'd9: asset_index=4'd5;
            4'd10: asset_index=4'd4;
            4'd11: asset_index=4'd5;
            4'd12: asset_index=4'd1;
            4'd13: asset_index=4'd1;
            4'd14: asset_index=4'd0;
            4'd15: asset_index=4'd1;
            default:asset_index=0;
        endcase
        case(cue_address[5:2])
            4'd0: cue_subtitle=8'd1;
            4'd1: cue_subtitle=8'd2;
            4'd2: cue_subtitle=8'd3;
            4'd3: cue_subtitle=8'd4;
            4'd4: cue_subtitle=8'd5;
            4'd5: cue_subtitle=8'd6;
            4'd6: cue_subtitle=8'd7;
            4'd7: cue_subtitle=8'd8;
            4'd8: cue_subtitle=8'd5;
            4'd9: cue_subtitle=8'd6;
            4'd10: cue_subtitle=8'd5;
            4'd11: cue_subtitle=8'd6;
            4'd12: cue_subtitle=8'd2;
            4'd13: cue_subtitle=8'd2;
            4'd14: cue_subtitle=8'd1;
            4'd15: cue_subtitle=8'd2;
            default:cue_subtitle=1;
        endcase
    end
endmodule
