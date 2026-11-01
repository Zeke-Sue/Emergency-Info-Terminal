module demo_playlist_rom(input wire [3:0] image_id, input wire [5:0] cue_address,
    output reg [3:0] asset_index, output reg [31:0] cue_sample,
    output reg [7:0] cue_subtitle, output reg cue_last);
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
            4'd8: asset_index=4'd8;
            4'd9: asset_index=4'd9;
            4'd10: asset_index=4'd0;
            4'd11: asset_index=4'd2;
            4'd12: asset_index=4'd4;
            4'd13: asset_index=4'd5;
            4'd14: asset_index=4'd8;
            4'd15: asset_index=4'd9;
            default: asset_index=0;
        endcase
        cue_sample=0;cue_subtitle=0;cue_last=1;
        case(cue_address)
            6'd0: begin cue_sample=32'd0; cue_subtitle=8'd1; cue_last=1'b0; end
            6'd1: begin cue_sample=32'd240000; cue_subtitle=8'd2; cue_last=1'b0; end
            6'd2: begin cue_sample=32'd480000; cue_subtitle=8'd3; cue_last=1'b0; end
            6'd3: begin cue_sample=32'd720000; cue_subtitle=8'd4; cue_last=1'b1; end
            6'd4: begin cue_sample=32'd0; cue_subtitle=8'd2; cue_last=1'b0; end
            6'd5: begin cue_sample=32'd240000; cue_subtitle=8'd1; cue_last=1'b0; end
            6'd6: begin cue_sample=32'd480000; cue_subtitle=8'd3; cue_last=1'b0; end
            6'd7: begin cue_sample=32'd720000; cue_subtitle=8'd5; cue_last=1'b1; end
            6'd8: begin cue_sample=32'd0; cue_subtitle=8'd1; cue_last=1'b0; end
            6'd9: begin cue_sample=32'd240000; cue_subtitle=8'd3; cue_last=1'b0; end
            6'd10: begin cue_sample=32'd480000; cue_subtitle=8'd4; cue_last=1'b0; end
            6'd11: begin cue_sample=32'd720000; cue_subtitle=8'd5; cue_last=1'b1; end
            6'd12: begin cue_sample=32'd0; cue_subtitle=8'd2; cue_last=1'b0; end
            6'd13: begin cue_sample=32'd240000; cue_subtitle=8'd3; cue_last=1'b0; end
            6'd14: begin cue_sample=32'd480000; cue_subtitle=8'd5; cue_last=1'b0; end
            6'd15: begin cue_sample=32'd720000; cue_subtitle=8'd10; cue_last=1'b1; end
            6'd16: begin cue_sample=32'd0; cue_subtitle=8'd3; cue_last=1'b0; end
            6'd17: begin cue_sample=32'd240000; cue_subtitle=8'd5; cue_last=1'b0; end
            6'd18: begin cue_sample=32'd480000; cue_subtitle=8'd6; cue_last=1'b0; end
            6'd19: begin cue_sample=32'd720000; cue_subtitle=8'd10; cue_last=1'b1; end
            6'd20: begin cue_sample=32'd0; cue_subtitle=8'd7; cue_last=1'b0; end
            6'd21: begin cue_sample=32'd240000; cue_subtitle=8'd8; cue_last=1'b0; end
            6'd22: begin cue_sample=32'd480000; cue_subtitle=8'd7; cue_last=1'b0; end
            6'd23: begin cue_sample=32'd720000; cue_subtitle=8'd8; cue_last=1'b1; end
            6'd24: begin cue_sample=32'd0; cue_subtitle=8'd6; cue_last=1'b0; end
            6'd25: begin cue_sample=32'd240000; cue_subtitle=8'd9; cue_last=1'b0; end
            6'd26: begin cue_sample=32'd480000; cue_subtitle=8'd10; cue_last=1'b0; end
            6'd27: begin cue_sample=32'd720000; cue_subtitle=8'd12; cue_last=1'b1; end
            6'd28: begin cue_sample=32'd0; cue_subtitle=8'd9; cue_last=1'b0; end
            6'd29: begin cue_sample=32'd240000; cue_subtitle=8'd10; cue_last=1'b0; end
            6'd30: begin cue_sample=32'd480000; cue_subtitle=8'd12; cue_last=1'b0; end
            6'd31: begin cue_sample=32'd720000; cue_subtitle=8'd13; cue_last=1'b1; end
            6'd32: begin cue_sample=32'd0; cue_subtitle=8'd11; cue_last=1'b0; end
            6'd33: begin cue_sample=32'd240000; cue_subtitle=8'd12; cue_last=1'b0; end
            6'd34: begin cue_sample=32'd480000; cue_subtitle=8'd13; cue_last=1'b0; end
            6'd35: begin cue_sample=32'd720000; cue_subtitle=8'd10; cue_last=1'b1; end
            6'd36: begin cue_sample=32'd0; cue_subtitle=8'd14; cue_last=1'b0; end
            6'd37: begin cue_sample=32'd240000; cue_subtitle=8'd15; cue_last=1'b0; end
            6'd38: begin cue_sample=32'd480000; cue_subtitle=8'd16; cue_last=1'b0; end
            6'd39: begin cue_sample=32'd720000; cue_subtitle=8'd10; cue_last=1'b1; end
            6'd40: begin cue_sample=32'd0; cue_subtitle=8'd1; cue_last=1'b0; end
            6'd41: begin cue_sample=32'd240000; cue_subtitle=8'd2; cue_last=1'b0; end
            6'd42: begin cue_sample=32'd480000; cue_subtitle=8'd3; cue_last=1'b0; end
            6'd43: begin cue_sample=32'd720000; cue_subtitle=8'd4; cue_last=1'b1; end
            6'd44: begin cue_sample=32'd0; cue_subtitle=8'd1; cue_last=1'b0; end
            6'd45: begin cue_sample=32'd240000; cue_subtitle=8'd3; cue_last=1'b0; end
            6'd46: begin cue_sample=32'd480000; cue_subtitle=8'd4; cue_last=1'b0; end
            6'd47: begin cue_sample=32'd720000; cue_subtitle=8'd5; cue_last=1'b1; end
            6'd48: begin cue_sample=32'd0; cue_subtitle=8'd3; cue_last=1'b0; end
            6'd49: begin cue_sample=32'd240000; cue_subtitle=8'd5; cue_last=1'b0; end
            6'd50: begin cue_sample=32'd480000; cue_subtitle=8'd6; cue_last=1'b0; end
            6'd51: begin cue_sample=32'd720000; cue_subtitle=8'd10; cue_last=1'b1; end
            6'd52: begin cue_sample=32'd0; cue_subtitle=8'd7; cue_last=1'b0; end
            6'd53: begin cue_sample=32'd240000; cue_subtitle=8'd8; cue_last=1'b0; end
            6'd54: begin cue_sample=32'd480000; cue_subtitle=8'd7; cue_last=1'b0; end
            6'd55: begin cue_sample=32'd720000; cue_subtitle=8'd8; cue_last=1'b1; end
            6'd56: begin cue_sample=32'd0; cue_subtitle=8'd11; cue_last=1'b0; end
            6'd57: begin cue_sample=32'd240000; cue_subtitle=8'd12; cue_last=1'b0; end
            6'd58: begin cue_sample=32'd480000; cue_subtitle=8'd13; cue_last=1'b0; end
            6'd59: begin cue_sample=32'd720000; cue_subtitle=8'd10; cue_last=1'b1; end
            6'd60: begin cue_sample=32'd0; cue_subtitle=8'd14; cue_last=1'b0; end
            6'd61: begin cue_sample=32'd240000; cue_subtitle=8'd15; cue_last=1'b0; end
            6'd62: begin cue_sample=32'd480000; cue_subtitle=8'd16; cue_last=1'b0; end
            6'd63: begin cue_sample=32'd720000; cue_subtitle=8'd10; cue_last=1'b1; end
            default: begin end
        endcase
    end
endmodule
