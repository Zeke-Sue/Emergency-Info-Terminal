`timescale 1ns/1ps
module tb_pixel_arithmetic;
    video_effects dut();
    integer value,luma,setting,delta,scaled,result_value,expected,count;
    reg [7:0] actual;
    initial begin
        count=0;
        for(setting=0;setting<8;setting=setting+1)
        for(value=0;value<256;value=value+1)
        for(luma=0;luma<256;luma=luma+1)begin
            delta=value-luma;
            case(setting)
                0:scaled=delta>>>1;
                1:scaled=delta-(delta>>>2);
                3:scaled=delta+(delta>>>2);
                4:scaled=delta+(delta>>>1);
                default:scaled=delta;
            endcase
            result_value=luma+scaled;
            expected=result_value<0 ? 0 : (result_value>255 ? 255 : result_value);
            actual=dut.saturate_channel(value[7:0],luma[7:0],setting[2:0]);
            if(actual!==expected[7:0])begin
                $display("TEST_FAIL saturation %0d %0d %0d got %0d expected %0d",value,luma,setting,actual,expected);$finish;
            end
            count=count+1;
        end
        $display("TEST_PASS %0d saturation arithmetic vectors",count);$finish;
    end
endmodule
