`timescale 1ns/1ps

module n10_prototype_segment_map(
    input wire [10:0] x,input wire [10:0] y,input wire [7:0] blocked_set,
    output reg [5:0] segment_id,output reg [7:0] segment_phase,
    output reg blocked_exit_pixel
);
    reg [4:0] dx,dy;
    reg [5:0] diagonal_sum;
    always @* begin
        segment_id=0;segment_phase=0;blocked_exit_pixel=0;dx=0;dy=0;diagonal_sum=0;
        if(y>=254&&y<=266&&x>=210&&x<=330)begin
            segment_id=1;segment_phase=330-x;
        end else if(x>=204&&x<=216&&y>=260&&y<=326)begin
            segment_id=2;segment_phase=y-260;
        end else if(y>=254&&y<=266&&x>=330&&x<=390)begin
            segment_id=3;segment_phase=x-330;
        end else if(x>=384&&x<=396&&y>=202&&y<=260)begin
            segment_id=4;segment_phase=260-y;
        end else if(y>=196&&y<=208&&x>=390&&x<=590)begin
            segment_id=5;segment_phase=x-390;
        end
        if(blocked_set[0]&&x>=194&&x<226&&y>=310&&y<342)begin
            dx=x[4:0]-5'd2;dy=y[4:0]-5'd22;
            diagonal_sum={1'b0,dx}+{1'b0,dy};
            if(({1'b0,dx}+6'd3>={1'b0,dy}&&{1'b0,dx}<={1'b0,dy}+6'd3)||
               (diagonal_sum>=6'd28&&diagonal_sum<=6'd34))
                blocked_exit_pixel=1;
        end
        if(blocked_set[1]&&x>=574&&x<606&&y>=186&&y<218)begin
            dx=x[4:0]-5'd30;dy=y[4:0]-5'd26;
            diagonal_sum={1'b0,dx}+{1'b0,dy};
            if(({1'b0,dx}+6'd3>={1'b0,dy}&&{1'b0,dx}<={1'b0,dy}+6'd3)||
               (diagonal_sum>=6'd28&&diagonal_sum<=6'd34))
                blocked_exit_pixel=1;
        end
    end
endmodule
