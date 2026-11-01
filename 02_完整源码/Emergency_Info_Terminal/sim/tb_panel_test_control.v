`timescale 1ns/1ps
module tb_panel_test_control;
 reg clk=0,rst=1,ft=0,en=0,blocked=0,prev=0,next=0,toggle=0,level=0,voice=0;
 wire mode,run,active,cancel,pending,evac,trusted,tone,synth,restart;
 wire [4:0] selection;wire [2:0] lev,kind;wire [15:0] seconds;
 always #5 clk=~clk;
 panel_test_control #(.SECOND_FRAMES(2)) dut(.clk(clk),.rst(rst),.frame_tick(ft),
 .enable(en),.blocked(blocked),.previous(prev),.next(next),.toggle(toggle),.level_next(level),.voice_enable(voice),
 .mode(mode),.running(run),.selection(selection),.level(lev),.active(active),.cancel(cancel),
 .pending(pending),.evacuation(evac),.trusted(trusted),.tone40k(tone),.synth_only(synth),
 .kind(kind),.seconds(seconds),.restart_audio(restart));
 task step;begin @(negedge clk);end endtask
 task frame;begin ft=1;step();ft=0;step();end endtask
 integer i;
 initial begin
 repeat(3)step();rst=0;en=1;repeat(2)step();
 if(!run||active||selection!=0||!tone)$fatal(1,"entry");
 repeat(200)frame();if(selection!=0)$fatal(1,"auto advance");
 for(i=1;i<=20;i=i+1)begin
 next=1;step();next=0;step();
 if(selection!=i||!run||!tone)$fatal(1,"next page");
 if(active!==(i>=16&&i<=19)||cancel!==(i==20))$fatal(1,"page mapping");
 voice=1;step();if(tone||synth)$fatal(1,"voice switch");voice=0;step();
 end
 next=1;step();next=0;step();if(selection!=0)$fatal(1,"wrap next");
 prev=1;step();prev=0;step();if(selection!=20)$fatal(1,"wrap previous");
 toggle=1;step();toggle=0;step();if(run||tone||!cancel)$fatal(1,"pause hides page or leaves tone");
 blocked=1;step();if(mode||active||cancel||tone)$fatal(1,"remote priority");
 blocked=0;step();if(run)$fatal(1,"unrequested resume");
 en=0;step();en=1;step();step();if(selection!=0||!run)$fatal(1,"reentry");
 $display("TEST_PASS manual 21 pages, wrap, no automatic advance, voice gating, pause, remote priority and reentry");$finish;
 end
endmodule
