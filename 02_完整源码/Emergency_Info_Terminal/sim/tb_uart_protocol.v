`timescale 1ns/1ps
module tb_uart_protocol;
    reg clk=0,rst=1,byte_valid=0,us_tick=0;reg [7:0] byte_data=0;
    always #5 clk=~clk;
    wire command_valid,frame_error,crc_error;wire [2:0] opcode,kind,level,region;
    wire [1:0] source;wire [15:0] event_id,remaining;wire [7:0] sequence;
    wire drill,pending,time_trusted;wire [31:0] session,message_sequence;
    uart_protocol_parser dut(.clk(clk),.rst(rst),.byte_valid(byte_valid),.byte_data(byte_data),.us_tick(us_tick),
        .command_valid(command_valid),.command_opcode(opcode),.command_source(source),.command_kind(kind),
        .command_event_id(event_id),.command_sequence(sequence),.command_level(level),.command_drill(drill),
        .command_pending(pending),.command_region(region),.command_time_trusted(time_trusted),
        .command_remaining_seconds(remaining),.command_session(session),.command_message_sequence(message_sequence),
        .frame_error(frame_error),.crc_error(crc_error));
    function [15:0] crc_next;input [15:0] current;input [7:0] value;integer b;reg [15:0] w;
        begin w=current^{value,8'h00};for(b=0;b<8;b=b+1)w=w[15]?(w<<1)^16'h1021:w<<1;crc_next=w;end endfunction
    task fail;input [8*100-1:0] reason;begin $display("TEST_FAIL tb_uart_protocol: %0s",reason);$finish;end endtask
    task send;input [7:0] value;begin @(negedge clk);byte_data=value;byte_valid=1;@(negedge clk);byte_valid=0;end endtask
    reg [15:0] crc;integer seen,commands=0,errors=0;
    always @(posedge clk)if(!rst)begin
        if(command_valid)commands<=commands+1;
        if(frame_error)errors<=errors+1;
    end
    task send_checked;input [7:0] value;begin crc=crc_next(crc,value);send(value);end endtask
    task cancel_frame;
        input [7:0] version,origin;
        begin
            crc=16'hffff;send(8'ha5);send(8'h5a);
            send_checked(version);send_checked(8'h02);send_checked(origin);
            send_checked(0);send_checked(0);send_checked(0);send_checked(1);
            send_checked(0);send_checked(0);send_checked(0);send_checked(2);
            send_checked(2);send_checked(8'h12);send_checked(8'h34);
            send(crc[15:8]);send(crc[7:0]);repeat(2)@(negedge clk);
        end
    endtask
    initial begin
        repeat(3)@(negedge clk);rst=0;crc=16'hffff;seen=0;
        send(8'ha5);send(8'h5a);
        send_checked(1);send_checked(8'h01);send_checked(2);
        send_checked(8'h11);send_checked(8'h22);send_checked(8'h33);send_checked(8'h44);
        send_checked(8'h00);send_checked(8'h00);send_checked(8'h00);send_checked(8'h07);
        send_checked(9);
        send_checked(8'h12);send_checked(8'h34);send_checked(8'h05);send_checked(8'h02);
        send_checked(8'b00000101);send_checked(8'h06);send_checked(8'h00);send_checked(8'h0c);send_checked(8'h00);
        send(crc[15:8]);send(crc[7:0]);#1;
        if(!command_valid||opcode!=0||source!=2||event_id!=16'h1234||sequence!=5||level!=2||!drill||pending||!time_trusted||region!=6||remaining!=12)fail("decoded warning fields");
        crc=16'hffff;send(8'ha5);send(8'h5a);send_checked(1);send_checked(8'h02);send_checked(1);
        send_checked(0);send_checked(0);send_checked(0);send_checked(1);send_checked(0);send_checked(0);send_checked(0);send_checked(2);send_checked(2);
        send_checked(8'h12);send_checked(8'h34);send(8'h00);send(8'h00);#1;
        if(!crc_error)fail("bad CRC accepted");
        cancel_frame(2,1);
        cancel_frame(1,8'h81);
        if(commands!=1 || errors!=2)fail("CRC-correct unsupported version/source accepted");
        cancel_frame(1,1);
        if(commands!=2 || opcode!=1 || event_id!=16'h1234)fail("parser did not recover after rejected headers");
        $display("TEST_PASS tb_uart_protocol header/payload decode, CRC/version/source rejection and subsequent valid recovery");$finish;
    end
    initial begin #200000;fail("timeout");end
endmodule
