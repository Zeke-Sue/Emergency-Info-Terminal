`timescale 1ns/1ps

module l0_voice_catalog(input wire [5:0] segment,
    output reg [15:0] start,output reg [15:0] length);
always @* begin start=0;length=0;case(segment)
6'd0:begin start=16'd0;length=16'd800;end
6'd1:begin start=16'd800;length=16'd800;end
6'd2:begin start=16'd1600;length=16'd800;end
6'd3:begin start=16'd2400;length=16'd800;end
6'd4:begin start=16'd3200;length=16'd800;end
6'd5:begin start=16'd4000;length=16'd800;end
6'd6:begin start=16'd4800;length=16'd800;end
6'd7:begin start=16'd5600;length=16'd800;end
6'd8:begin start=16'd6400;length=16'd800;end
6'd9:begin start=16'd7200;length=16'd800;end
6'd10:begin start=16'd8000;length=16'd800;end
6'd11:begin start=16'd8800;length=16'd800;end
6'd12:begin start=16'd9600;length=16'd800;end
6'd13:begin start=16'd10400;length=16'd800;end
6'd14:begin start=16'd11200;length=16'd800;end
6'd15:begin start=16'd12000;length=16'd800;end
6'd16:begin start=16'd12800;length=16'd800;end
6'd17:begin start=16'd13600;length=16'd800;end
6'd18:begin start=16'd14400;length=16'd800;end
6'd19:begin start=16'd15200;length=16'd800;end
6'd20:begin start=16'd16000;length=16'd800;end
6'd21:begin start=16'd16800;length=16'd800;end
6'd22:begin start=16'd17600;length=16'd800;end
6'd23:begin start=16'd18400;length=16'd800;end
6'd24:begin start=16'd19200;length=16'd800;end
6'd25:begin start=16'd20000;length=16'd800;end
6'd26:begin start=16'd20800;length=16'd800;end
6'd27:begin start=16'd21600;length=16'd800;end
default:begin start=0;length=0;end
endcase end
endmodule
