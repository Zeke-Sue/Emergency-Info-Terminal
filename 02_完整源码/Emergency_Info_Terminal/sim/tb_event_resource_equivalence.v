`timescale 1ns/1ps
module tb_event_resource_equivalence;
    reg clk=0,rst=1,frame_tick=0,cmd_valid=0,sync_valid=0;
    reg [31:0] now_seconds=0;
    reg [2:0] opcode=0,kind=0,level=1,region=0;
    reg [1:0] source=0;
    reg [15:0] id=0,remaining=0;
    reg [7:0] sequence=0,sync_set=0;
    reg drill=0,pending=0,trusted=0;
    wire [79:0] actual,reference;
    integer n,clocks=0,wait_clocks,writes=0,results=0;
    integer result_counts[0:5];
    reg [31:0] random_state=32'h4b1026e3;
    always #5 clk=~clk;
    event_manager #(.CANCEL_FRAMES(19)) dut(
        .clk(clk),.rst(rst),.frame_tick(frame_tick),.now_seconds(now_seconds),
        .cmd_valid(cmd_valid),.cmd_opcode(opcode),.cmd_source(source),.cmd_kind(kind),
        .cmd_event_id(id),.cmd_sequence(sequence),.cmd_level(level),.cmd_drill(drill),
        .cmd_pending(pending),.cmd_region(region),.cmd_time_trusted(trusted),
        .cmd_remaining_seconds(remaining),.sync_blocked_valid(sync_valid),.sync_blocked_set(sync_set),
        .cmd_ready(actual[79]),.result_valid(actual[78]),.result_code(actual[77:74]),
        .primary_valid(actual[73]),.primary_source(actual[72:71]),.primary_kind(actual[70:68]),
        .primary_event_id(actual[67:52]),.primary_sequence(actual[51:44]),
        .primary_level(actual[43:41]),.primary_drill(actual[40]),.primary_pending(actual[39]),
        .primary_time_trusted(actual[38]),.primary_remaining_seconds(actual[37:22]),
        .primary_region(actual[21:19]),.active_count(actual[18:15]),
        .tombstone_count(actual[14:10]),.blocked_set(actual[9:2]),.cancel_notice(actual[1]),
        .full_urgent(actual[0]));
    event_manager_reference #(.CANCEL_FRAMES(19)) old(
        .clk(clk),.rst(rst),.frame_tick(frame_tick),.now_seconds(now_seconds),
        .cmd_valid(cmd_valid),.cmd_opcode(opcode),.cmd_source(source),.cmd_kind(kind),
        .cmd_event_id(id),.cmd_sequence(sequence),.cmd_level(level),.cmd_drill(drill),
        .cmd_pending(pending),.cmd_region(region),.cmd_time_trusted(trusted),
        .cmd_remaining_seconds(remaining),.sync_blocked_valid(sync_valid),.sync_blocked_set(sync_set),
        .cmd_ready(reference[79]),.result_valid(reference[78]),.result_code(reference[77:74]),
        .primary_valid(reference[73]),.primary_source(reference[72:71]),.primary_kind(reference[70:68]),
        .primary_event_id(reference[67:52]),.primary_sequence(reference[51:44]),
        .primary_level(reference[43:41]),.primary_drill(reference[40]),.primary_pending(reference[39]),
        .primary_time_trusted(reference[38]),.primary_remaining_seconds(reference[37:22]),
        .primary_region(reference[21:19]),.active_count(reference[18:15]),
        .tombstone_count(reference[14:10]),.blocked_set(reference[9:2]),.cancel_notice(reference[1]),
        .full_urgent(reference[0]));
    task fail;input [8*100-1:0] msg;begin
        $display("TEST_FAIL event equivalence: %0s command=%0d clock=%0d actual=%h reference=%h",
            msg,n,clocks,actual,reference);$finish;end endtask
    always @(posedge clk)begin
        clocks=clocks+1;
        if(!rst)begin
            if(dut.mem_we!==old.mem_we)fail("RAM write strobe changed");
            if(dut.mem_we)begin
                if(dut.mem_wa!==old.mem_wa||dut.mem_wd!==old.mem_wd)
                    fail("RAM address/data changed");
                writes=writes+1;
            end
        end
        #1;
        if(actual!==reference)fail("cycle-visible contract changed");
        if(!rst&&actual[78])begin
            results=results+1;
            if(actual[77:74]<6)result_counts[actual[77:74]]=result_counts[actual[77:74]]+1;
        end
    end
    always @(negedge clk)begin
        frame_tick=!rst&&clocks%233==0;
        sync_valid=!rst&&clocks%1597==0;sync_set=clocks>>7;
    end
    task transact;
        begin
            @(negedge clk);
            wait_clocks=0;
            while(!actual[79]&&wait_clocks<1000)begin @(negedge clk);wait_clocks=wait_clocks+1;end
            if(!actual[79])fail("ready timeout");
            cmd_valid=1;@(negedge clk);cmd_valid=0;
            wait_clocks=0;
            while(!actual[78]&&wait_clocks<1000)begin @(negedge clk);wait_clocks=wait_clocks+1;end
            if(!actual[78])fail("result timeout");
            repeat(2)@(negedge clk);
        end
    endtask
    initial begin
        for(n=0;n<6;n=n+1)result_counts[n]=0;
        repeat(3)@(negedge clk);rst=0;

        for(n=0;n<9;n=n+1)begin id=n;sequence=7;transact;end
        id=0;sequence=7;transact;sequence=6;transact;
        opcode=1;transact;opcode=0;sequence=8;transact;
        opcode=2;id=15;transact;
        opcode=5;transact;
        for(n=0;n<10000;n=n+1)begin
            random_state={random_state[30:0],random_state[31]^random_state[21]^random_state[1]^random_state[0]};
            opcode=n%701==0 ? 5 : (random_state[2:0]<4 ? 0 :
                random_state[2:0]==7 ? 7 : random_state[2:0]-3);
            source=random_state[4:3];kind=random_state[6:5]%3;
            level=random_state[8:7]+1;id=random_state[12:9];
            sequence=random_state[20:13];region=random_state[23:21];
            drill=random_state[24];pending=random_state[25];trusted=random_state[26];
            remaining=n%17==0 ? 16'hffff : random_state[31:27];
            if(n%31==0)now_seconds=now_seconds+77;
            if(n==4999)now_seconds=32'hfffff800;
            transact;
            if(n%997==996)begin
                @(negedge clk);rst=1;repeat(3)@(negedge clk);rst=0;
            end
        end
        repeat(600)@(negedge clk);
        for(n=0;n<6;n=n+1)if(result_counts[n]==0)fail("missing result-code coverage");
        $display("TEST_PASS event resource equivalence: %0d commands/results, %0d cycles, %0d RAM writes, all six result codes, expiry/cancel/reset/wrap, seed 4b1026e3",
            results,clocks,writes);$finish;
    end
    initial begin #100000000;fail("bounded timeout");end
endmodule
