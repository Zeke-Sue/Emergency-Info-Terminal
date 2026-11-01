`timescale 1ns/1ps

module transition_coordinate_generator #(
    parameter integer BASIC_ONLY=0,
    parameter integer WIDTH=640,
    parameter integer HEIGHT=480
)(

    input wire [2:0] mode,
    input wire [6:0] progress,
    input wire [10:0] x,
    input wire [10:0] y,
    output reg select_new,
    output reg [7:0] new_alpha,
    output reg [10:0] old_x,
    output reg [10:0] old_y,
    output reg [10:0] new_x,
    output reg [10:0] new_y,
    output wire dual_source
);
    wire [10:0] x_cut;
    generate if(WIDTH==640) begin: fixed_640_cut
        assign x_cut=(progress<<3)+(progress<<1);
    end else begin: generic_cut
        wire [17:0] x_product=progress*WIDTH;
        assign x_cut=x_product>>6;
    end endgenerate
    wire [10:0] push_split=WIDTH-x_cut;
    wire [15:0] hash=(x*16'd73)^(y*16'd151)^{x[7:0],y[7:0]};
    wire [7:0] dissolve_level={progress[5:0],2'b11};
    wire [10:0] block_x={x[10:4],4'b0};
    wire [7:0] block_rank={x[5:4],y[5:4],x[7:6]^y[7:6],x[9:8]^y[9:8]};
    wire signed [11:0] dx=$signed({1'b0,x})-WIDTH/2;
    wire signed [11:0] dy=$signed({1'b0,y})-HEIGHT/2;
    wire [23:0] distance2=dx*dx+dy*dy;
    localparam integer RADIUS=(WIDTH==640 && HEIGHT==480) ? 400 : (WIDTH+HEIGHT)/2;
    wire [18:0] radius_product=progress*RADIUS;
    wire [11:0] radius=radius_product>>6;
    wire [23:0] radius2=radius*radius;
    assign dual_source=1'b1;
    always @* begin
        select_new=0;new_alpha=0;old_x=x;old_y=y;new_x=x;new_y=y;
        if(progress==0)begin select_new=0;new_alpha=0;end
        else if(progress>=64) begin select_new=1;new_alpha=255;end
        else if(BASIC_ONLY)begin

            case(mode)
              0:begin new_alpha={progress[5:0],2'b00};select_new=progress>=32;end
              2:begin select_new=x>=push_split;new_alpha=select_new ? 255 : 0;
                old_x=x+x_cut;new_x=x-push_split;end
              5:begin select_new={1'b0,x[4:0]}<(progress>>1);new_alpha=select_new ? 255 : 0;end
              default:begin select_new=x<x_cut;new_alpha=select_new ? 255 : 0;end
            endcase
        end else case(mode)
            0:begin new_alpha={progress[5:0],2'b00};select_new=progress>=32;end
            1:begin select_new=x<x_cut;new_alpha=select_new ? 255 : 0;end
            2:begin
                select_new=x>=push_split;new_alpha=select_new ? 255 : 0;
                old_x=x+x_cut;new_x=x-push_split;
            end
            3:begin select_new=hash[7:0]<=dissolve_level;new_alpha=select_new ? 255 : 0;end
            4:begin
                select_new=block_rank<{progress[5:0],2'b00};
                new_alpha=select_new ? 255 : 0;
            end
            5:begin select_new={1'b0,x[4:0]}<(progress>>1);new_alpha=select_new ? 255 : 0;end
            6:begin select_new=distance2<=radius2;new_alpha=select_new ? 255 : 0;end
            default:begin
                select_new=x<x_cut;new_alpha=select_new ? 255 : 0;
            end
        endcase
    end
endmodule
