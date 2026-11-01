`timescale 1ns/1ps
module tb_p3_uart_link;
    reg clk=0,rst=1;always #5 clk=~clk;
    reg filter_valid=0;reg [1:0] source=0;reg [31:0] session=0,sequence=0;
    wire accepted,duplicate;
    uart_session_filter filter(.clk(clk),.rst(rst),.command_valid(filter_valid),
        .command_source(source),.command_session(session),.command_sequence(sequence),
        .accept_valid(accepted),.duplicate_valid(duplicate));
    reg request=0;wire request_ready,byte_valid,byte_ready,tx,rx_valid,rx_error;
    wire [7:0] byte_data,rx_data;
    uart_reply_framer framer(.clk(clk),.rst(rst),.request_valid(request),
        .request_ready(request_ready),.request_type(8'h82),.request_source(2'd2),
        .request_session(32'h11223344),.request_sequence(32'h00000007),
        .result_code(4'd0),.finish_reason(4'd0),.pixel_latency_us(24'h010203),
        .audio_latency_us(24'h040506),.alarm_active(1'b1),.alarm_level(3'd2),
        .active_count(4'd3),.blocked_set(8'ha5),.boot_count(32'd0),
        .telemetry_last_line(16'd0),.telemetry_max_line(16'd0),
        .telemetry_video_underflows(16'd0),.telemetry_uart_errors(16'd0),
        .byte_valid(byte_valid),
        .byte_ready(byte_ready),.byte_data(byte_data));
    uart_tx_8n1 #(.CLK_HZ(100),.BAUD(10)) tx0(.clk(clk),.rst(rst),
        .data(byte_data),.valid(byte_valid),.ready(byte_ready),.tx(tx));
    uart_rx_8n1 #(.CLK_HZ(100),.BAUD(10)) rx0(.clk(clk),.rst(rst),.rx(tx),
        .data(rx_data),.valid(rx_valid),.framing_error(rx_error));
    reg [7:0] captured [0:31];integer count=0,i;reg [15:0] crc;
    function [15:0] crc_next;input [15:0] current;input [7:0] value;
        integer b;reg [15:0] w;begin w=current^{value,8'h00};
        for(b=0;b<8;b=b+1)w=w[15]?(w<<1)^16'h1021:w<<1;crc_next=w;end endfunction
    task fail;input [8*100-1:0] reason;begin $display("TEST_FAIL tb_p3_uart_link: %0s",reason);$finish;end endtask
    task check_filter;input [31:0] sess;input [31:0] seq;input want_accept;
        begin @(negedge clk);session=sess;sequence=seq;filter_valid=1;
            @(negedge clk);filter_valid=0;#1;
            if(accepted!=want_accept||duplicate==want_accept)fail("session filter result");
        end endtask
    always @(posedge clk) if(rx_valid) begin captured[count]=rx_data;count=count+1;end
    initial begin
        repeat(4)@(negedge clk);rst=0;
        check_filter(32'h1,32'd1,1);check_filter(32'h1,32'd1,0);
        check_filter(32'h1,32'd0,0);check_filter(32'h1,32'd2,1);
        check_filter(32'h2,32'd0,1);
        @(negedge clk);request=1;@(negedge clk);request=0;
        wait(count==22);@(negedge clk);
        if(rx_error)fail("UART framing error");
        if(captured[0]!=8'ha5||captured[1]!=8'h5a||captured[3]!=8'h82||
           captured[4]!=2||captured[5]!=8'h11||captured[8]!=8'h44||
           captured[12]!=7||captured[13]!=6)fail("response header");
        if(captured[14]!=1||captured[15]!=2||captured[16]!=3||
           captured[17]!=4||captured[18]!=5||captured[19]!=6)fail("latency payload");
        crc=16'hffff;for(i=2;i<20;i=i+1)crc=crc_next(crc,captured[i]);
        if(captured[20]!=crc[15:8]||captured[21]!=crc[7:0])fail("response CRC");
        $display("TEST_PASS tb_p3_uart_link session replay filter, reply CRC and UART TX/RX");$finish;
    end
    initial begin #5000000;fail("timeout");end
endmodule
