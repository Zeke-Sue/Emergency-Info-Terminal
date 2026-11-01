`timescale 1ns/1ps
module tb_waterfall_buffer;
    reg clk=0,rst=1,frame_tick=0,spectrum_valid=0;
    always #5 clk=~clk;
    reg [5:0] spectrum_bin=0,query_bin=0;
    reg [15:0] spectrum_magnitude=0;
    reg [6:0] query_age=0;
    wire [7:0] query_value;
    wire [6:0] newest_column;
    waterfall_buffer dut(.clk(clk),.rst(rst),.frame_tick(frame_tick),
        .spectrum_valid(spectrum_valid),.spectrum_bin(spectrum_bin),
        .spectrum_magnitude(spectrum_magnitude),.query_age(query_age),
        .query_bin(query_bin),.query_value(query_value),
        .newest_column(newest_column));

    task fail;
        input [8*100-1:0] reason;
        begin $display("TEST_FAIL tb_waterfall_buffer: %0s",reason);$finish;end
    endtask
    task put;
        input [5:0] bin;input [15:0] magnitude;
        begin
            @(negedge clk);spectrum_bin=bin;spectrum_magnitude=magnitude;
            spectrum_valid=1;
            @(negedge clk);spectrum_valid=0;
            repeat(2)@(negedge clk);
        end
    endtask
    task next_frame;
        begin
            @(negedge clk);frame_tick=1;
            @(negedge clk);frame_tick=0;
            repeat(68)@(negedge clk);
        end
    endtask
    task expect;
        input [6:0] age;input [5:0] bin;input [7:0] value;
        begin
            @(negedge clk);query_age=age;query_bin=bin;
            repeat(3)@(negedge clk);
            if(query_value!==value) begin
                $display("age=%0d bin=%0d expected=%0d got=%0d",age,bin,value,query_value);
                fail("query mismatch");
            end
        end
    endtask

    integer column;
    initial begin
        repeat(3)@(negedge clk);rst=0;
        repeat(66)@(negedge clk);
        put(6'd5,16'h0120);
        put(6'd5,16'h0a00);
        put(6'd5,16'h0400);
        put(6'd42,16'h1ff0);
        next_frame();
        if(newest_column!=1)fail("first column pointer");
        expect(0,5,8'ha0);
        expect(0,42,8'hff);
        expect(0,7,8'h00);

        put(6'd5,16'h0300);
        put(6'd9,16'h0550);
        next_frame();
        if(newest_column!=2)fail("second column pointer");
        expect(0,5,8'h30);
        expect(0,9,8'h55);
        expect(1,5,8'ha0);

        for(column=2;column<130;column=column+1) begin
            put(6'd1,{4'd0,column[7:0],4'd0});
            next_frame();
        end
        if(newest_column!=2)fail("128-column wrap");
        expect(0,1,8'h81);
        expect(1,1,8'h80);
        expect(127,1,8'h02);
        $display("TEST_PASS tb_waterfall_buffer frame maxima, bank swap and 128-column wrap");
        $finish;
    end
    initial begin #3000000;fail("timeout");end
endmodule
