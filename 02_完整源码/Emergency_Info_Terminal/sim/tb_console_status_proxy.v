`timescale 1ns/1ps
module tb_console_status_proxy;
    reg clk=0,rst=1,request=0;
    always #5 clk=~clk;
    localparam [95:0] PAYLOAD={8'hd5,8'h6a,8'h93,8'h91,8'h07,8'h0a,
        8'ha5,8'h5a,8'h12,8'h34,8'h00,8'h02};
    wire request_ready,byte_valid;wire [7:0] byte_data;
    console_status_framer framer(.clk(clk),.rst(rst),.request_valid(request),
        .request_ready(request_ready),.request_payload(PAYLOAD),
        .byte_valid(byte_valid),.byte_ready(1'b1),.byte_data(byte_data));
    wire command_valid,service_valid,service_last,frame_error,crc_error;
    wire [2:0] command_opcode,command_kind,command_level,command_region;
    wire [1:0] command_source;wire [15:0] command_event_id,command_remaining;
    wire [7:0] command_sequence,service_type;wire command_drill,command_pending;
    wire command_trusted;wire [31:0] command_session,command_message_sequence;
    wire [15:0] service_batch;wire [95:0] service_payload;
    uart_protocol_parser parser(.clk(clk),.rst(rst),.byte_valid(byte_valid),
        .byte_data(byte_data),.us_tick(1'b0),.command_valid(command_valid),
        .command_opcode(command_opcode),.command_source(command_source),
        .command_kind(command_kind),.command_event_id(command_event_id),
        .command_sequence(command_sequence),.command_level(command_level),
        .command_drill(command_drill),.command_pending(command_pending),
        .command_region(command_region),.command_time_trusted(command_trusted),
        .command_remaining_seconds(command_remaining),.command_session(command_session),
        .command_message_sequence(command_message_sequence),
        .service_valid(service_valid),.service_type(service_type),
        .service_batch(service_batch),.service_payload(service_payload),
        .service_last(service_last),.frame_error(frame_error),.crc_error(crc_error));

    reg [10:0] x=0,y=0;wire [23:0] proxy_rgb;
    console_proxy_overlay overlay(.x(x),.y(y),.status_valid(1'b1),
        .status(PAYLOAD),.rgb_in(24'h123456),.rgb_out(proxy_rgb));
    initial begin
        repeat(3)@(negedge clk);rst=0;
        @(negedge clk);request=1;@(negedge clk);request=0;
        wait(service_valid);#1;
        if(service_type!=8'h20||service_payload!=PAYLOAD||!service_last||
                frame_error||crc_error||command_valid)begin
            $display("TEST_FAIL status protocol type=%h payload=%h frame=%b crc=%b",
                service_type,service_payload,frame_error,crc_error);$finish;
        end
        x=432;y=8;#1;if(proxy_rgb!=24'h35d0c8)begin
            $display("TEST_FAIL proxy border rgb=%h",proxy_rgb);$finish;end
        x=440;y=78;#1;if(proxy_rgb!=24'h45df82)begin
            $display("TEST_FAIL proxy link flag rgb=%h",proxy_rgb);$finish;end
        x=440;y=93;#1;if(proxy_rgb!=24'h45df82)begin
            $display("TEST_FAIL proxy admission bitmap rgb=%h",proxy_rgb);$finish;end
        x=100;y=100;#1;if(proxy_rgb!=24'h123456)begin
            $display("TEST_FAIL proxy leaked outside panel rgb=%h",proxy_rgb);$finish;end
        $display("TEST_PASS tb_console_status_proxy compact B-to-A semantic status and overlay");
        $finish;
    end
endmodule
