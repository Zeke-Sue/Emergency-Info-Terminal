`timescale 1ns/1ps

module console_status_rows(input wire [63:0] context,input wire [3:0] row,
 output wire [7:0] descriptor);
 localparam SIMPLE_DEMO=1;
 wire [15:0] status=context[15:0],quality_status=context[31:16],panel_status=context[47:32];
 wire [7:0] remote_confirmation=context[55:48];
 wire enable=context[56],fire_visible=context[57],media_fault=context[58];
 wire remote_evacuation_selected=context[59];wire [1:0] waveform_status=context[61:60];
 reg [10:0] x,y,tx,ty;reg panel;reg [5:0] message;
 always @* begin
  x=row==0 ? 112 : 32;
  case(row)
   0:y=40;1:y=56;2:y=76;3:y=108;4:y=288;5:y=304;6:y=320;
   7:y=336;8:y=352;9:y=368;10:y=384;11:y=400;12:y=340;default:y=0;
  endcase
 end
 wire eligible=(row<7)||((row>=7&&row<=11)&&status[4])||(row==12&&!status[4]);
 assign descriptor={panel&&eligible,(row==1||row==2)&&panel_status[15],message};
    always @* begin
        panel=0;message=6'd0;tx=0;ty=0;
        if(enable&&x>=32&&x<608)begin
            tx=x-32;
            if(SIMPLE_DEMO&&panel_status[15]&&x>=112&&x<528&&y>=40&&y<56)begin
                panel=1;tx=x-112;ty=y-40;message=panel_status[13:10]==0 ? 6'd47 : 6'd45+panel_status[13:10];
            end else if(SIMPLE_DEMO&&panel_status[15]&&x<160&&y>=56&&y<72)begin
                panel=1;ty=y-56;message=6'd59+panel_status[9:7];
            end else if(SIMPLE_DEMO&&panel_status[15]&&x<416&&y>=76&&y<92)begin
                panel=1;ty=y-76;message=!panel_status[14] ? 6'd56 : panel_status[6] ? 6'd53 : 6'd52;
            end else if(SIMPLE_DEMO&&panel_status[15]&&!panel_status[14]&&y>=304&&y<336)begin
                panel=1;ty=(y-304)%16;message=y<320 ? 6'd57 : 6'd58;
            end else if(fire_visible&&y>=56&&y<72)begin
                panel=1;ty=y-56;
                if(status[3])message=6'd1;
                else if(status[2])message=6'd2;
                else message=6'd3;
            end else if(media_fault&&y>=288&&y<304)begin
                panel=1;ty=y-288;message=6'd4;
            end else if(quality_status[15]&&quality_status[0]&&
                    quality_status[14:11]>=12&&quality_status[14:11]<=14&&y>=320&&y<336)begin
                panel=1;ty=y-320;message=6'd5;
            end else if(quality_status[15]&&quality_status[14:11]>=11&&y>=304&&y<320)begin
                panel=1;ty=y-304;
                case(quality_status[14:11])
                    11:message=quality_status[10] ? 6'd6 : 6'd7;
                    12:message=quality_status[9:8]==2 ? 6'd8 :
                        quality_status[9:8]==1 ? 6'd9 : 6'd10;
                    13:message=quality_status[7:5]==2 ? 6'd11 :
                        quality_status[7:5]<2 ? 6'd12 : 6'd13;
                    14:message=quality_status[4:2]==2 ? 6'd14 :
                        quality_status[4:2]<2 ? 6'd15 : 6'd16;
                    15:message=quality_status[1] ? 6'd17 : 6'd18;
                endcase
            end else if((remote_confirmation[7]||remote_confirmation[6]||remote_confirmation[0])&&y>=108&&y<124)begin
                panel=1;ty=y-108;
                if(remote_confirmation[7])message=6'd19;
                else if(remote_confirmation[6])message=6'd20;
                else message=6'd21;
            end else if(remote_evacuation_selected&&y>=108&&y<124)begin
                panel=1;ty=y-108;message=6'd22;
            end else if(waveform_status[0]&&!status[4]&&y>=340&&y<356)begin
                panel=1;ty=y-340;message=waveform_status[1] ? (SIMPLE_DEMO ? 6'd52 : 6'd45) : 6'd44;
            end else if(status[4]&&y>=336&&y<416)begin
                panel=1;ty=(y-336)%16;
                case((y-336)/16)
                    0:case(status[7:6])
                        0:message=6'd23;
                        1:message=6'd24;
                        2:message=6'd25;
                        3:message=6'd26;
                    endcase
                    1:case(status[9:8])
                        0:message=6'd27;
                        1:message=6'd28;
                        2:message=6'd29;
                        3:message=6'd30;
                    endcase
                    2:message=status[0] ? 6'd31 :
                        6'd32;
                    3:begin
                        if(status[5])message=6'd33;
                        else case(status[13:10])
                            0:message=6'd34;
                            1:message=6'd35;
                            2:message=6'd36;
                            3:message=6'd37;
                            4:message=6'd38;
                            5:message=6'd39;
                            default:message=6'd40;
                        endcase
                    end
                    4:message=status[14] ? 6'd41 :
                        (status[15] ? 6'd42 :
                        6'd43);
                endcase
            end
        end
    end
endmodule
