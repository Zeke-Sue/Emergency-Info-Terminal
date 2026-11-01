`timescale 1ns/1ps
module tb_status_framer_stable_session;
    reg clk=0,rst=1;
    always #5 clk=~clk;
    reg request=0,byte_ready=0;
    reg [31:0] session=32'hb1234567,sequence=0,random_state=32'h12345678;
    reg [95:0] payload=0;
    reg [7:0] message_type=8'h26;
    wire ready_ref,ready_opt,valid_ref,valid_opt;
    wire [7:0] byte_ref,byte_opt;
    integer packet,bytes=0,total=0;
    console_status_framer #(.DYNAMIC_TYPE(1),.EXTERNAL_IDENTITY(1)) reference(
        .clk(clk),.rst(rst),.request_valid(request),.request_ready(ready_ref),
        .request_payload(payload),.request_type(message_type),
        .request_session(session),.request_sequence(sequence),
        .byte_valid(valid_ref),.byte_ready(byte_ready),.byte_data(byte_ref));
    console_status_framer #(.DYNAMIC_TYPE(1),.EXTERNAL_IDENTITY(1),
        .STABLE_EXTERNAL_SESSION(1)) optimized(
        .clk(clk),.rst(rst),.request_valid(request),.request_ready(ready_opt),
        .request_payload(payload),.request_type(message_type),
        .request_session(session),.request_sequence(sequence),
        .byte_valid(valid_opt),.byte_ready(byte_ready),.byte_data(byte_opt));
    task fail;input [8*100-1:0] reason;begin
        $display("TEST_FAIL stable session framer: %0s",reason);$fatal;
    end endtask
    always @(posedge clk)if(!rst)begin
        if(ready_ref!==ready_opt||valid_ref!==valid_opt)
            fail("handshake differs from captured-session reference");
        if(valid_ref&&byte_ref!==byte_opt)fail("wire bytes/CRC differ");
        if(valid_opt&&byte_ready)begin bytes=bytes+1;total=total+1;end
    end
    always @(negedge clk)begin
        random_state={random_state[30:0],random_state[31]^random_state[21]^random_state[1]^random_state[0]};
        byte_ready=random_state[0]|random_state[3];
    end
    initial begin
        repeat(4)@(negedge clk);#1;rst=0;
        for(packet=0;packet<512;packet=packet+1)begin
            if(packet==256)begin
                @(negedge clk);#1;rst=1;session=32'h81234568;
                repeat(3)@(negedge clk);#1;rst=0;
            end
            wait(ready_opt);@(negedge clk);#1;
            bytes=0;request=1;sequence=packet;
            payload={random_state,~random_state,32'h76543210^packet};
            @(negedge clk);#1;request=0;

            while(!ready_opt)begin
                payload=payload+1'b1;sequence=sequence+1'b1;message_type=message_type+1'b1;
                @(negedge clk);#1;
            end
            if(bytes!=28)fail("packet length");
        end
        $display("TEST_PASS stable session framer 512 packets, %0d bytes, backpressure and reset",total);
        $finish;
    end
    initial begin #2000000;fail("timeout");end
endmodule
