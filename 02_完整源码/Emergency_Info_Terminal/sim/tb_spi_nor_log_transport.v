`timescale 1ns/1ps
module tb_spi_nor_log_transport;
    localparam [23:0] BASE_ADDRESS=24'h7fc000;
    localparam integer SLOT_BITS=7;
    localparam integer FLASH_BYTES=1<<(SLOT_BITS+6);

    reg clk=0,rst=1;
    always #5 clk=~clk;
    reg program_valid=0;
    reg [23:0] program_address=0;
    reg [7:0] program_data=0;
    wire program_ready,program_done,program_error;
    wire restore_valid,initialized;
    wire [15:0] restore_next_sequence;
    wire [SLOT_BITS-1:0] restore_write_slot;
    wire flash_cs_n,flash_sclk,flash_mosi,flash_wp_n,flash_hold_n;
    reg flash_miso=0;

    spi_nor_log_transport #(.CLK_DIV(1),.BASE_ADDRESS(BASE_ADDRESS),
        .SLOT_BITS(SLOT_BITS),.POLL_LIMIT(32)) dut(
        .clk(clk),.rst(rst),.program_valid(program_valid),
        .program_ready(program_ready),.program_address(program_address),
        .program_data(program_data),.program_done(program_done),
        .program_error(program_error),.restore_valid(restore_valid),
        .restore_next_sequence(restore_next_sequence),
        .restore_write_slot(restore_write_slot),.initialized(initialized),
        .flash_cs_n(flash_cs_n),.flash_sclk(flash_sclk),
        .flash_mosi(flash_mosi),.flash_miso(flash_miso),
        .flash_wp_n(flash_wp_n),.flash_hold_n(flash_hold_n));

    reg [7:0] flash_mem [0:FLASH_BYTES-1];
    reg [7:0] spi_shift,command,received_byte;
    reg [23:0] flash_address;
    integer spi_bit_count,transaction_index,program_data_count;
    integer busy_polls,erase_count,page_program_count,error_count;
    integer erase_base,i,j;
    reg write_enable;
    reg [23:0] page_address [0:15];
    integer page_length [0:15];
    reg commit_visible_after_body;

    initial begin
        spi_shift=0;command=0;flash_address=0;spi_bit_count=0;
        transaction_index=0;program_data_count=0;busy_polls=0;
        erase_count=0;page_program_count=0;error_count=0;
        erase_base=0;write_enable=0;commit_visible_after_body=0;
        for(i=0;i<FLASH_BYTES;i=i+1)flash_mem[i]=8'hff;
        for(i=0;i<16;i=i+1)begin page_address[i]=0;page_length[i]=0;end
    end

    always @(negedge flash_cs_n)begin
        spi_shift=0;command=0;flash_address=0;spi_bit_count=0;
        transaction_index=0;program_data_count=0;flash_miso=0;
    end

    always @(posedge flash_sclk)if(!flash_cs_n)begin
        received_byte={spi_shift[6:0],flash_mosi};
        spi_shift=received_byte;
        if(spi_bit_count==7)begin
            spi_bit_count=0;
            if(transaction_index==0)command=received_byte;
            else if(transaction_index<=3&&
                    (command==8'h03||command==8'h02||command==8'h20))
                flash_address={flash_address[15:0],received_byte};
            else if(command==8'h02&&transaction_index>=4)begin
                if(write_enable&&flash_address+program_data_count>=BASE_ADDRESS&&
                        flash_address+program_data_count<BASE_ADDRESS+FLASH_BYTES)
                    flash_mem[flash_address-BASE_ADDRESS+program_data_count]=
                        flash_mem[flash_address-BASE_ADDRESS+program_data_count]&
                        received_byte;
                program_data_count=program_data_count+1;
            end else if(command==8'h03&&transaction_index>=4)
                flash_address=flash_address+1'b1;
            else if(command==8'h05&&transaction_index>=1&&busy_polls>0)
                busy_polls=busy_polls-1;
            transaction_index=transaction_index+1;
        end else spi_bit_count=spi_bit_count+1;
    end

    always @(negedge flash_sclk)if(!flash_cs_n)begin
        if(command==8'h03&&transaction_index>=4&&
                flash_address>=BASE_ADDRESS&&flash_address<BASE_ADDRESS+FLASH_BYTES)
            flash_miso=flash_mem[flash_address-BASE_ADDRESS][7-spi_bit_count];
        else if(command==8'h05&&transaction_index>=1)
            flash_miso=(7-spi_bit_count)==0 && busy_polls>0;
        else flash_miso=0;
    end

    always @(posedge flash_cs_n)begin
        flash_miso=0;
        if(command==8'h06)write_enable=1;
        else if(command==8'h20&&write_enable&&transaction_index==4)begin
            erase_base=(flash_address-BASE_ADDRESS)&24'hfff000;
            for(j=0;j<4096;j=j+1)
                if(erase_base+j<FLASH_BYTES)flash_mem[erase_base+j]=8'hff;
            erase_count=erase_count+1;busy_polls=2;write_enable=0;
        end else if(command==8'h02&&write_enable&&program_data_count>0)begin
            if(page_program_count<16)begin
                page_address[page_program_count]=flash_address;
                page_length[page_program_count]=program_data_count;
            end
            if(program_data_count==32&&flash_address[5:0]==0&&
                    flash_mem[flash_address-BASE_ADDRESS+32]==8'h43&&
                    flash_mem[flash_address-BASE_ADDRESS+33]==8'h4d&&
                    flash_mem[flash_address-BASE_ADDRESS+34]==8'h49&&
                    flash_mem[flash_address-BASE_ADDRESS+35]==8'h54)
                commit_visible_after_body=1;
            page_program_count=page_program_count+1;
            busy_polls=2;write_enable=0;
        end
    end

    always @(posedge clk)if(program_error)error_count=error_count+1;

    reg [7:0] record_bytes [0:35];
    reg [31:0] record_crc;
    integer n,wait_cycles,erase_before,program_before;
    function [31:0] crc32_byte;
        input [31:0] current;input [7:0] value;integer k;reg [31:0] work;
        begin work=current^value;
            for(k=0;k<8;k=k+1)
                work=work[0] ? (work>>1)^32'hedb88320 : work>>1;
            crc32_byte=work;
        end
    endfunction
    task fail;input [8*100-1:0] message;begin
        $display("TEST_FAIL tb_spi_nor_log_transport: %0s",message);$finish;
    end endtask
    task build_record;input [15:0] sequence;begin
        for(n=0;n<36;n=n+1)record_bytes[n]=0;
        record_bytes[0]=8'h4c;record_bytes[1]=8'h47;
        record_bytes[2]=8'h01;record_bytes[3]=8'h55;
        record_bytes[4]=sequence[15:8];record_bytes[5]=sequence[7:0];
        for(n=6;n<28;n=n+1)record_bytes[n]=n+sequence[7:0];
        record_crc=32'hffffffff;
        for(n=0;n<28;n=n+1)record_crc=crc32_byte(record_crc,record_bytes[n]);
        record_crc=~record_crc;
        record_bytes[28]=record_crc[31:24];record_bytes[29]=record_crc[23:16];
        record_bytes[30]=record_crc[15:8];record_bytes[31]=record_crc[7:0];
        record_bytes[32]=8'h43;record_bytes[33]=8'h4d;
        record_bytes[34]=8'h49;record_bytes[35]=8'h54;
    end endtask
    task clear_flash;begin
        for(n=0;n<FLASH_BYTES;n=n+1)flash_mem[n]=8'hff;
        busy_polls=0;write_enable=0;
    end endtask
    task preload_record;input integer slot;input [15:0] sequence;
        input integer corrupt;begin
        build_record(sequence);
        for(n=0;n<36;n=n+1)flash_mem[slot*64+n]=record_bytes[n];
        if(corrupt!=0)flash_mem[slot*64+10]=flash_mem[slot*64+10]^8'h01;
    end endtask
    task reset_and_wait;begin
        @(negedge clk);rst=1;program_valid=0;
        repeat(3)@(negedge clk);rst=0;
        wait_cycles=0;
        while(!initialized&&wait_cycles<200000)begin
            @(negedge clk);wait_cycles=wait_cycles+1;
        end
        if(!initialized)fail("startup scan timeout");
        #1;
    end endtask
    task send_record;input integer slot;input [15:0] sequence;begin
        build_record(sequence);
        for(n=0;n<36;n=n+1)begin
            while(!program_ready)@(negedge clk);
            program_address=BASE_ADDRESS+slot*64+n;
            program_data=record_bytes[n];program_valid=1;
            @(negedge clk);program_valid=0;
        end
        wait_cycles=0;
        while(!program_done&&wait_cycles<10000)begin
            @(negedge clk);wait_cycles=wait_cycles+1;
        end
        if(!program_done)fail("program completion timeout");
        if(program_error)fail("unexpected transport error");
    end endtask

    initial begin
        repeat(3)@(negedge clk);rst=0;
        wait_cycles=0;
        while(!initialized&&wait_cycles<200000)begin
            @(negedge clk);wait_cycles=wait_cycles+1;
        end
        if(!initialized)fail("empty flash scan timeout");
        if(restore_next_sequence!=0||restore_write_slot!=0)
            fail("empty flash recovery state");
        if(!flash_wp_n||!flash_hold_n)fail("protection pins not inactive");

        send_record(0,16'd0);
        if(erase_count!=1||page_program_count!=2)
            fail("first slot erase/program command counts");
        if(page_address[0]!=BASE_ADDRESS||page_length[0]!=32||
                page_address[1]!=BASE_ADDRESS+32||page_length[1]!=4)
            fail("body and commit were not separate page programs");
        if(commit_visible_after_body)fail("commit word visible after body program");
        for(n=0;n<36;n=n+1)
            if(flash_mem[n]!=record_bytes[n])fail("programmed record mismatch");

        reset_and_wait;
        if(restore_next_sequence!=1||restore_write_slot!=1)
            fail("reset did not recover the committed record");
        preload_record(1,16'd400,1);
        reset_and_wait;
        if(restore_next_sequence!=1||restore_write_slot!=1)
            fail("CRC-damaged record was accepted during recovery");

        @(negedge clk);rst=1;clear_flash;preload_record(62,16'd62,0);
        repeat(3)@(negedge clk);rst=0;
        wait_cycles=0;
        while(!initialized&&wait_cycles<200000)begin
            @(negedge clk);wait_cycles=wait_cycles+1;
        end
        if(!initialized)fail("boundary setup scan timeout");
        if(restore_next_sequence!=63||restore_write_slot!=63)
            fail("boundary setup recovery state");
        erase_before=erase_count;program_before=page_program_count;
        send_record(63,16'd63);
        if(erase_count!=erase_before||page_program_count!=program_before+2)
            fail("last slot in sector used unexpected erase/program count");
        send_record(64,16'd64);
        if(erase_count!=erase_before+1||page_program_count!=program_before+4)
            fail("first slot in next sector did not erase exactly once");
        for(n=36;n<64;n=n+1)
            if(flash_mem[64*64+n]!=8'hff)fail("sector erase did not clear next slot");
        reset_and_wait;
        if(restore_next_sequence!=65||restore_write_slot!=65)
            fail("post-boundary reset recovery state");
        if(error_count!=0)fail("transport emitted program_error");
        $display("TEST_PASS tb_spi_nor_log_transport W25Q64 recovery, commit-last, CRC and sector wrap");
        $finish;
    end
    initial begin #50000000;fail("timeout");end
endmodule
