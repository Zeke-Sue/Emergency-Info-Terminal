`timescale 1ns/1ps

module earthquake_tone_generator(
    input wire clk,rst,enable,sample_tick,
    output reg signed [15:0] tone,
    output reg ready,
    output reg overrun
);
    localparam INIT=0,IDLE=1,READ=2,RENDER=3,WRITE=4;
    reg [2:0] state;
    reg [2:0] word_step;
    reg [2:0] voice;
    reg [16:0] period_sample;
    reg signed [15:0] sum;
    wire [1:0] segment=period_sample<14400 ? 0 : (period_sample<67200 ? 1 : 2);
    wire at_anchor=period_sample==14399 || period_sample==67199 || period_sample==95999;
    wire [1:0] next_segment=period_sample==14399 ? 1 : (period_sample==67199 ? 2 : 0);
    wire [1:0] anchor_segment=state==INIT ? 0 : next_segment;
    reg [28:0] anchor;
    reg signed [15:0] slope;
    always @* begin
        case({anchor_segment,voice})
            5'd0: anchor=29'd95205108;
            5'd1: anchor=29'd75161928;
            5'd2: anchor=29'd55118747;
            5'd3: anchor=29'd35075566;
            5'd4: anchor=29'd12526988;
            5'd8: anchor=29'd473162230;
            5'd9: anchor=29'd373572676;
            5'd10: anchor=29'd273893644;
            5'd11: anchor=29'd174304089;
            5'd12: anchor=29'd62277026;
            5'd16: anchor=29'd432002127;
            5'd17: anchor=29'd341091986;
            5'd18: anchor=29'd250092367;
            5'd19: anchor=29'd159182225;
            5'd20: anchor=29'd56818838;
            default:anchor=0;
        endcase
        case({segment,voice})
            5'd0: slope=16'sd26247;
            5'd1: slope=16'sd20723;
            5'd2: slope=16'sd15193;
            5'd3: slope=16'sd9669;
            5'd4: slope=16'sd3455;
            5'd8: slope=-16'sd780;
            5'd9: slope=-16'sd615;
            5'd10: slope=-16'sd451;
            5'd11: slope=-16'sd286;
            5'd12: slope=-16'sd103;
            5'd16: slope=-16'sd11694;
            5'd17: slope=-16'sd9234;
            5'd18: slope=-16'sd6770;
            5'd19: slope=-16'sd4309;
            5'd20: slope=-16'sd1538;
            default:slope=0;
        endcase
    end

    reg [63:0] voice_state;
    wire [31:0] phase=voice_state[31:0];
    wire [28:0] step=voice_state[60:32];
    wire [28:0] step_next=at_anchor ? anchor : step+{{13{slope[15]}},slope};
    wire [31:0] phase_next=phase+{3'd0,step};
    wire [63:0] voice_write={3'd0,step_next,phase_next};
    wire [15:0] voice_q;
    wire [15:0] initial_word=word_step<2 ? 16'd0 :
        (word_step==2 ? anchor[15:0] : {3'd0,anchor[28:16]});
    wire [4:0] voice_address={voice,word_step[1:0]};
    buffer_ram #(.DATA_WIDTH(16),.ADDR_WIDTH(5)) voices(
        .clk(clk),.we(!rst && enable && (state==INIT || state==WRITE)),
        .wa(voice_address),.ra(voice_address),
        .d(state==INIT ? initial_word : voice_state[15:0]),.q(voice_q));
    always @(posedge clk)begin
        if(state==READ)case(word_step)
            1:voice_state[15:0]<=voice_q;
            2:voice_state[31:16]<=voice_q;
            3:voice_state[47:32]<=voice_q;
            4:voice_state[63:48]<=voice_q;
        endcase
        else if(state==RENDER)voice_state<=voice_write;
        else if(state==WRITE)voice_state<={16'd0,voice_state[63:16]};
    end
    wire signed [15:0] sine;
    sine_quarter_rom waveform(.phase(phase[31:23]),.value(sine));
    wire signed [15:0] sum_next=sum+(sine>>>3);
    always @(posedge clk or posedge rst)begin
        if(rst)begin
            state<=INIT;voice<=0;word_step<=0;period_sample<=0;sum<=0;
            tone<=0;ready<=0;overrun<=0;
        end else if(!enable)begin
            state<=INIT;voice<=0;word_step<=0;period_sample<=0;sum<=0;
            tone<=0;ready<=0;overrun<=0;
        end else begin
            overrun<=sample_tick && ready && state!=IDLE;
            case(state)
                INIT:begin
                    if(word_step==3)begin
                        word_step<=0;
                        if(voice==4)begin voice<=0;state<=IDLE;end
                        else voice<=voice+1'b1;
                    end else word_step<=word_step+1'b1;
                end
                IDLE:if(sample_tick)begin voice<=0;sum<=0;word_step<=0;state<=READ;end
                READ:begin
                    if(word_step==4)begin word_step<=0;state<=RENDER;end
                    else word_step<=word_step+1'b1;
                end
                RENDER:begin
                    sum<=sum_next;
                    state<=WRITE;word_step<=0;
                    if(voice==4)begin
                        tone<=sum_next;ready<=1;
                    end
                end
                WRITE:begin
                    if(word_step==3)begin
                        word_step<=0;
                        if(voice==4)begin
                            state<=IDLE;voice<=0;
                            period_sample<=period_sample==95999 ? 0 : period_sample+1'b1;
                        end else begin voice<=voice+1'b1;state<=READ;end
                    end else word_step<=word_step+1'b1;
                end
            endcase
        end
    end
endmodule
