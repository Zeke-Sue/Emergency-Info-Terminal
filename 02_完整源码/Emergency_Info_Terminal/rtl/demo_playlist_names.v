module demo_playlist_names(input wire wav, input wire [4:0] ordinal,
    output reg [31:0] short_hash,long_hash, output reg [7:0] name_length, output reg known);
    always @* begin
        short_hash=0;long_hash=0;name_length=0;known=0;
        case({wav,ordinal})
            6'd0: begin short_hash=32'h05799412; long_hash=32'h13c4ff0a; name_length=8'd11; known=1; end
            6'd1: begin short_hash=32'hd5847d2f; long_hash=32'h131d91d1; name_length=8'd11; known=1; end
            6'd2: begin short_hash=32'hfefd6ee8; long_hash=32'hfd02a718; name_length=8'd11; known=1; end
            6'd3: begin short_hash=32'h38034a9d; long_hash=32'h65d137a7; name_length=8'd11; known=1; end
            6'd4: begin short_hash=32'h7b17eede; long_hash=32'hdda1f86e; name_length=8'd11; known=1; end
            6'd5: begin short_hash=32'h0c6a211b; long_hash=32'h3a2c8bb5; name_length=8'd11; known=1; end
            6'd6: begin short_hash=32'hc0f20d94; long_hash=32'hc6dfa07c; name_length=8'd11; known=1; end
            6'd7: begin short_hash=32'h01ea2e29; long_hash=32'hf277e72b; name_length=8'd11; known=1; end
            6'd8: begin short_hash=32'h3e49c20a; long_hash=32'h9170aa72; name_length=8'd11; known=1; end
            6'd9: begin short_hash=32'h2978c9cc; long_hash=32'ha99b8a52; name_length=8'd11; known=1; end
            6'd10: begin short_hash=32'hfd856f13; long_hash=32'hdfa6ca8b; name_length=8'd11; known=1; end
            6'd11: begin short_hash=32'h6ff553b6; long_hash=32'h0f856da0; name_length=8'd11; known=1; end
            6'd12: begin short_hash=32'h543e3c55; long_hash=32'hb187b599; name_length=8'd11; known=1; end
            6'd13: begin short_hash=32'hb3da6f00; long_hash=32'h1ffaf3b6; name_length=8'd11; known=1; end
            6'd14: begin short_hash=32'h74ddb7c7; long_hash=32'h538bcaef; name_length=8'd11; known=1; end
            6'd15: begin short_hash=32'h325c326a; long_hash=32'h766cd804; name_length=8'd11; known=1; end
            6'd32: begin short_hash=32'hc65792d3; long_hash=32'hc2366afd; name_length=8'd11; known=1; end
            6'd33: begin short_hash=32'h8b3f6e8c; long_hash=32'hdb936494; name_length=8'd11; known=1; end
            6'd34: begin short_hash=32'h8f96bdbd; long_hash=32'h597d0b6f; name_length=8'd11; known=1; end
            6'd35: begin short_hash=32'h971ea646; long_hash=32'h18226d86; name_length=8'd11; known=1; end
            6'd36: begin short_hash=32'h63db951f; long_hash=32'h19422459; name_length=8'd11; known=1; end
            6'd37: begin short_hash=32'hc6a71908; long_hash=32'hc1c7fdf0; name_length=8'd11; known=1; end
            6'd38: begin short_hash=32'h212adc99; long_hash=32'h6bf0b5cb; name_length=8'd11; known=1; end
            6'd39: begin short_hash=32'h4def5d92; long_hash=32'h590e9e62; name_length=8'd11; known=1; end
            6'd40: begin short_hash=32'h01a62e3b; long_hash=32'h9c3b0435; name_length=8'd11; known=1; end
            6'd41: begin short_hash=32'h01145d94; long_hash=32'hf34c912c; name_length=8'd11; known=1; end
            6'd42: begin short_hash=32'h356e5576; long_hash=32'h804a9fdc; name_length=8'd11; known=1; end
            6'd43: begin short_hash=32'h808692ed; long_hash=32'h97b063a5; name_length=8'd11; known=1; end
            default: begin end
        endcase
    end
endmodule
