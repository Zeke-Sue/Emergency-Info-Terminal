`timescale 1ns/1ps
module status_display #(parameter integer TEST_STATUS=0)(
    input wire [15:0] test_status,
    input wire clk, rst,
    input wire [3:0] image_index,
    input wire [4:0] image_count,
    input wire autoplay, ready,
    input wire [5:0] period_seconds,
    input wire [3:0] error_code,
    output wire [5:0] seg_sel,
    output reg [7:0] seg_data
);
    reg [14:0] div;
    reg [2:0] digit;
    reg [3:0] value;
    wire [4:0] test_page=test_status[4:0]+1'b1;
    assign seg_sel=~(6'b000001<<digit);
    always @(posedge clk or posedge rst) begin
        if(rst) begin div<=0; digit<=0; end
        else if(div==24999) begin div<=0; digit<=digit==5 ? 3'd0 : digit+1'b1; end
        else div<=div+1'b1;
    end
    always @* begin
        case(digit)
            0: value=period_seconds==10 ? 0 : period_seconds[3:0];
            1: value=period_seconds==10 ? 1 : 0;
            2: value=autoplay ? 4'ha : 4'hb;
            3: value=ready ? image_index : 4'd0;
            4: value=image_count==16 ? 4'hf : image_count[3:0];
            default: value=error_code!=0 ? error_code : 4'hc;
        endcase
        if(TEST_STATUS&&test_status[15])begin
            case(digit)
                0:value=4'he;
                1:value=0;
                2:value=test_page>=20 ? test_page-20 : test_page>=10 ? test_page-10 : test_page;
                3:value=test_page>=20 ? 2 : test_page>=10 ? 1 : 0;
                4:value={3'd0,test_status[14]};
                default:value=error_code!=0 ? error_code : 4'hc;
            endcase
        end
        case(value)
            0:seg_data=8'hc0; 1:seg_data=8'hf9; 2:seg_data=8'ha4; 3:seg_data=8'hb0;
            4:seg_data=8'h99; 5:seg_data=8'h92; 6:seg_data=8'h82; 7:seg_data=8'hf8;
            8:seg_data=8'h80; 9:seg_data=8'h90; 10:seg_data=8'h88; 11:seg_data=8'h83;
            12:seg_data=8'hc6; 13:seg_data=8'ha1; 14:seg_data=8'h86; default:seg_data=8'h8e;
        endcase
    end
endmodule
