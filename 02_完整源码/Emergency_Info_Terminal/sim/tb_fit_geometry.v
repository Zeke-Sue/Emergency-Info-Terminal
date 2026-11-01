`timescale 1ns/1ps

module tb_fit_geometry;
    reg clk=0,rst=1;
    always #5 clk=~clk;
    integer w,h,mode,orientation,n,cycles,ew,eh,ey,cases=0,span,pan;
    reg [31:0] random_state=32'h61a73029;
    bmp_preloader dut(.clk(clk),.rst(rst),.start_ready(1'b0),.sd_ready(1'b0),
        .load_request(1'b0),.load_image(4'd0),.load_slot(2'd0),
        .sector_data(8'd0),.sector_valid(1'b0),.sector_end(1'b0),
        .pixel_ready(1'b1),.route_cfg_ready(1'b1),.audio_open_req(1'b0),
        .audio_file_index(4'd0),.audio_file_ready(1'b0));
    task fail;input [8*100-1:0] msg;begin
        $display("TEST_FAIL fit: %0s w=%0d h=%0d orientation=%0d",msg,w,h,orientation);
        $finish;end endtask
    task check_fit;
        begin
            @(negedge clk);rst=1;
            repeat(2)@(negedge clk);rst=0;
            dut.bmp_width=w;dut.bmp_height=orientation ? -h : h;
            dut.calculated_height=h;dut.calculated_stride=(w*3+3)/4*4;

            dut.crop_width=w;dut.crop_height=h;dut.crop_x=0;dut.crop_y=0;
            dut.state=6;
            cycles=0;
            while(dut.state!=3&&cycles<32)begin @(negedge clk);cycles=cycles+1;end
            if(cycles>=32)fail("unbounded divider");
            if(w*480<=h*640)begin ew=(w*480+h/2)/h;eh=480;end
            else begin ew=640;eh=(h*640+w/2)/w;end
            if(ew==0)ew=1;if(eh==0)eh=1;
            ey=orientation ? (480-eh)/2 : 480-eh-(480-eh)/2;
            if(dut.fit_width!==ew||dut.fit_height!==eh||
                    dut.fit_x_offset!==(640-ew)/2||dut.fit_y_stream_offset!==ey)
                fail("rounded Fit rectangle / stream padding mismatch");
            if(dut.source_width!==w||dut.source_height!==h||
                    dut.fit_x_offset+ew>640||dut.fit_y_stream_offset+eh>480)
                fail("source extent / destination bounds");
            cases=cases+1;
        end
    endtask
    initial begin
        for(span=0;span<=1280;span=span+1)for(pan=0;pan<=4;pan=pan+1)
            if(dut.pan_offset(span,pan)!==((span*pan)>>2))fail("shared pan offset mismatch");
        for(w=1;w<=1280;w=w+1)begin
            for(mode=0;mode<3;mode=mode+1)begin
                h=mode==0 ? 1 : mode==1 ? 960 : (w*73)%960+1;
                for(orientation=0;orientation<2;orientation=orientation+1)check_fit;
            end
        end
        for(n=0;n<512;n=n+1)begin
            random_state={random_state[30:0],random_state[31]^random_state[21]^random_state[1]^random_state[0]};
            w=random_state%1280+1;
            random_state={random_state[30:0],random_state[31]^random_state[21]^random_state[1]^random_state[0]};
            h=random_state%960+1;orientation=n%2;check_fit;
        end
        $display("TEST_PASS fit: %0d rectangles, widths 1..1280, heights 1..960, top-down/bottom-up, seed 61a73029",cases);
        $finish;
    end
    initial begin #10000000;fail("timeout");end
endmodule
