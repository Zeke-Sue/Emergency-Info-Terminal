`timescale 1ns/1ps
module tb_remote_spectrum;
    reg clk=0,rst=1,start=0,sample=0,spec=0,done=0,frame=0;
    always #5 clk=~clk;
    reg [5:0] bin=0;reg [15:0] magnitude=0;
    wire request;reg ready=0;wire [7:0] kind;wire [95:0] data;
    reg message=0;reg [7:0] message_type=0;reg [95:0] payload=0;
    reg [6:0] age=0;reg [5:0] query=0;wire [7:0] value;
    wire [23:0] peak;wire [3:0] file_id;wire [31:0] position;wire valid;
    wire [15:0] dropped;
    reg [3:0] source_file=7;
    spectrum_packetizer source(.clk(clk),.rst(rst),.file_start(start),
        .sample_valid(sample),.file_index(source_file),.spectrum_valid(spec),
        .spectrum_bin(bin),.spectrum_magnitude(magnitude),.transform_done(done),
        .peak_frequency_q8(24'd256000),.request_valid(request),.request_ready(ready),
        .request_type(kind),.request_payload(data));
    remote_spectrum_receiver #(.TIMEOUT_FRAMES(4)) sink(.clk(clk),.rst(rst),.frame_tick(frame),
        .message_valid(message),.message_type(message_type),.payload(payload),
        .query_age(age),.query_bin(query),.query_value(value),
        .peak_frequency_q8(peak),.file_index(file_id),.sample_position(position),
        .valid(valid),.dropped_columns(dropped));
    task fail;input [255:0] why;begin $display("TEST_FAIL spectrum: %0s",why);$finish;end endtask
    task column;
        integer i;
        begin
            @(negedge clk);sample=1;repeat(4800)@(negedge clk);sample=0;
            for(i=0;i<64;i=i+1)begin
                spec=1;bin=i;magnitude=(i+1)*16;@(negedge clk);
            end
            spec=0;done=1;@(negedge clk);done=0;
        end
    endtask
    task transfer;
        input integer skip;
        integer i;
        begin
            for(i=0;i<9;i=i+1)begin
                wait(request);@(negedge clk);
                payload=data;message_type=kind;message=i!=skip;ready=1;
                @(negedge clk);message=0;ready=0;
                repeat(13)@(negedge clk);
            end
        end
    endtask
    integer i;
    initial begin
        repeat(4)@(negedge clk);rst=0;
        column();transfer(3);
        frame=1;@(negedge clk);frame=0;repeat(80)@(negedge clk);
        if(valid)fail("incomplete column was committed");
        column();transfer(-1);
        if(valid)fail("column committed outside blank");
        frame=1;@(negedge clk);frame=0;repeat(80)@(negedge clk);
        if(!valid||file_id!=7||peak!=256000||position!=9600)fail("metadata mismatch");
        for(i=0;i<64;i=i+1)begin
            query=i;@(posedge clk);#1;
            if(value!==i+1)fail("column data mismatch");
            @(negedge clk);
        end
        age=1;@(posedge clk);#1;if(value!=0)fail("uninitialized history visible");
        @(negedge clk);column();transfer(-1);
        frame=1;@(negedge clk);frame=0;repeat(80)@(negedge clk);
        query=0;age=1;repeat(2)@(posedge clk);#1;
        if(value!=1)fail("second column did not preserve history");
        @(negedge clk);source_file=8;start=1;@(negedge clk);start=0;
        column();transfer(-1);
        frame=1;@(negedge clk);frame=0;repeat(80)@(negedge clk);
        if(file_id!=8)fail("file change was not committed");
        repeat(2)@(posedge clk);#1;if(value!=0)fail("old file history leaked");
        for(i=0;i<4;i=i+1)begin
            @(negedge clk);frame=1;@(negedge clk);frame=0;
        end
        age=0;repeat(2)@(posedge clk);#1;
        if(valid||value!=0)fail("stale spectrum survived timeout");
        $display("TEST_PASS tb_remote_spectrum atomic columns, loss, file boundary and timeout");$finish;
    end
    initial begin #2000000;fail("timeout");end
endmodule
