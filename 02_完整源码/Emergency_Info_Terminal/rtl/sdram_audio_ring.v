`timescale 1ns/1ps

module sdram_audio_ring #(
    parameter integer SAMPLE_BITS=16,
    parameter [20:0] BASE_WORD=21'h1e0000
)(
    input wire clk,rst,flush,
    input wire sample_valid,input wire [15:0] sample,
    output wire sample_ready,input wire stream_end,
    output wire output_valid,output wire [15:0] output_sample,
    input wire output_ready,
    output wire mem_valid,output wire mem_write,
    output wire [20:0] mem_addr,output wire [31:0] mem_wdata,
    input wire mem_ready,mem_done,input wire [31:0] mem_rdata,
    input wire mem_error,
    output wire [SAMPLE_BITS:0] buffered_samples,
    output reg fault
);
    localparam IDLE=0,WRITE_WAIT=1,READ_WAIT=2,CANCEL_WAIT=3;
    localparam [SAMPLE_BITS:0] CAPACITY=1<<SAMPLE_BITS;
    reg [1:0] state,fill,available;
    reg [31:0] input_word,output_word;
    reg [SAMPLE_BITS:0] committed,fetched;
    reg ended;
    reg [1:0] transaction_samples;
    wire [SAMPLE_BITS:0] stored=committed-fetched;
    wire write_pending=fill==2||(ended&&fill==1);
    wire read_pending=available==0&&stored!=0;
    assign buffered_samples=stored+available+fill;
    assign sample_ready=!rst&&!flush&&!fault&&!ended&&
        state!=CANCEL_WAIT&&fill<2&&stored<=CAPACITY-2;
    assign output_valid=available!=0&&!flush&&!fault;
    assign output_sample=output_word[15:0];
    assign mem_valid=state==IDLE&&!flush&&!fault&&(read_pending||write_pending);

    assign mem_write=!read_pending;
    assign mem_addr=BASE_WORD+(mem_write ? {committed[SAMPLE_BITS-1:1],2'b00} : {fetched[SAMPLE_BITS-1:1],2'b00});
    assign mem_wdata=input_word;
    always @(posedge clk or posedge rst)begin
        if(rst)begin
            state<=IDLE;fill<=0;available<=0;input_word<=0;output_word<=0;
            committed<=0;fetched<=0;ended<=0;transaction_samples<=0;fault<=0;
        end else if(flush)begin

            state<=(state==IDLE||mem_done) ? IDLE : CANCEL_WAIT;
            fill<=0;available<=0;committed<=0;fetched<=0;ended<=0;fault<=0;
        end else begin
            if(mem_error)fault<=1;
            if(stream_end)ended<=1;
            if(sample_valid&&sample_ready)begin
                if(fill==0)input_word[15:0]<=sample;
                else input_word[31:16]<=sample;
                fill<=fill+1'b1;
            end
            if(output_valid&&output_ready)begin
                output_word<=output_word>>16;available<=available-1'b1;
            end
            case(state)
                IDLE:if(mem_valid&&mem_ready)begin
                    transaction_samples<=mem_write ? fill : (stored==1 ? 1 : 2);
                    state<=mem_write ? WRITE_WAIT : READ_WAIT;
                end
                WRITE_WAIT:if(mem_done)begin
                    committed<=committed+transaction_samples;fill<=0;state<=IDLE;
                end
                READ_WAIT:if(mem_done)begin
                    output_word<=mem_rdata;available<=transaction_samples;
                    fetched<=fetched+transaction_samples;state<=IDLE;
                end
                CANCEL_WAIT:if(mem_done)state<=IDLE;
            endcase
        end
    end
endmodule
