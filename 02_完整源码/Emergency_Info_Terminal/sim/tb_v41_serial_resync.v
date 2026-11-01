`timescale 1ns/1ps
module tb_v41_serial_resync #(parameter CERTIFICATE_COUNT=10,SINGLE_CARD=0);
    localparam CLK_HZ=1000000,BAUD=100000;
    reg clk=0,rst=1,heartbeat=0,force_sync=0,frame_tick=0;
    always #5 clk=~clk;
    reg [31:0] boot=32'h17,parameters=32'h11223344;
    reg [63:0] event_state=64'h0123456789abcdef;
    reg [7:0] blocked=8'h24;
    reg [95:0] certificate={3'd0,16'h0402,4'd0,1'b1,
        32'h43658702,32'd80,8'h21};
    reg certificate_update=0;reg [3:0] certificate_update_index=0;
    reg [3:0] certificate_lookup_index=0;
    wire msg_valid,msg_ready,msg_last,resync_active,resync_done;
    wire [7:0] msg_type;wire [15:0] msg_batch;wire [95:0] msg_payload;
    v41_resync_sender #(.CERTIFICATE_COUNT(CERTIFICATE_COUNT),.ENABLE_CERTIFICATES(!SINGLE_CARD)) sender(.clk(clk),.rst(rst),.heartbeat_valid(heartbeat),
        .remote_boot_count(boot),.force_resync(force_sync),.parameters(parameters),
        .event_state(event_state),.blocked_set(blocked),
        .certificate_update_valid(certificate_update),
        .certificate_update_index(certificate_update_index),
        .certificate_update(certificate),
        .msg_valid(msg_valid),.msg_ready(msg_ready),.msg_type(msg_type),
        .msg_batch(msg_batch),.msg_payload(msg_payload),.msg_last(msg_last),
        .resync_active(resync_active),.resync_done(resync_done));
    wire frame_byte_valid,frame_byte_ready;wire [7:0] frame_byte;
    v41_record_framer framer(.clk(clk),.rst(rst),.msg_valid(msg_valid),
        .msg_ready(msg_ready),.msg_type(msg_type),.msg_batch(msg_batch),
        .msg_payload(msg_payload),.msg_last(msg_last),.byte_valid(frame_byte_valid),
        .byte_ready(frame_byte_ready),.byte_data(frame_byte));
    wire serial;
    reg corrupt=0;
    uart_tx_8n1 #(.CLK_HZ(CLK_HZ),.BAUD(BAUD)) tx(.clk(clk),.rst(rst),
        .data(frame_byte^(corrupt&&framer.position==framer.final_position ? 8'h01 : 8'h00)),.valid(frame_byte_valid),.ready(frame_byte_ready),.tx(serial));
    wire [7:0] rx_byte;wire rx_valid,framing_error;
    uart_rx_8n1 #(.CLK_HZ(CLK_HZ),.BAUD(BAUD)) rx(.clk(clk),.rst(rst),
        .rx(serial),.data(rx_byte),.valid(rx_valid),.framing_error(framing_error));
    wire command_valid;wire service_valid,service_last,parse_frame_error,crc_error;
    wire [7:0] service_type;wire [15:0] service_batch;wire [95:0] service_payload;
    uart_protocol_parser #(.CLK_HZ(CLK_HZ),.INTERBYTE_US(5000),.CERTIFICATE_COUNT(CERTIFICATE_COUNT),.SINGLE_CARD_CONTROL(SINGLE_CARD)) parser(
        .clk(clk),.rst(rst),.byte_valid(rx_valid),.byte_data(rx_byte),.us_tick(1'b1),
        .command_valid(command_valid),.service_valid(service_valid),
        .service_type(service_type),.service_batch(service_batch),
        .service_payload(service_payload),.service_last(service_last),
        .frame_error(parse_frame_error),.crc_error(crc_error));
    wire [31:0] active_parameters;wire [63:0] active_event;
    wire [7:0] active_blocked;wire [95:0] active_certificate;
    wire [15:0] active_certificate_valid_bitmap;
    wire state_valid,apply_pulse,batch_error;wire [15:0] active_batch;
    v41_resync_receiver #(.CERTIFICATE_COUNT(CERTIFICATE_COUNT),.ENABLE_CERTIFICATES(!SINGLE_CARD)) receiver(.clk(clk),.rst(rst),.frame_tick(frame_tick),
        .msg_valid(service_valid),.msg_type(service_type),.msg_batch(service_batch),
        .msg_payload(service_payload),.msg_last(service_last),
        .certificate_lookup_index(certificate_lookup_index),
        .active_parameters(active_parameters),.active_event(active_event),
        .active_blocked(active_blocked),.active_certificate(active_certificate),
        .active_certificate_valid_bitmap(active_certificate_valid_bitmap),
        .state_valid(state_valid),.apply_pulse(apply_pulse),
        .batch_error(batch_error),.active_batch(active_batch));
    integer records=0;
    integer slot;
    reg [95:0] expected_certificate;
    wire [15:0] expected_bitmap=((16'h0001<<CERTIFICATE_COUNT)-1)&16'hfdff;
    wire allowed;
    audio_play_permission #(.TIMEOUT_FRAMES(5)) permit(.clk(clk),.rst(rst),.frame_tick(frame_tick),
        .snapshot_apply(apply_pulse),.parameters(active_parameters),.allowed(allowed));
    task tick;begin
        @(negedge clk);frame_tick=1;@(negedge clk);frame_tick=0;
        repeat(3)@(negedge clk);
    end endtask
    task single_snapshot;input [31:0] value;integer before_count;begin
        before_count=records;
        @(negedge clk);parameters=value;force_sync=1;@(negedge clk);force_sync=0;
        wait(records==before_count+3);wait(receiver.commit_ready);
        tick();
        if(active_parameters!=value||active_event!=event_state||active_blocked!=blocked||
            active_certificate_valid_bitmap!=0||active_certificate!=0)
            fail("single-card control snapshot or fabricated certificate");
    end endtask
    always @(posedge clk)if(service_valid)records<=records+1;
    task fail;input [8*100-1:0] msg;begin
        $display("TEST_FAIL tb_v41_serial_resync: %0s",msg);$finish;end endtask
    initial begin
        repeat(8)@(negedge clk);rst=0;
        if(SINGLE_CARD)begin
            if(allowed)fail("permission present at boot");
            single_snapshot(32'h00000001);
            if(allowed)fail("legacy control granted permission");
            single_snapshot(32'ha6100001);
            if(!allowed)fail("single-card control did not grant permission");
            repeat(4)tick();if(!allowed)fail("lease expired too early");
            single_snapshot(32'ha6100001);if(!allowed)fail("refresh failed");
            repeat(5)tick();if(allowed)fail("disconnect did not expire permission");
            single_snapshot(32'ha6100001);if(!allowed)fail("reconnect failed");
            single_snapshot(32'ha6100000);if(allowed)fail("explicit revoke failed");
            corrupt=1;parameters=32'ha6100001;force_sync=1;
            @(negedge clk);force_sync=0;
            repeat(25000)@(negedge clk);tick();
            if(allowed||records!=15)fail("bad UART CRC granted permission");
            corrupt=0;single_snapshot(32'ha6100001);if(!allowed)fail("CRC recovery failed");
            rst=1;@(negedge clk);if(allowed)fail("reset retained permission");
            $display("TEST_PASS single-card UART atomic controls, no certificates, profile marker, revoke, lease, reconnect and CRC");$finish;
        end
        for(slot=0;slot<CERTIFICATE_COUNT;slot=slot+1)begin
            @(negedge clk);certificate_update=slot!=9;
            certificate_update_index=slot;certificate[7:0]=8'h21+slot;
            certificate[71:40]=32'h43658702+slot;
            @(negedge clk);certificate_update=0;
        end
        @(negedge clk);heartbeat=1;@(negedge clk);heartbeat=0;
        wait(records==CERTIFICATE_COUNT+3);repeat(8)@(posedge clk);#1;
        if(state_valid||active_parameters!=0)fail("partial serial batch became active");
        while(!receiver.commit_ready)@(negedge clk);
        @(negedge clk);frame_tick=1;@(posedge clk);#1;
        if(!apply_pulse||!state_valid||active_parameters!=parameters||
                active_event!=event_state||active_blocked!=blocked||
                active_batch!=1||active_certificate_valid_bitmap!=expected_bitmap)begin
            $display("serial mismatch apply=%b state=%b params=%h event=%h blocked=%h cert=%h expected=%h batch=%h bitmap=%h records=%0d",
                apply_pulse,state_valid,active_parameters,active_event,
                active_blocked,active_certificate,certificate,active_batch,
                active_certificate_valid_bitmap,records);
            fail("serial batch contents or atomic apply");
        end
        @(negedge clk);frame_tick=0;
        if(command_valid||framing_error||parse_frame_error||crc_error||batch_error)
            fail("serial protocol error");
        certificate_lookup_index=9;#1;
        if(active_certificate!=0)fail("empty certificate slot became valid");
        for(slot=0;slot<CERTIFICATE_COUNT;slot=slot+1)begin
            @(negedge clk);certificate_lookup_index=slot;
            repeat(9)@(negedge clk);
            expected_certificate=certificate;expected_certificate[7:0]=8'h21+slot;
            expected_certificate[71:40]=32'h43658702+slot;
            if(slot==9)expected_certificate=0;
            if(active_certificate!==expected_certificate)fail("certificate slot contents");
        end
        $display("TEST_PASS tb_v41_serial_resync %0d certificate slots and frame-atomic serial apply",CERTIFICATE_COUNT);
        $finish;
    end
    initial begin #20000000;fail("timeout");end
endmodule

module tb_v41_serial_resync12;
    tb_v41_serial_resync #(.CERTIFICATE_COUNT(12)) test();
endmodule

module tb_v41_serial_resync15;
    tb_v41_serial_resync #(.CERTIFICATE_COUNT(15)) test();
endmodule

module tb_single_card_serial;
    tb_v41_serial_resync #(.CERTIFICATE_COUNT(15),.SINGLE_CARD(1)) test();
endmodule
