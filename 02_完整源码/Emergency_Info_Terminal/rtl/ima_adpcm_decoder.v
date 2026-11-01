`timescale 1ns/1ps

module ima_adpcm_decoder #(
    parameter integer SEEDED_BLOCKS=0
)(
    input wire clk,
    input wire rst,
    input wire restart,
    input wire seed_valid,
    input wire signed [15:0] seed_predictor,
    input wire [6:0] seed_index,
    input wire nibble_valid,
    input wire [3:0] nibble,
    output reg sample_valid,
    output reg signed [15:0] pcm_sample,
    output reg [6:0] step_index
);
    reg signed [16:0] predictor;
    reg [15:0] step_value;
    reg signed [16:0] difference;
    reg signed [17:0] next_predictor;
    reg signed [8:0] next_index;
    always @* begin
        case(step_index)
            7'd0:step_value=16'd7;
            7'd1:step_value=16'd8;
            7'd2:step_value=16'd9;
            7'd3:step_value=16'd10;
            7'd4:step_value=16'd11;
            7'd5:step_value=16'd12;
            7'd6:step_value=16'd13;
            7'd7:step_value=16'd14;
            7'd8:step_value=16'd16;
            7'd9:step_value=16'd17;
            7'd10:step_value=16'd19;
            7'd11:step_value=16'd21;
            7'd12:step_value=16'd23;
            7'd13:step_value=16'd25;
            7'd14:step_value=16'd28;
            7'd15:step_value=16'd31;
            7'd16:step_value=16'd34;
            7'd17:step_value=16'd37;
            7'd18:step_value=16'd41;
            7'd19:step_value=16'd45;
            7'd20:step_value=16'd50;
            7'd21:step_value=16'd55;
            7'd22:step_value=16'd60;
            7'd23:step_value=16'd66;
            7'd24:step_value=16'd73;
            7'd25:step_value=16'd80;
            7'd26:step_value=16'd88;
            7'd27:step_value=16'd97;
            7'd28:step_value=16'd107;
            7'd29:step_value=16'd118;
            7'd30:step_value=16'd130;
            7'd31:step_value=16'd143;
            7'd32:step_value=16'd157;
            7'd33:step_value=16'd173;
            7'd34:step_value=16'd190;
            7'd35:step_value=16'd209;
            7'd36:step_value=16'd230;
            7'd37:step_value=16'd253;
            7'd38:step_value=16'd279;
            7'd39:step_value=16'd307;
            7'd40:step_value=16'd337;
            7'd41:step_value=16'd371;
            7'd42:step_value=16'd408;
            7'd43:step_value=16'd449;
            7'd44:step_value=16'd494;
            7'd45:step_value=16'd544;
            7'd46:step_value=16'd598;
            7'd47:step_value=16'd658;
            7'd48:step_value=16'd724;
            7'd49:step_value=16'd796;
            7'd50:step_value=16'd876;
            7'd51:step_value=16'd963;
            7'd52:step_value=16'd1060;
            7'd53:step_value=16'd1166;
            7'd54:step_value=16'd1282;
            7'd55:step_value=16'd1411;
            7'd56:step_value=16'd1552;
            7'd57:step_value=16'd1707;
            7'd58:step_value=16'd1878;
            7'd59:step_value=16'd2066;
            7'd60:step_value=16'd2272;
            7'd61:step_value=16'd2499;
            7'd62:step_value=16'd2749;
            7'd63:step_value=16'd3024;
            7'd64:step_value=16'd3327;
            7'd65:step_value=16'd3660;
            7'd66:step_value=16'd4026;
            7'd67:step_value=16'd4428;
            7'd68:step_value=16'd4871;
            7'd69:step_value=16'd5358;
            7'd70:step_value=16'd5894;
            7'd71:step_value=16'd6484;
            7'd72:step_value=16'd7132;
            7'd73:step_value=16'd7845;
            7'd74:step_value=16'd8630;
            7'd75:step_value=16'd9493;
            7'd76:step_value=16'd10442;
            7'd77:step_value=16'd11487;
            7'd78:step_value=16'd12635;
            7'd79:step_value=16'd13899;
            7'd80:step_value=16'd15289;
            7'd81:step_value=16'd16818;
            7'd82:step_value=16'd18500;
            7'd83:step_value=16'd20350;
            7'd84:step_value=16'd22385;
            7'd85:step_value=16'd24623;
            7'd86:step_value=16'd27086;
            7'd87:step_value=16'd29794;
            7'd88:step_value=16'd32767;
            default:step_value=16'd32767;
        endcase
    end
    always @(posedge clk or posedge rst) begin
        if(rst||restart) begin predictor<=0;step_index<=0;pcm_sample<=0;sample_valid<=0;end
        else begin
            sample_valid<=0;
            if(SEEDED_BLOCKS&&seed_valid)begin
                predictor<=$signed(seed_predictor);step_index<=seed_index;
                pcm_sample<=seed_predictor;sample_valid<=1;
            end else if(nibble_valid) begin
                difference=step_value>>>3;
                if(nibble[0])difference=difference+(step_value>>>2);
                if(nibble[1])difference=difference+(step_value>>>1);
                if(nibble[2])difference=difference+step_value;
                next_predictor=nibble[3] ? predictor-difference : predictor+difference;
                if(next_predictor>32767)next_predictor=32767;
                else if(next_predictor< -32768)next_predictor=-32768;
                case(nibble[2:0])
                    0,1,2,3:next_index=$signed({2'b0,step_index})-9'sd1;
                    4:next_index=$signed({2'b0,step_index})+9'sd2;
                    5:next_index=$signed({2'b0,step_index})+9'sd4;
                    6:next_index=$signed({2'b0,step_index})+9'sd6;
                    default:next_index=$signed({2'b0,step_index})+9'sd8;
                endcase
                if(next_index<0)next_index=0;else if(next_index>88)next_index=88;
                predictor<=next_predictor;pcm_sample<=next_predictor;step_index<=next_index;
                sample_valid<=1;
            end
        end
    end
endmodule
