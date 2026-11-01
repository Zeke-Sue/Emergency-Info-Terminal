`timescale 1ns/1ps
module tb_spectrum_uart;
    reg bclk=0,aclk=0,rst=1,sample=0,spec=0,done=0,frame=0;
    always #10 bclk=~bclk;
    always #20 aclk=~aclk;
    reg [5:0] bin=0;
    reg [15:0] magnitude=0;
    wire request,request_ready,tx_valid,tx_ready,serial,rx_valid,framing_error;
    wire [7:0] kind,tx_byte,rx_byte;
    wire [95:0] data;
    integer tx_position=0,tx_packet=0,crc_errors=0,services=0;
    wire corrupt=tx_packet==3 && tx_position==18;
    spectrum_packetizer source(.clk(bclk),.rst(rst),.file_start(1'b0),
        .sample_valid(sample),.file_index(4'd4),.spectrum_valid(spec),
        .spectrum_bin(bin),.spectrum_magnitude(magnitude),.transform_done(done),
        .peak_frequency_q8(24'd512000),.request_valid(request),.request_ready(request_ready),
        .request_type(kind),.request_payload(data));
    console_status_framer #(.DYNAMIC_TYPE(1)) framer(.clk(bclk),.rst(rst),
        .request_valid(request),.request_ready(request_ready),.request_payload(data),
        .request_type(kind),.byte_valid(tx_valid),.byte_ready(tx_ready),.byte_data(tx_byte));
    uart_tx_8n1 #(.CLK_HZ(50000000),.BAUD(250000)) tx(.clk(bclk),.rst(rst),
        .data(tx_byte^(corrupt ? 8'h01 : 8'h00)),.valid(tx_valid),.ready(tx_ready),.tx(serial));
    uart_rx_8n1 #(.CLK_HZ(25000000),.BAUD(250000)) rx(.clk(aclk),.rst(rst),
        .rx(serial),.data(rx_byte),.valid(rx_valid),.framing_error(framing_error));
    wire service,crc_error;
    wire [7:0] message_type;
    wire [95:0] payload;
    uart_protocol_parser parser(.clk(aclk),.rst(rst),.byte_valid(rx_valid),
        .byte_data(rx_byte),.us_tick(1'b0),.service_valid(service),
        .service_type(message_type),.service_payload(payload),.crc_error(crc_error));
    reg [5:0] query=0;
    wire [7:0] value;
    wire valid;
    wire [3:0] file_id;
    wire [31:0] position;
    remote_spectrum_receiver sink(.clk(aclk),.rst(rst),.frame_tick(frame),
        .message_valid(service),.message_type(message_type),.payload(payload),
        .query_age(7'd0),.query_bin(query),.query_value(value),.valid(valid),
        .file_index(file_id),.sample_position(position));
    always @(posedge bclk)if(!rst&&tx_valid&&tx_ready)begin
        if(tx_position==27)begin tx_position<=0;tx_packet<=tx_packet+1;end
        else tx_position<=tx_position+1;
    end
    always @(posedge aclk)if(!rst)begin
        if(crc_error)crc_errors=crc_errors+1;
        if(service)services=services+1;
        if(framing_error)begin $display("TEST_FAIL UART framing");$finish;end
    end
    task column;
        integer i;
        begin
            @(negedge bclk);sample=1;repeat(4800)@(negedge bclk);sample=0;
            for(i=0;i<64;i=i+1)begin
                spec=1;bin=i;magnitude=(i+10)*16;@(negedge bclk);
            end
            spec=0;done=1;@(negedge bclk);done=0;
        end
    endtask
    task commit;
        begin
            repeat(2000)@(negedge aclk);
            frame=1;@(negedge aclk);frame=0;repeat(80)@(negedge aclk);
        end
    endtask
    integer i;
    initial begin
        repeat(5)@(negedge aclk);rst=0;
        column();wait(tx_packet==9);commit();
        if(valid||crc_errors!=1)begin $display("TEST_FAIL corrupt column published");$finish;end
        column();wait(tx_packet==18);commit();
        if(!valid||file_id!=4||position!=9600||services!=17)begin
            $display("TEST_FAIL complete column metadata/services %0d",services);$finish;
        end
        for(i=0;i<64;i=i+1)begin
            query=i;repeat(2)@(posedge aclk);#1;
            if(value!=i+10)begin $display("TEST_FAIL UART spectrum bin %0d",i);$finish;end
            @(negedge aclk);
        end
        $display("TEST_PASS spectrum packetizer/framer/UART/CRC/receiver, corrupt-column rejection");$finish;
    end
    initial begin #30000000;$display("TEST_FAIL spectrum UART timeout");$finish;end
endmodule
