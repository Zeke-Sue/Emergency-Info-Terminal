`timescale 1ns/1ps
module tb_bmp_header_predicates #(
    parameter integer WIDTH=8,
    parameter integer HEIGHT=6,
    parameter integer SOURCE_WIDTH=3,
    parameter integer SOURCE_HEIGHT=4,
    parameter integer VIEW_SHIFT=0,PAN_X=2,PAN_Y=2
);
    localparam integer PIXELS=WIDTH*HEIGHT;
    localparam integer SOURCE_STRIDE=(SOURCE_WIDTH*3+3)/4*4;
    localparam integer FILE_SIZE=54+SOURCE_STRIDE*SOURCE_HEIGHT;
    localparam integer CROP_W=(SOURCE_WIDTH>>VIEW_SHIFT)>0 ? SOURCE_WIDTH>>VIEW_SHIFT : 1;
    localparam integer CROP_H=(SOURCE_HEIGHT>>VIEW_SHIFT)>0 ? SOURCE_HEIGHT>>VIEW_SHIFT : 1;
    localparam integer CROP_X=(SOURCE_WIDTH-CROP_W)*PAN_X/4;
    localparam integer CROP_Y=(SOURCE_HEIGHT-CROP_H)*PAN_Y/4;
    localparam integer EXPECTED_FIT_WIDTH = CROP_W*HEIGHT<=CROP_H*WIDTH ?
        (CROP_W*HEIGHT+CROP_H/2)/CROP_H : WIDTH;
    localparam integer EXPECTED_FIT_HEIGHT = CROP_W*HEIGHT<=CROP_H*WIDTH ?
        HEIGHT : (CROP_H*WIDTH+CROP_W/2)/CROP_W;
    localparam integer EXPECTED_FIT_X=(WIDTH-EXPECTED_FIT_WIDTH)/2;
    localparam integer EXPECTED_FIT_Y=(HEIGHT-EXPECTED_FIT_HEIGHT)/2;
    integer mutation_position=0,mutation_value=0;
    reg clk=0,rst=1,start_ready=0,sd_ready=0;
    always #5 clk=~clk;
    wire sector_req,pixel_valid,done;
    wire [31:0] sector_lba;
    reg [7:0] sector_data=0;
    reg sector_valid=0,sector_end=0;
    reg pixel_ready=1;
    wire [21:0] pixel_addr;
    wire [23:0] pixel_rgb;
    wire [4:0] image_count;
    wire [3:0] error_code;
    bmp_preloader #(.WIDTH(WIDTH),.HEIGHT(HEIGHT),.SCAN_FIRST(0),.SCAN_LIMIT(16),.IMAGE_COUNT(8),
        .IO_TIMEOUT(4000),.INIT_TIMEOUT(100),.ENABLE_VIEWPORT(VIEW_SHIFT!=0),
        .DEFAULT_VIEW({VIEW_SHIFT[1:0],PAN_X[2:0],PAN_Y[2:0]})) dut(
        .clk(clk),.rst(rst),.start_ready(start_ready),.sd_ready(sd_ready),
        .load_request(1'b0),.load_image(4'd0),.load_slot(2'd0),
        .sector_req(sector_req),.sector_lba(sector_lba),.sector_data(sector_data),
        .sector_valid(sector_valid),.sector_end(sector_end),.pixel_valid(pixel_valid),
        .pixel_ready(pixel_ready),.pixel_addr(pixel_addr),.pixel_rgb(pixel_rgb),
        .done(done),.image_count(image_count),.error_code(error_code),
        .route_cfg_ready(1'b1));

    task fail;
        input [8*160-1:0] reason;
        begin
            $display("TEST_FAIL tb_scaler: %0s",reason);
            $finish;
        end
    endtask

    function automatic [23:0] source_pixel(input integer picture,xx,yy);
        reg [7:0] rr,gg,bb;
        begin
            rr=picture*40+xx;gg=yy*30;bb=xx+yy*4;
            source_pixel={rr,gg,bb};
        end
    endfunction
    function automatic [7:0] lerp_expected(input [7:0] a,b,input integer weight);
        integer value;
        begin
            value=(a*(256-weight)+b*weight+128)>>8;
            lerp_expected=value[7:0];
        end
    endfunction
    function automatic [23:0] scaled_pixel(input integer picture,xx,yy);
        integer sx0,sx1,sy0,sy1,fx,fy,xnum,ynum;
        integer fit_width,fit_height,fit_x,fit_y,active_x,active_y;
        reg [23:0] p00,p01,p10,p11;
        begin
            if(CROP_W*HEIGHT<=CROP_H*WIDTH)begin
                fit_width=(CROP_W*HEIGHT+CROP_H/2)/CROP_H;
                fit_height=HEIGHT;
            end else begin
                fit_width=WIDTH;
                fit_height=(CROP_H*WIDTH+CROP_W/2)/CROP_W;
            end
            fit_x=(WIDTH-fit_width)/2;fit_y=(HEIGHT-fit_height)/2;
            if(xx<fit_x||xx>=fit_x+fit_width||yy<fit_y||yy>=fit_y+fit_height)
                scaled_pixel=0;
            else begin
            active_x=xx-fit_x;active_y=yy-fit_y;
            if(CROP_W==fit_width*2 && CROP_H==fit_height*2)begin
                p00=source_pixel(picture,CROP_X+active_x*2,CROP_Y+active_y*2);
                p01=source_pixel(picture,CROP_X+active_x*2+1,CROP_Y+active_y*2);
                p10=source_pixel(picture,CROP_X+active_x*2,CROP_Y+active_y*2+1);
                p11=source_pixel(picture,CROP_X+active_x*2+1,CROP_Y+active_y*2+1);
                scaled_pixel[23:16]=(p00[23:16]+p01[23:16]+p10[23:16]+p11[23:16]+2)>>2;
                scaled_pixel[15:8]=(p00[15:8]+p01[15:8]+p10[15:8]+p11[15:8]+2)>>2;
                scaled_pixel[7:0]=(p00[7:0]+p01[7:0]+p10[7:0]+p11[7:0]+2)>>2;
            end else begin
            xnum=active_x*(CROP_W-1);ynum=active_y*(CROP_H-1);
            sx0=fit_width==1 ? 0 : xnum/(fit_width-1);
            sy0=fit_height==1 ? 0 : ynum/(fit_height-1);
            sx1=sx0==CROP_W-1 ? sx0 : sx0+1;
            sy1=sy0==CROP_H-1 ? sy0 : sy0+1;
            fx=fit_width==1 ? 0 : ((xnum%(fit_width-1))*256)/(fit_width-1);
            fy=fit_height==1 ? 0 : ((ynum%(fit_height-1))*256)/(fit_height-1);
            p00=source_pixel(picture,CROP_X+sx0,CROP_Y+sy0);p01=source_pixel(picture,CROP_X+sx1,CROP_Y+sy0);
            p10=source_pixel(picture,CROP_X+sx0,CROP_Y+sy1);p11=source_pixel(picture,CROP_X+sx1,CROP_Y+sy1);
            scaled_pixel[23:16]=lerp_expected(
                lerp_expected(p00[23:16],p01[23:16],fx),
                lerp_expected(p10[23:16],p11[23:16],fx),fy);
            scaled_pixel[15:8]=lerp_expected(
                lerp_expected(p00[15:8],p01[15:8],fx),
                lerp_expected(p10[15:8],p11[15:8],fx),fy);
            scaled_pixel[7:0]=lerp_expected(
                lerp_expected(p00[7:0],p01[7:0],fx),
                lerp_expected(p10[7:0],p11[7:0],fx),fy);
            end
            end
        end
    endfunction
    function automatic [31:0] fat_entry(input integer cluster);
        begin
            case(cluster)
                0:fat_entry=32'h0ffffff8;1:fat_entry=32'hffffffff;
                2,3,5,7,9:fat_entry=32'h0fffffff;
                default:fat_entry=0;
            endcase
        end
    endfunction
    function automatic [7:0] card_byte(input integer lba,idx);
        integer picture,pos,n,physical_y,logical_y,xx,component,signed_height;
        integer entry,epos,cluster;
        reg [23:0] rgb;
        reg [31:0] value;
        begin
            card_byte=0;

            if(lba==0)begin
                case(idx)
                    450:card_byte=8'h0c;
                    454:card_byte=8;455,456,457:card_byte=0;
                    510:card_byte=8'h55;511:card_byte=8'haa;
                    default:card_byte=0;
                endcase
            end else if(lba==8)begin
                case(idx)
                    11:card_byte=0;12:card_byte=2;13:card_byte=1;
                    14:card_byte=1;15:card_byte=0;16:card_byte=1;
                    17,18,22,23:card_byte=0;
                    36:card_byte=1;37,38,39:card_byte=0;
                    44:card_byte=2;45,46,47:card_byte=0;
                    510:card_byte=8'h55;511:card_byte=8'haa;
                    default:card_byte=0;
                endcase
            end else if(lba==9)begin
                entry=idx/4;epos=idx%4;value=fat_entry(entry);
                card_byte=value>>(epos*8);
            end else if(lba==10)begin
                picture=idx/32;epos=idx%32;cluster=3+picture*2;
                if(picture<8)case(epos)
                    0:card_byte="I";1:card_byte="M";2:card_byte="A";
                    3:card_byte="G";4:card_byte="E";
                    5:card_byte="1"+picture;6,7:card_byte=" ";
                    8:card_byte="B";9:card_byte="M";10:card_byte="P";
                    11:card_byte=8'h20;
                    26:card_byte=cluster;27:card_byte=cluster>>8;
                    28,29,30,31:card_byte=FILE_SIZE>>((epos-28)*8);
                    default:card_byte=0;
                endcase
            end
            for(picture=0;picture<8;picture=picture+1)begin
                pos=(lba-(11+picture*2))*512+idx;
                signed_height=picture[0] ? -SOURCE_HEIGHT : SOURCE_HEIGHT;
                if(pos>=0 && pos<FILE_SIZE)begin
                    case(pos)
                        0:card_byte=8'h42;1:card_byte=8'h4d;
                        2,3,4,5:card_byte=FILE_SIZE>>((pos-2)*8);
                        10,11,12,13:card_byte=54>>((pos-10)*8);
                        14:card_byte=40;
                        18,19,20,21:card_byte=SOURCE_WIDTH>>((pos-18)*8);
                        22,23,24,25:card_byte=signed_height>>((pos-22)*8);
                        26:card_byte=1;28:card_byte=24;
                        default:card_byte=0;
                    endcase
                    if(picture==0&&pos==14&&mutation_position>=15&&mutation_position<=17)card_byte=0;
                    if(picture==0&&pos==mutation_position)card_byte=mutation_value;
                    if(pos>=54)begin
                        n=pos-54; physical_y=n/SOURCE_STRIDE;
                        xx=(n%SOURCE_STRIDE)/3; component=(n%SOURCE_STRIDE)%3;
                        logical_y=picture[0] ? physical_y : SOURCE_HEIGHT-1-physical_y;
                        rgb=source_pixel(picture,xx,logical_y);
                        if(xx<SOURCE_WIDTH)card_byte=rgb>>(component*8);
                    end
                end
            end
        end
    endfunction

    integer source_state=0,source_index=0,source_lba=0,cycles=0;
    always @(posedge clk)begin
        cycles<=cycles+1;sector_valid<=0;sector_end<=0;
        pixel_ready<=cycles%5!=0;
        if(rst)begin source_state<=0;source_index<=0;end
        else case(source_state)
            0:if(sector_req)begin source_lba<=sector_lba;source_index<=0;source_state<=1;end
            1:begin
                sector_data<=card_byte(source_lba,source_index);sector_valid<=1;
                if(source_index==511)source_state<=2;else source_index<=source_index+1;
            end
            2:begin sector_end<=1;source_state<=3;end
            3:if(!sector_req)source_state<=0;
        endcase
    end

    integer positions[0:13];
    integer i,value,checks=0;
    reg expected_valid;
    initial begin
        positions[0]=0;positions[1]=1;positions[2]=26;positions[3]=27;
        positions[4]=28;positions[5]=29;positions[6]=30;positions[7]=31;
        positions[8]=32;positions[9]=33;positions[10]=14;positions[11]=15;
        positions[12]=16;positions[13]=17;
        for(i=0;i<14;i=i+1)for(value=0;value<256;value=value+1)begin
            @(negedge clk);rst=1;start_ready=0;sd_ready=0;
            mutation_position=positions[i];mutation_value=value;
            case(mutation_position)
                0:expected_valid=value==8'h42;
                1:expected_valid=value==8'h4d;
                26:expected_valid=value==1;
                28:expected_valid=value==24;
                14:expected_valid=value>=40;
                15,16,17:expected_valid=value!=0;
                default:expected_valid=value==0;
            endcase
            repeat(4)@(negedge clk);rst=0;start_ready=1;sd_ready=1;
            wait(dut.state==5);@(negedge clk);
            if(dut.basic_header_ok!==expected_valid)
                $fatal(1,"BMP header acceptance offset=%0d byte=%0d got=%b expected=%b",mutation_position,value,dut.basic_header_ok,expected_valid);
            checks=checks+1;
        end
        $display("TEST_PASS %0d real FAT/BMP header byte mutations: signatures, planes, BPP, compression, all DIB-size bytes",checks);$finish;
    end
    initial begin #1000000000;$fatal(1,"header predicate test timeout");end
endmodule
