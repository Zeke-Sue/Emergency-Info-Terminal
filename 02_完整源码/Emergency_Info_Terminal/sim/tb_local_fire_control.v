`timescale 1ns/1ps
module tb_local_fire_control;
    reg clk=0,rst=1,contact=0,prev=0,next=0,confirm=0,back=0,held=0;
    always #5 clk=~clk;
    wire closed,active,confirmed,evac,menu,armed,acted;
    wire [1:0] role,selection,action;
    wire [3:0] result;
    wire [15:0] version;
    wire alarm,pending,trusted,visible,route;
    wire [2:0] kind;wire [7:0] blocked;wire [3:0] count;
    local_fire_control #(.CLK_HZ(10),.DEBOUNCE_CYCLES(4),.CONFIRM_CYCLES(20),.TIMEOUT_CYCLES(100)) dut(
        .clk(clk),.rst(rst),.contact_raw(contact),.previous(prev),.next(next),
        .confirm(confirm),.back(back),.confirm_held(held),.contact_closed(closed),
        .fire_active(active),.fire_confirmed(confirmed),.evacuation(evac),
        .menu_visible(menu),.armed(armed),.role(role),.selection(selection),.result(result),
        .action_valid(acted),.action(action),.event_version(version));
    emergency_control_core #(.CLK_HZ(1000000),.REMOTE_EVENTS(1),.LOCAL_FIRE(1)) core(
        .clk(clk),.rst(rst),.frame_tick(1'b1),.first_active_pixel(1'b0),.audio_sample_tick(1'b0),
        .demo_alarm(1'b0),.local_fire_active(active),.local_fire_confirmed(confirmed),
        .local_fire_evacuation(evac),.flash_rate(2'd1),.flash_duty(2'd1),
        .command_valid(1'b0),.command_opcode(3'd0),.command_source(2'd0),.command_kind(3'd0),
        .command_event_id(16'd0),.command_sequence(8'd0),.command_level(3'd0),
        .command_drill(1'b0),.command_pending(1'b0),.command_region(3'd0),
        .command_time_trusted(1'b0),.command_remaining_seconds(16'd0),
        .command_snapshot(25'd0),.command_epoch_changed(1'b0),
        .sync_blocked_valid(1'b0),.sync_blocked_set(8'd0),
        .alarm_active(alarm),.alarm_pending(pending),.countdown_trusted(trusted),
        .alarm_kind(kind),.local_fire_visible(visible),.alarm_evacuation(route),
        .blocked_set(blocked),.active_count(count));
    task fail;input [799:0] reason;begin $display("TEST_FAIL local fire: %0s result=%d",reason,result);$finish;end endtask
    task step;input integer n;begin repeat(n)@(negedge clk);end endtask
    task key;input integer k;begin
        case(k)0:prev=1;1:next=1;2:confirm=1;3:back=1;endcase
        step(1);prev=0;next=0;confirm=0;back=0;step(1);
    end endtask
    task execute;begin key(2);if(!armed)fail("not armed");held=1;step(20);held=0;step(2);end endtask
    initial begin
        step(4);rst=0;step(4);
        contact=1;step(2);contact=0;step(8);if(active)fail("bounce latched");
        contact=1;step(9);
        if(!closed||!active||!alarm||!pending||trusted||kind!=1||!visible||route||blocked!=1||count!=1)
            fail("offline contact not connected to real emergency core");
        key(3);key(2);execute();if(result!=1||confirmed)fail("locked role accepted");
        key(0);key(1);key(1);if(role!=2||selection!=0)fail("role selection");
        key(2);key(1);execute();if(result!=5||evac)fail("unconfirmed evacuation");
        key(0);execute();if(!confirmed||pending||route)fail("confirmation implicitly evacuated");
        key(1);execute();if(!evac||!route)fail("explicit evacuation not applied");
        key(1);execute();if(!active||result!=3)fail("closed contact cleared");
        contact=0;step(9);if(!active||closed)fail("open contact auto cleared");
        key(2);held=1;step(10);held=0;step(3);held=1;step(19);
        if(!active)fail("non-contiguous hold accepted");
        step(1);held=0;step(2);if(active||route||blocked!=0||count!=0)fail("authorized reset failed");
        contact=1;step(9);if(!active||confirmed||evac)fail("contact relatch retains old authorization");
        key(2);step(101);if(armed||result!=4)fail("confirmation timeout");
        $display("TEST_PASS local fire: bounce, no-B L0, role checks, separate confirm/evacuate, reset veto, continuous hold, timeout, relatch");$finish;
    end
    initial begin #100000;fail("timeout");end
endmodule
