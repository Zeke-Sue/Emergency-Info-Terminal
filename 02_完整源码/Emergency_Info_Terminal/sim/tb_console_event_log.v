`timescale 1ns/1ps
module tb_console_event_log;
    reg clk=0,rst=1,ms_tick=0,ack=0,telemetry=0;
    reg restore_valid=0,program_done=0;always #5 clk=~clk;
    wire append,append_ready;wire [1:0] category;wire [5:0] flags;
    wire [15:0] bboot,dropped;wire [31:0] bms,aboot,aus,uptime;
    wire [7:0] event_type;wire [55:0] payload;
    wire pvalid,committed;wire [23:0] paddr;wire [7:0] pdata;
    wire [15:0] next_sequence;wire [7:0] slot;
    reg [7:0] capture [0:71];integer count=0;
    console_event_log_manager manager(.clk(clk),.rst(rst),.ms_tick(ms_tick),
        .b_boot(16'h12),.a_boot(32'h3456),.ack_valid(ack),.ack_result(4'h3),
        .ack_session(32'h11223344),.ack_sequence(32'h55667788),
        .heartbeat_valid(1'b0),.heartbeat_alarm(1'b0),.heartbeat_level(3'd0),
        .heartbeat_active_count(4'd0),.heartbeat_blocked_set(8'd0),
        .telemetry_valid(telemetry),.telemetry_last_line(16'h10),
        .telemetry_max_line(16'h20),.telemetry_video_underflows(16'h30),
        .telemetry_uart_errors(16'h40),.latency_valid(1'b0),
        .pixel_latency_us(24'd0),.audio_latency_us(24'd0),
        .finish_valid(1'b0),.finish_reason(4'd0),.admission_valid(1'b0),
        .admission_pass(1'b0),.admission_reason(4'd0),.admission_purpose(8'd0),
        .admission_length(32'd0),.admission_version(16'd0),
        .append_ready(append_ready),.append_valid(append),.category(category),
        .flags(flags),.log_b_boot(bboot),.log_b_ms(bms),.log_a_boot(aboot),
        .log_a_us(aus),.event_type(event_type),.payload(payload),
        .dropped_count(dropped),.uptime_ms(uptime));
    console_log_journal journal(.clk(clk),.rst(rst),.append_valid(append),
        .append_ready(append_ready),.category(category),.flags(flags),
        .b_boot(bboot),.b_ms(bms),.a_boot(aboot),.a_us(aus),
        .event_type(event_type),.payload(payload),.program_valid(pvalid),
        .program_ready(1'b1),.program_address(paddr),.program_data(pdata),
        .program_done(program_done),.program_error(1'b0),
        .restore_valid(restore_valid),.restore_next_sequence(16'd0),
        .restore_write_slot(8'd0),.committed_pulse(committed),
        .next_sequence(next_sequence),.write_slot(slot),.failed_pulse());
    always @(posedge clk)begin
        program_done<=0;
        if(pvalid)begin
            capture[count]=pdata;count=count+1;
            if(count==36||count==72)program_done<=1;
        end
    end
    task pulse_ack;begin @(negedge clk);ack=1;@(negedge clk);ack=0;end endtask
    task pulse_telemetry;begin @(negedge clk);telemetry=1;@(negedge clk);telemetry=0;end endtask
    task fail;input [8*100-1:0] msg;begin
        $display("TEST_FAIL tb_console_event_log: %0s",msg);$finish;end endtask
    initial begin
        repeat(4)@(negedge clk);rst=0;
        @(negedge clk);restore_valid=1;@(negedge clk);restore_valid=0;
        pulse_ack;wait(committed);
        pulse_telemetry;wait(next_sequence==2);#1;
        if(count!=72||capture[20]!=8'h81||capture[56]!=8'h91)
            fail("event mux or record layout");
        if(next_sequence!=2||slot!=2||dropped!=0)fail("journal accounting");
        $display("TEST_PASS tb_console_event_log protocol event mux and committed journal records");
        $finish;
    end
    initial begin #200000;fail("timeout");end
endmodule
