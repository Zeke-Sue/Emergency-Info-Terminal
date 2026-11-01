module demo_sprite_palette(input wire sprite, input wire [3:0] index,
    output reg [31:0] argb, output reg [35:0] premultiplied,
    output reg [4:0] inverse_alpha);
    always @* begin
        case({sprite,index})
            5'd0: begin argb=32'hfe04b062; premultiplied=36'h040b00620; inverse_alpha=5'd0; end
            5'd1: begin argb=32'h00000000; premultiplied=36'h000000000; inverse_alpha=5'd16; end
            5'd2: begin argb=32'h0100ff00; premultiplied=36'h000000000; inverse_alpha=5'd16; end
            5'd3: begin argb=32'h0d00a35b; premultiplied=36'h000000000; inverse_alpha=5'd16; end
            5'd4: begin argb=32'hfe67cd9e; premultiplied=36'h670cd09e0; inverse_alpha=5'd0; end
            5'd5: begin argb=32'hfea6e1c6; premultiplied=36'ha60e10c60; inverse_alpha=5'd0; end
            5'd6: begin argb=32'hfe8cdab5; premultiplied=36'h8c0da0b50; inverse_alpha=5'd0; end
            5'd7: begin argb=32'h07fcfefd; premultiplied=36'h000000000; inverse_alpha=5'd16; end
            5'd8: begin argb=32'hffcdeede; premultiplied=36'hcd0ee0de0; inverse_alpha=5'd0; end
            5'd9: begin argb=32'hff3bbe80; premultiplied=36'h3b0be0800; inverse_alpha=5'd0; end
            5'd10: begin argb=32'h0100ffff; premultiplied=36'h000000000; inverse_alpha=5'd16; end
            5'd11: begin argb=32'hff3fc184; premultiplied=36'h3f0c10840; inverse_alpha=5'd0; end
            5'd12: begin argb=32'h0e009a36; premultiplied=36'h000000000; inverse_alpha=5'd16; end
            5'd13: begin argb=32'h0e007f12; premultiplied=36'h000000000; inverse_alpha=5'd16; end
            5'd14: begin argb=32'hfd00ad5d; premultiplied=36'h000ad05d0; inverse_alpha=5'd0; end
            5'd15: begin argb=32'hfefcfdfc; premultiplied=36'hfc0fd0fc0; inverse_alpha=5'd0; end
            5'd16: begin argb=32'hfed45859; premultiplied=36'hd40580590; inverse_alpha=5'd0; end
            5'd17: begin argb=32'hf9e8a1a2; premultiplied=36'he80a10a20; inverse_alpha=5'd0; end
            5'd18: begin argb=32'h6cfaefef; premultiplied=36'h5dc59a59a; inverse_alpha=5'd10; end
            5'd19: begin argb=32'ha2f8eaea; premultiplied=36'h9b0924924; inverse_alpha=5'd6; end
            5'd20: begin argb=32'hfbba2527; premultiplied=36'hba0250270; inverse_alpha=5'd0; end
            5'd21: begin argb=32'h03ffa7a7; premultiplied=36'h000000000; inverse_alpha=5'd16; end
            5'd22: begin argb=32'h17dedcdc; premultiplied=36'h0de0dc0dc; inverse_alpha=5'd15; end
            5'd23: begin argb=32'hfcca393b; premultiplied=36'hca03903b0; inverse_alpha=5'd0; end
            5'd24: begin argb=32'hdbf0d1d1; premultiplied=36'hc30a9da9d; inverse_alpha=5'd3; end
            5'd25: begin argb=32'hbde9b7b8; premultiplied=36'ha037dd7e8; inverse_alpha=5'd5; end
            5'd26: begin argb=32'hfbd67e80; premultiplied=36'hd607e0800; inverse_alpha=5'd0; end
            5'd27: begin argb=32'h00000000; premultiplied=36'h000000000; inverse_alpha=5'd16; end
            5'd28: begin argb=32'h06ffffff; premultiplied=36'h000000000; inverse_alpha=5'd16; end
            5'd29: begin argb=32'hfbdb898b; premultiplied=36'hdb08908b0; inverse_alpha=5'd0; end
            5'd30: begin argb=32'h05ffcccc; premultiplied=36'h000000000; inverse_alpha=5'd16; end
            5'd31: begin argb=32'h7bfbf5f5; premultiplied=36'h6dd6b36b3; inverse_alpha=5'd9; end
            default: begin argb=0;premultiplied=0;inverse_alpha=16;end
        endcase
    end
endmodule
