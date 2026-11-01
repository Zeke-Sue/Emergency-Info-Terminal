`timescale 1ns/1ps

module quality_parameter_smoother(
    input wire clk,rst,frame_tick,
    input wire signed [8:0] target_brightness,
    input wire [7:0] target_contrast,
    input wire [1:0] gamma_mode,temperature_mode,
    output reg signed [8:0] brightness,contrast,
    output reg signed [6:0] gamma_weight,
    output reg signed [5:0] temperature_r,temperature_b,
    output wire busy
);
    localparam INIT=0,IDLE=1,READ=2,CALCULATE=3,WRITE=4;
    reg [2:0] state,channel;
    reg [1:0] word_step;
    reg [44:0] targets;
    reg signed [13:0] accumulator;
    reg signed [9:0] step;
    reg signed [8:0] previous_target;
    reg [4:0] remaining;
    reg signed [8:0] target;
    wire signed [8:0] gamma_target=gamma_mode==0 ? -9'sd32 :
        (gamma_mode==2 ? 9'sd32 : 9'sd0);
    wire signed [8:0] red_target=temperature_mode==0 ? 9'sd12 :
        (temperature_mode==2 ? -9'sd10 : 9'sd0);
    wire signed [8:0] blue_target=temperature_mode==0 ? -9'sd12 :
        (temperature_mode==2 ? 9'sd14 : 9'sd0);
    wire signed [8:0] value=accumulator[13:5];
    wire signed [9:0] delta={target[8],target}-{value[8],value};
    wire changed=target!=previous_target;
    wire signed [13:0] accumulator_base=changed ? {value,5'd0} : accumulator;
    wire signed [9:0] increment=changed ? delta : step;
    wire signed [13:0] increment_extended={{4{increment[9]}},increment};
    wire signed [13:0] next_accumulator=changed || remaining>1 ?
        accumulator_base+increment_extended :
        (remaining==1 ? {previous_target,5'd0} : accumulator);
    wire [15:0] memory_q;
    reg [15:0] memory_d;
    wire [4:0] address={channel,word_step};
    assign busy=state!=IDLE;
    always @* begin
        case(channel)
            0:target=targets[8:0];
            1:target=targets[17:9];
            2:target=targets[26:18];
            3:target=targets[35:27];
            default:target=targets[44:36];
        endcase
        if(state==INIT)begin
            memory_d=0;
            if(channel==1)begin
                if(word_step==0)memory_d=16'd4096;
                if(word_step==2)memory_d=16'd128;
            end
        end else case(word_step)
            0:memory_d={2'd0,accumulator};
            1:memory_d={1'b0,remaining,step};
            default:memory_d={7'd0,previous_target};
        endcase
    end
    buffer_ram #(.DATA_WIDTH(16),.ADDR_WIDTH(5)) states(
        .clk(clk),.we(!rst && (state==INIT || state==WRITE)),
        .wa(address),.ra(address),.d(memory_d),.q(memory_q));

    always @(posedge clk)begin
        if(state==READ)case(word_step)
            1:accumulator<=memory_q[13:0];
            2:begin step<=memory_q[9:0];remaining<=memory_q[14:10];end
            3:previous_target<=memory_q[8:0];
        endcase
        else if(state==CALCULATE)begin
            accumulator<=next_accumulator;
            if(changed)begin previous_target<=target;step<=delta;remaining<=31;end
            else if(remaining!=0)remaining<=remaining-1'b1;
        end
    end
    always @(posedge clk or posedge rst)begin
        if(rst)begin
            state<=INIT;channel<=0;word_step<=0;targets<=0;
            brightness<=0;contrast<=128;gamma_weight<=0;temperature_r<=0;temperature_b<=0;
        end else case(state)
            INIT:begin
                if(word_step==2)begin
                    word_step<=0;
                    if(channel==4)begin channel<=0;state<=IDLE;end
                    else channel<=channel+1'b1;
                end else word_step<=word_step+1'b1;
            end
            IDLE:if(frame_tick)begin
                targets<={blue_target,red_target,gamma_target,1'b0,target_contrast,target_brightness};
                channel<=0;word_step<=0;state<=READ;
            end
            READ:begin
                if(word_step==3)begin word_step<=0;state<=CALCULATE;end
                else word_step<=word_step+1'b1;
            end
            CALCULATE:begin
                case(channel)
                    0:brightness<=next_accumulator[13:5];
                    1:contrast<=next_accumulator[13:5];
                    2:gamma_weight<=next_accumulator[11:5];
                    3:temperature_r<=next_accumulator[10:5];
                    4:temperature_b<=next_accumulator[10:5];
                endcase
                word_step<=0;state<=WRITE;
            end
            WRITE:begin
                if(word_step==2)begin
                    word_step<=0;
                    if(channel==4)begin channel<=0;state<=IDLE;end
                    else begin channel<=channel+1'b1;state<=READ;end
                end else word_step<=word_step+1'b1;
            end
            default:begin state<=INIT;channel<=0;word_step<=0;end
        endcase
    end
endmodule
