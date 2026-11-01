`timescale 1ns/1ps

module alarm_trajectory_checker(
    input wire clk,rst,start,
    input wire [1:0] profile,
    input wire bin_valid,input wire [8:0] bin_index,
    input wire [15:0] magnitude,input wire window_done,
    output wire failed,
    output reg [31:0] windows_checked,bad_windows,first_bad_sample,
    output reg [4:0] missing_voices,
    output reg bad_window
);
    reg [8:0] cycle_window;
    wire [35:0] expected;
    trajectory_reference_rom reference(.clk(clk),.address(cycle_window),.value(expected));
    wire [1:0] tolerance=expected[30] ? 2'd1 : 2'd2;
    reg [15:0] left,centre,maximum,low_band;
    reg [15:0] voice_peak[0:4];
    reg [15:0] evac_peak;
    wire local_peak=bin_index>=2 && centre>=left && centre>magnitude;
    wire [8:0] peak_bin=bin_index-1'b1;
    reg [4:0] missing;
    integer i,v;
    reg [8:0] target;
    always @* begin
        missing=0;
        for(v=0;v<5;v=v+1)
            missing[v]=({3'd0,voice_peak[v]}<<3)<{3'd0,maximum};
    end
    wire quake_bad=expected[31] ? ({1'b0,low_band}<<1)<{1'b0,maximum} : |missing;
    wire evac_bad=({1'b0,evac_peak}<<1)<{1'b0,maximum};
    wire current_bad=profile!=0 && (maximum<8 || (profile==1 ? quake_bad : evac_bad));

    assign failed=profile!=0 && bad_windows>(windows_checked>>5);
    always @(posedge clk or posedge rst)begin
        if(rst)begin
            cycle_window<=0;left<=0;centre<=0;maximum<=0;low_band<=0;evac_peak<=0;
            windows_checked<=0;bad_windows<=0;first_bad_sample<=0;
            missing_voices<=0;bad_window<=0;
            for(i=0;i<5;i=i+1)voice_peak[i]<=0;
        end else if(start)begin
            cycle_window<=0;left<=0;centre<=0;maximum<=0;low_band<=0;evac_peak<=0;
            windows_checked<=0;bad_windows<=0;first_bad_sample<=0;
            missing_voices<=0;bad_window<=0;
            for(i=0;i<5;i=i+1)voice_peak[i]<=0;
        end else begin
            bad_window<=0;
            if(bin_valid)begin
                if(bin_index==0)begin
                    left<=0;centre<=magnitude;maximum<=magnitude;low_band<=0;evac_peak<=0;
                    for(i=0;i<5;i=i+1)voice_peak[i]<=0;
                end else begin
                    left<=centre;centre<=magnitude;
                    if(magnitude>maximum)maximum<=magnitude;
                    if(bin_index<=12 && magnitude>low_band)low_band<=magnitude;
                    if(local_peak)begin
                        for(i=0;i<5;i=i+1)begin
                            target={3'd0,expected[i*6+:6]};
                            if(peak_bin+tolerance>=target && peak_bin<=target+tolerance &&
                                    centre>voice_peak[i])voice_peak[i]<=centre;
                        end
                        if(peak_bin+1>=expected[35:32] &&
                                peak_bin<={5'd0,expected[35:32]}+9'd1 && centre>evac_peak)
                            evac_peak<=centre;
                    end
                end
            end
            if(window_done)begin
                windows_checked<=windows_checked+1'b1;
                cycle_window<=cycle_window==374 ? 0 : cycle_window+1'b1;
                bad_window<=current_bad;
                if(current_bad)begin
                    if(bad_windows==0)begin
                        first_bad_sample<=(windows_checked+1'b1)<<8;
                        missing_voices<=missing;
                    end
                    bad_windows<=bad_windows+1'b1;
                end
            end
        end
    end
endmodule
