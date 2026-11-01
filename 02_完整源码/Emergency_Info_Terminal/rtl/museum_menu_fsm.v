`timescale 1ns/1ps

module museum_menu_fsm(
    input wire clk,rst,frame_tick,resource_ready,
    input wire [3:0] error_code,
    input wire previous,next,confirm,back,home,activity,timeout_event,
    input wire video_busy,
    output reg [3:0] page,
    output reg [2:0] selection,
    output reg playing,
    output reg [2:0] brightness,contrast,saturation,
    output reg zoom,mono,
    output reg [1:0] period_select,
    output reg previous_event,next_event,reload_event,
    output wire idle_enable
);
    localparam BOOT=0,LOAD=1,MAIN=2,GUIDE=3,BROWSE=4,
               DETAIL=5,ENHANCE=6,SETTINGS=7,ERROR=8;
    reg [3:0] page_pending,detail_parent;
    reg [2:0] select_pending,bri_pending,con_pending,sat_pending;
    reg play_pending,zoom_pending,mono_pending;
    reg [3:0] dismissed_error;
    reg [1:0] period_pending;
    reg prev_pending,next_pending,reload_pending;
    reg reload_wait;
    assign idle_enable=resource_ready && error_code==0 &&
        !(page_pending==GUIDE && play_pending);
    function [2:0] adjust;
        input [2:0] value;
        input increment;
        begin adjust=increment ? (value<4 ? value+1'b1 : value) :
                                 (value>0 ? value-1'b1 : value);end
    endfunction
    always @(posedge clk or posedge rst) begin
        if(rst) begin
            page<=BOOT;page_pending<=BOOT;detail_parent<=MAIN;
            selection<=0;select_pending<=0;playing<=0;play_pending<=0;
            brightness<=2;contrast<=2;saturation<=2;
            bri_pending<=2;con_pending<=2;sat_pending<=2;
            zoom<=0;mono<=0;zoom_pending<=0;mono_pending<=0;
            period_select<=2;period_pending<=2;dismissed_error<=0;
            previous_event<=0;next_event<=0;reload_event<=0;
            prev_pending<=0;next_pending<=0;reload_pending<=0;
            reload_wait<=0;
        end else begin
            previous_event<=0;next_event<=0;reload_event<=0;
            if(error_code==0) dismissed_error<=0;
            if(frame_tick) begin
                page<=page_pending;selection<=select_pending;
                playing<=page_pending==GUIDE && play_pending && !prev_pending && !next_pending && resource_ready && error_code==0;
                brightness<=bri_pending;contrast<=con_pending;saturation<=sat_pending;
                zoom<=zoom_pending;mono<=mono_pending;period_select<=period_pending;

                previous_event<=prev_pending && !video_busy && resource_ready && error_code==0 && !home && !back;
                next_event<=next_pending && !video_busy && resource_ready && error_code==0 && !home && !back;
                reload_event<=reload_pending && !home && !back;
                prev_pending<=0;next_pending<=0;reload_pending<=0;
            end
            if(home || back) begin
                page_pending<=(!home && page_pending==DETAIL) ? detail_parent : MAIN;
                select_pending<=0;play_pending<=0;
                prev_pending<=0;next_pending<=0;reload_pending<=0;
                dismissed_error<=error_code;
            end else if(error_code!=0 && error_code!=dismissed_error && page_pending!=ERROR) begin
                page_pending<=ERROR;select_pending<=0;play_pending<=0;
                prev_pending<=0;next_pending<=0;
            end else if(timeout_event && !activity && resource_ready && error_code==0) begin
                page_pending<=GUIDE;select_pending<=0;play_pending<=1;
                prev_pending<=0;next_pending<=0;
            end else begin
                case(page_pending)
                    BOOT: page_pending<=LOAD;
                    LOAD: begin
                        if(!resource_ready) reload_wait<=0;
                        if(resource_ready && !reload_wait) begin page_pending<=MAIN;select_pending<=0;end
                    end
                    MAIN: begin
                        if(previous) select_pending<=select_pending==0 ? 4 : select_pending-1'b1;
                        if(next) select_pending<=select_pending==4 ? 0 : select_pending+1'b1;
                        if(confirm) begin
                            if(resource_ready || select_pending==4) begin
                                page_pending<=3+select_pending;
                                play_pending<=select_pending==0;
                                detail_parent<=MAIN;select_pending<=0;
                            end else page_pending<=LOAD;
                        end
                    end
                    GUIDE,BROWSE: begin
                        if(previous || next) begin
                            play_pending<=0;
                            if(!video_busy) begin prev_pending<=previous;next_pending<=next;end
                        end
                        if(confirm) begin
                            prev_pending<=0;next_pending<=0;
                            if(page_pending==GUIDE) play_pending<=!play_pending;
                            else begin page_pending<=DETAIL;detail_parent<=BROWSE;select_pending<=0;end
                        end
                    end
                    DETAIL: begin
                        if(previous) zoom_pending<=0;
                        if(next) zoom_pending<=1;
                        if(confirm) zoom_pending<=!zoom_pending;
                    end
                    ENHANCE: begin
                        if(confirm) select_pending<=select_pending==3 ? 0 : select_pending+1'b1;
                        if(previous || next) case(select_pending)
                            0:bri_pending<=adjust(bri_pending,next);
                            1:con_pending<=adjust(con_pending,next);
                            2:sat_pending<=adjust(sat_pending,next);
                            3:mono_pending<=next;
                        endcase
                    end
                    SETTINGS: begin
                        if(previous) select_pending<=select_pending==0 ? 1 : 0;
                        if(next) select_pending<=select_pending==1 ? 0 : 1;
                        if(confirm) begin
                            if(select_pending==0) period_pending<=period_pending+1'b1;
                            else begin
                                reload_pending<=1;reload_wait<=1;page_pending<=LOAD;play_pending<=0;
                            end
                        end
                    end
                    ERROR: if(confirm) begin
                        reload_pending<=1;reload_wait<=1;page_pending<=LOAD;dismissed_error<=error_code;
                    end
                    default: begin page_pending<=MAIN;select_pending<=0;play_pending<=0;end
                endcase
            end
        end
    end
endmodule
