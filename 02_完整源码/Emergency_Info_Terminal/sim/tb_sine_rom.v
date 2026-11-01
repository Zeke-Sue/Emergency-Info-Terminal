`timescale 1ns/1ps
module tb_sine_rom;
    reg [8:0] phase=0;
    wire signed [15:0] actual,expected;
    sine_quarter_rom dut(.phase(phase),.value(actual));
    sine_quarter_rom_baseline baseline(.phase(phase),.value(expected));
    integer i;
    initial begin
        for(i=0;i<512;i=i+1)begin
            phase=i;#1;
            if(actual!==expected)begin
                $display("TEST_FAIL sine phase=%0d got=%0d expected=%0d",i,actual,expected);$finish;
            end
        end
        $display("TEST_PASS tb_sine_rom all 512 phases bit-exact against pre-optimization table");$finish;
    end
endmodule

`timescale 1ns/1ps

module sine_quarter_rom_baseline(input wire [8:0] phase, output reg signed [15:0] value);
    reg [6:0] address;reg negate;
    always @* begin
        case(phase[8:7])
            0:begin address=phase[6:0];negate=0;end
            1:begin address=7'd127-phase[6:0];negate=0;end
            2:begin address=phase[6:0];negate=1;end
            default:begin address=7'd127-phase[6:0];negate=1;end
        endcase
        case(address)
            7'd0:value=negate ? -16'sd0 : 16'sd0;
            7'd1:value=negate ? -16'sd402 : 16'sd402;
            7'd2:value=negate ? -16'sd804 : 16'sd804;
            7'd3:value=negate ? -16'sd1206 : 16'sd1206;
            7'd4:value=negate ? -16'sd1608 : 16'sd1608;
            7'd5:value=negate ? -16'sd2009 : 16'sd2009;
            7'd6:value=negate ? -16'sd2410 : 16'sd2410;
            7'd7:value=negate ? -16'sd2811 : 16'sd2811;
            7'd8:value=negate ? -16'sd3212 : 16'sd3212;
            7'd9:value=negate ? -16'sd3612 : 16'sd3612;
            7'd10:value=negate ? -16'sd4011 : 16'sd4011;
            7'd11:value=negate ? -16'sd4410 : 16'sd4410;
            7'd12:value=negate ? -16'sd4808 : 16'sd4808;
            7'd13:value=negate ? -16'sd5205 : 16'sd5205;
            7'd14:value=negate ? -16'sd5602 : 16'sd5602;
            7'd15:value=negate ? -16'sd5998 : 16'sd5998;
            7'd16:value=negate ? -16'sd6393 : 16'sd6393;
            7'd17:value=negate ? -16'sd6786 : 16'sd6786;
            7'd18:value=negate ? -16'sd7179 : 16'sd7179;
            7'd19:value=negate ? -16'sd7571 : 16'sd7571;
            7'd20:value=negate ? -16'sd7962 : 16'sd7962;
            7'd21:value=negate ? -16'sd8351 : 16'sd8351;
            7'd22:value=negate ? -16'sd8739 : 16'sd8739;
            7'd23:value=negate ? -16'sd9126 : 16'sd9126;
            7'd24:value=negate ? -16'sd9512 : 16'sd9512;
            7'd25:value=negate ? -16'sd9896 : 16'sd9896;
            7'd26:value=negate ? -16'sd10278 : 16'sd10278;
            7'd27:value=negate ? -16'sd10659 : 16'sd10659;
            7'd28:value=negate ? -16'sd11039 : 16'sd11039;
            7'd29:value=negate ? -16'sd11417 : 16'sd11417;
            7'd30:value=negate ? -16'sd11793 : 16'sd11793;
            7'd31:value=negate ? -16'sd12167 : 16'sd12167;
            7'd32:value=negate ? -16'sd12539 : 16'sd12539;
            7'd33:value=negate ? -16'sd12910 : 16'sd12910;
            7'd34:value=negate ? -16'sd13279 : 16'sd13279;
            7'd35:value=negate ? -16'sd13645 : 16'sd13645;
            7'd36:value=negate ? -16'sd14010 : 16'sd14010;
            7'd37:value=negate ? -16'sd14372 : 16'sd14372;
            7'd38:value=negate ? -16'sd14732 : 16'sd14732;
            7'd39:value=negate ? -16'sd15090 : 16'sd15090;
            7'd40:value=negate ? -16'sd15446 : 16'sd15446;
            7'd41:value=negate ? -16'sd15800 : 16'sd15800;
            7'd42:value=negate ? -16'sd16151 : 16'sd16151;
            7'd43:value=negate ? -16'sd16499 : 16'sd16499;
            7'd44:value=negate ? -16'sd16846 : 16'sd16846;
            7'd45:value=negate ? -16'sd17189 : 16'sd17189;
            7'd46:value=negate ? -16'sd17530 : 16'sd17530;
            7'd47:value=negate ? -16'sd17869 : 16'sd17869;
            7'd48:value=negate ? -16'sd18204 : 16'sd18204;
            7'd49:value=negate ? -16'sd18537 : 16'sd18537;
            7'd50:value=negate ? -16'sd18868 : 16'sd18868;
            7'd51:value=negate ? -16'sd19195 : 16'sd19195;
            7'd52:value=negate ? -16'sd19519 : 16'sd19519;
            7'd53:value=negate ? -16'sd19841 : 16'sd19841;
            7'd54:value=negate ? -16'sd20159 : 16'sd20159;
            7'd55:value=negate ? -16'sd20475 : 16'sd20475;
            7'd56:value=negate ? -16'sd20787 : 16'sd20787;
            7'd57:value=negate ? -16'sd21096 : 16'sd21096;
            7'd58:value=negate ? -16'sd21403 : 16'sd21403;
            7'd59:value=negate ? -16'sd21705 : 16'sd21705;
            7'd60:value=negate ? -16'sd22005 : 16'sd22005;
            7'd61:value=negate ? -16'sd22301 : 16'sd22301;
            7'd62:value=negate ? -16'sd22594 : 16'sd22594;
            7'd63:value=negate ? -16'sd22884 : 16'sd22884;
            7'd64:value=negate ? -16'sd23170 : 16'sd23170;
            7'd65:value=negate ? -16'sd23452 : 16'sd23452;
            7'd66:value=negate ? -16'sd23731 : 16'sd23731;
            7'd67:value=negate ? -16'sd24007 : 16'sd24007;
            7'd68:value=negate ? -16'sd24279 : 16'sd24279;
            7'd69:value=negate ? -16'sd24547 : 16'sd24547;
            7'd70:value=negate ? -16'sd24811 : 16'sd24811;
            7'd71:value=negate ? -16'sd25072 : 16'sd25072;
            7'd72:value=negate ? -16'sd25329 : 16'sd25329;
            7'd73:value=negate ? -16'sd25582 : 16'sd25582;
            7'd74:value=negate ? -16'sd25832 : 16'sd25832;
            7'd75:value=negate ? -16'sd26077 : 16'sd26077;
            7'd76:value=negate ? -16'sd26319 : 16'sd26319;
            7'd77:value=negate ? -16'sd26556 : 16'sd26556;
            7'd78:value=negate ? -16'sd26790 : 16'sd26790;
            7'd79:value=negate ? -16'sd27019 : 16'sd27019;
            7'd80:value=negate ? -16'sd27245 : 16'sd27245;
            7'd81:value=negate ? -16'sd27466 : 16'sd27466;
            7'd82:value=negate ? -16'sd27683 : 16'sd27683;
            7'd83:value=negate ? -16'sd27896 : 16'sd27896;
            7'd84:value=negate ? -16'sd28105 : 16'sd28105;
            7'd85:value=negate ? -16'sd28310 : 16'sd28310;
            7'd86:value=negate ? -16'sd28510 : 16'sd28510;
            7'd87:value=negate ? -16'sd28706 : 16'sd28706;
            7'd88:value=negate ? -16'sd28898 : 16'sd28898;
            7'd89:value=negate ? -16'sd29085 : 16'sd29085;
            7'd90:value=negate ? -16'sd29268 : 16'sd29268;
            7'd91:value=negate ? -16'sd29447 : 16'sd29447;
            7'd92:value=negate ? -16'sd29621 : 16'sd29621;
            7'd93:value=negate ? -16'sd29791 : 16'sd29791;
            7'd94:value=negate ? -16'sd29956 : 16'sd29956;
            7'd95:value=negate ? -16'sd30117 : 16'sd30117;
            7'd96:value=negate ? -16'sd30273 : 16'sd30273;
            7'd97:value=negate ? -16'sd30424 : 16'sd30424;
            7'd98:value=negate ? -16'sd30571 : 16'sd30571;
            7'd99:value=negate ? -16'sd30714 : 16'sd30714;
            7'd100:value=negate ? -16'sd30852 : 16'sd30852;
            7'd101:value=negate ? -16'sd30985 : 16'sd30985;
            7'd102:value=negate ? -16'sd31113 : 16'sd31113;
            7'd103:value=negate ? -16'sd31237 : 16'sd31237;
            7'd104:value=negate ? -16'sd31356 : 16'sd31356;
            7'd105:value=negate ? -16'sd31470 : 16'sd31470;
            7'd106:value=negate ? -16'sd31580 : 16'sd31580;
            7'd107:value=negate ? -16'sd31685 : 16'sd31685;
            7'd108:value=negate ? -16'sd31785 : 16'sd31785;
            7'd109:value=negate ? -16'sd31880 : 16'sd31880;
            7'd110:value=negate ? -16'sd31971 : 16'sd31971;
            7'd111:value=negate ? -16'sd32057 : 16'sd32057;
            7'd112:value=negate ? -16'sd32137 : 16'sd32137;
            7'd113:value=negate ? -16'sd32213 : 16'sd32213;
            7'd114:value=negate ? -16'sd32285 : 16'sd32285;
            7'd115:value=negate ? -16'sd32351 : 16'sd32351;
            7'd116:value=negate ? -16'sd32412 : 16'sd32412;
            7'd117:value=negate ? -16'sd32469 : 16'sd32469;
            7'd118:value=negate ? -16'sd32521 : 16'sd32521;
            7'd119:value=negate ? -16'sd32567 : 16'sd32567;
            7'd120:value=negate ? -16'sd32609 : 16'sd32609;
            7'd121:value=negate ? -16'sd32646 : 16'sd32646;
            7'd122:value=negate ? -16'sd32678 : 16'sd32678;
            7'd123:value=negate ? -16'sd32705 : 16'sd32705;
            7'd124:value=negate ? -16'sd32728 : 16'sd32728;
            7'd125:value=negate ? -16'sd32745 : 16'sd32745;
            7'd126:value=negate ? -16'sd32757 : 16'sd32757;
            7'd127:value=negate ? -16'sd32765 : 16'sd32765;
            default:value=0;
        endcase
    end
endmodule
