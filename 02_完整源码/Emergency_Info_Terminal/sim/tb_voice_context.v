`timescale 1ns/1ps
module tb_voice_context;
    reg clk=0,rst=1,alarm=1,cancel=0,drill=0,pending=1,evac=0,ready=1;
    reg [2:0] kind=1,level=1;
    reg [15:0] seconds=12;
    reg [25:0] identity=1;
    always #5 clk=~clk;
    wire enqueue,urgent,flush;wire [5:0] segment;
    integer seen=0,n;
    reg [5:0] observed [0:31];
    reg urgent_flags [0:31];
    l0_voice_scheduler #(.ENABLE_CONTEXT(1)) dut(.clk(clk),.rst(rst),
        .alarm_active(alarm),.alarm_drill(drill),.cancel_notice(cancel),.alarm_level(level),
        .countdown_trusted(1'b1),.countdown_seconds(seconds),.enqueue_ready(ready),
        .alarm_kind(kind),.alarm_pending(pending),.alarm_evacuation(evac),.event_identity(identity),
        .enqueue_valid(enqueue),.enqueue_segment(segment),.enqueue_urgent(urgent),.cancel_queue(flush));
    always @(negedge clk)if(!rst&&enqueue)begin
        observed[seen]=segment;urgent_flags[seen]=urgent;seen=seen+1;
    end
    task fail;input [799:0] msg;begin $display("TEST_FAIL voice context: %0s seen=%0d",msg,seen);$finish;end endtask
    task settle;begin repeat(16)@(posedge clk);#1;end endtask
    initial begin
        repeat(4)@(posedge clk);#1;rst=0;
        repeat(50)@(posedge clk);#1;
        if(seen!=2||observed[0]!=23||observed[1]!=26||!urgent_flags[0])fail("startup fire lost or earthquake phrase used");
        seen=0;seconds=0;settle();if(seen!=0)fail("fire produced earthquake countdown");
        pending=0;settle();if(seen!=2||observed[1]!=24)fail("confirmed fire context");
        seen=0;ready=0;evac=1;settle();
        if(seen!=1||observed[0]!=25||!urgent_flags[0])fail("full queue blocks urgent evacuation replacement");
        seen=0;cancel=1;settle();if(seen!=1||observed[0]!=19||!urgent_flags[0])fail("full queue blocks cancellation");
        seen=0;ready=1;cancel=0;kind=0;evac=0;seconds=10;identity=2;settle();
        if(seen!=2||observed[0]!=12)fail("new event announcement");
        seen=0;seconds=0;settle();if(seen!=1||observed[0]!=18)fail("zero spoken as zero seconds instead of arrival");
        alarm=0;@(posedge clk);#1;if(!flush)fail("alarm termination did not flush queue");
        $display("TEST_PASS voice context: boot alarm, correct fire stages, full-queue urgent replace, cancellation, event identity, arrival, queue flush");$finish;
    end
    initial begin #100000;fail("timeout");end
endmodule
