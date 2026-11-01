`timescale 1ns/1ps
module tb_n10_route_link;
    reg clk=0,rst=1,refresh=0;
    always #5 clk=~clk;
    wire request,request_ready;wire [7:0] kind;wire [95:0] payload;
    wire generator_busy,generator_error;
    n10_route_packetizer generator(.clk(clk),.rst(rst),.refresh(refresh),
        .request_valid(request),.request_ready(request_ready),.request_type(kind),
        .request_payload(payload),.busy(generator_busy),.error(generator_error));
    wire byte_valid,byte_ready;wire [7:0] byte_data;
    console_status_framer #(.DYNAMIC_TYPE(1)) framer(.clk(clk),.rst(rst),
        .request_valid(request),.request_ready(request_ready),.request_payload(payload),
        .request_type(kind),.byte_valid(byte_valid),.byte_ready(byte_ready),.byte_data(byte_data));
    integer fault_mode=0;
    wire [7:0] wire_byte=byte_data^((fault_mode==5&&framer.message_type==8'h24&&
        framer.payload[79:72]==37&&framer.position==14) ? 8'd1 : 8'd0);
    wire serial,rx_valid,framing_error;wire [7:0] rx_byte;
    uart_tx_8n1 #(.CLK_HZ(1000000),.BAUD(100000)) tx(.clk(clk),.rst(rst),
        .data(wire_byte),.valid(byte_valid),.ready(byte_ready),.tx(serial));
    uart_rx_8n1 #(.CLK_HZ(1000000),.BAUD(100000)) rx(.clk(clk),.rst(rst),
        .rx(serial),.data(rx_byte),.valid(rx_valid),.framing_error(framing_error));
    wire service_valid,parse_error,crc_error;wire [7:0] service_type;wire [95:0] service_payload;
    uart_protocol_parser parser(.clk(clk),.rst(rst),.byte_valid(rx_valid),.byte_data(rx_byte),
        .us_tick(1'b0),.service_valid(service_valid),.service_type(service_type),
        .service_payload(service_payload),.frame_error(parse_error),.crc_error(crc_error));
    reg [95:0] delivered;
    always @* begin
        delivered=service_payload;
        if(fault_mode==2&&service_type==8'h25)delivered[32]=~service_payload[32];
        if(fault_mode==3&&service_type==8'h23)delivered[80]=~service_payload[80];
        if(fault_mode==4&&service_type==8'h23)delivered[32]=~service_payload[32];
        if(fault_mode==6&&service_type==8'h24&&service_payload[79:72]==37)delivered[79:72]=38;
    end
    reg auto_frames=1,manual_frame=0;
    reg [9:0] frame_clock=0;
    always @(posedge clk)frame_clock<=frame_clock==999 ? 10'd0 : frame_clock+1'b1;
    wire frame=auto_frames ? frame_clock==999 : manual_frame;
    wire write,commit,cfg_ready,batch_error;wire [7:0] key;
    wire [31:0] segments,directions,table_crc;wire [2:0] exit_id;wire [1:0] status;
    wire [15:0] version;
    n10_route_receiver receiver(.clk(clk),.rst(rst),.frame_tick(frame),
        .message_valid(service_valid&&!(fault_mode==7&&service_type!=8'h23)),
        .message_type(service_type),.payload(delivered),
        .cfg_ready(cfg_ready),.cfg_write(write),.cfg_key(key),.cfg_segments(segments),
        .cfg_directions(directions),.cfg_exit(exit_id),.cfg_status(status),
        .cfg_commit(commit),.batch_error(batch_error),.cfg_version(version),.cfg_crc32(table_crc));
    reg [7:0] blocked=0;
    wire route_valid;wire [31:0] selected_segments,selected_directions,active_crc;
    wire [2:0] selected_exit;wire [1:0] selected_status;wire [15:0] active_version;
    n10_route_engine table_store(.clk(clk),.rst(rst),.frame_tick(frame),.cfg_ready(cfg_ready),
        .cfg_write(write),.cfg_blocked_key(key),.cfg_segment_mask(segments),.cfg_direction_mask(directions),
        .cfg_exit(exit_id),.cfg_status(status),.cfg_commit(commit),.cfg_crc_ok(commit),.cfg_checked(commit),
        .cfg_assets_match(commit),.cfg_version(version),.cfg_crc32(table_crc),.blocked_set(blocked),
        .pixel_valid(1'b0),.segment_id(6'd0),.segment_phase(8'd0),.blocked_exit_pixel(1'b0),.flash_on(1'b0),
        .route_valid(route_valid),.selected_segment_mask(selected_segments),
        .selected_direction_mask(selected_directions),.selected_exit(selected_exit),.selected_status(selected_status),
        .active_version(active_version),.active_crc32(active_crc));
    reg [71:0] expected[0:255];
    integer sent=0,received_end=0,commits=0,errors=0,wire_errors=0,j,b;
    reg [31:0] first_crc;
    always @(posedge clk)begin
        if(request&&request_ready&&kind==8'h24&&sent==0)expected[payload[79:72]]=payload[71:0];
        if(request&&request_ready&&kind==8'h25)sent=sent+1;
        if(service_valid&&service_type==8'h25)received_end=received_end+1;
        if(commit)commits=commits+1;
        if(batch_error)errors=errors+1;
        if(crc_error)wire_errors=wire_errors+1;
        if(!rst&&(generator_error||framing_error||parse_error))begin
            $display("TEST_FAIL graph serial generator/frame error");$finish;end
    end
    task query_table;
        begin
            auto_frames=0;
            for(j=0;j<256;j=j+1)begin
                @(negedge clk);blocked=j;manual_frame=1;
                @(negedge clk);manual_frame=0;repeat(2)@(negedge clk);
                if({3'd0,selected_status,selected_exit,selected_directions,selected_segments}!==expected[j])begin
                    $display("TEST_FAIL serial route lookup key=%d",j);$finish;end
            end
            auto_frames=1;
        end
    endtask
    task await_end;
        input integer wanted;
        begin
            while(received_end<wanted)@(negedge clk);
            repeat(2000)@(negedge clk);
        end
    endtask
    initial begin
        repeat(5)@(negedge clk);rst=0;
        while(sent==0)begin @(negedge clk);if(route_valid)begin $display("TEST_FAIL partial table visible");$finish;end end
        await_end(1);
        if(!route_valid||commits!=1||errors||active_version!=16'h5001)begin
            $display("TEST_FAIL first route batch c=%d e=%d version=%h",commits,errors,active_version);$finish;end
        first_crc=active_crc;query_table();
        for(b=2;b<=7;b=b+1)begin
            fault_mode=b;@(negedge clk);refresh=1;@(negedge clk);refresh=0;
            await_end(b);
            if(commits!=1||active_crc!=first_crc||!route_valid)begin
                $display("TEST_FAIL corrupt/incomplete batch replaced live table mode=%d",b);$finish;end
            query_table();
        end
        fault_mode=0;@(negedge clk);refresh=1;@(negedge clk);refresh=0;
        await_end(8);query_table();
        if(commits!=2||wire_errors!=1||errors<6)begin
            $display("TEST_FAIL route recovery counts %d/%d/%d",commits,wire_errors,errors);$finish;end
        $display("TEST_PASS B graph -> UART/CRC16 -> A CRC32/banked table, 256 entries, corruption/loss/order/version/timeout rejection and recovery");$finish;
    end
    initial begin #200000000;$display("TEST_FAIL graph link timeout");$finish;end
endmodule
