`timescale 1ns/1ps
module tb_spectrum_banks;
    reg clk=0,rst=1,start=0,sample=0,spec=0,done=0,ready=0;
    reg [3:0] file_id=1;
    reg [5:0] bin=0;
    reg [15:0] magnitude=0;
    wire request;
    wire [7:0] kind;
    wire [95:0] payload;
    reg [95:0] held_payload;
    integer c,b,i;
    always #5 clk=~clk;
    spectrum_packetizer dut(.clk(clk),.rst(rst),.file_start(start),
        .sample_valid(sample),.file_index(file_id),.spectrum_valid(spec),
        .spectrum_bin(bin),.spectrum_magnitude(magnitude),.transform_done(done),
        .peak_frequency_q8(24'd256000),.request_valid(request),.request_ready(ready),
        .request_type(kind),.request_payload(payload));
    task emit;
        input [5:0] index;input [15:0] value;
        begin spec=1;bin=index;magnitude=value;@(negedge clk);end
    endtask
    task due;
        begin sample=1;repeat(4800)@(negedge clk);sample=0;end
    endtask
    task drain;
        input integer sequence_id,input_file,pattern;
        reg [7:0] expected;
        begin
            for(c=0;c<9;c=c+1)begin
                wait(request);@(negedge clk);held_payload=payload;
                repeat(13)begin
                    @(negedge clk);
                    if(!request||payload!==held_payload)$fatal(1,"TEST_FAIL stalled payload changed");
                end
                if(payload[95:88]!==sequence_id[7:0])$fatal(1,"TEST_FAIL column sequence");
                if(c<8)begin
                    if(kind!==8'h21||payload[87:80]!==c[7:0]||payload[75:72]!==input_file[3:0])
                        $fatal(1,"TEST_FAIL chunk metadata");
                    for(b=0;b<8;b=b+1)begin
                        expected=pattern==0 ? (c*8+b==7 ? 8'd220 : 8'd0) :
                            pattern==1 ? c*8+b+20 : (c*8+b==63 ? 8'd255 : 8'd0);
                        if(payload[63-b*8 -: 8]!==expected)
                            $fatal(1,"TEST_FAIL bank %0d bin %0d got %0d expected %0d",
                                sequence_id,c*8+b,payload[63-b*8 -: 8],expected);
                    end
                end else if(kind!==8'h22||payload[83:80]!==input_file[3:0])
                    $fatal(1,"TEST_FAIL final metadata");
                ready=1;@(negedge clk);ready=0;
            end
        end
    endtask
    initial begin
        repeat(3)@(negedge clk);rst=0;

        emit(7,16'd1600);emit(7,16'd3520);emit(7,16'd2400);spec=0;
        due();done=1;@(negedge clk);done=0;wait(request);

        @(negedge clk);start=1;file_id=2;@(negedge clk);start=0;
        for(i=0;i<64;i=i+1)emit(i,(i+20)*16);
        spec=0;drain(1,1,0);
        due();done=1;@(negedge clk);done=0;drain(2,2,1);

        start=1;file_id=3;@(negedge clk);start=0;due();
        emit(63,16'hffff);spec=0;done=1;@(negedge clk);done=0;drain(3,3,2);
        $display("TEST_PASS spectrum RAM forwarding, stall stability, file isolation, bank reuse, final bin");
        $finish;
    end
    initial begin #1000000;$fatal(1,"TEST_FAIL spectrum bank timeout");end
endmodule
