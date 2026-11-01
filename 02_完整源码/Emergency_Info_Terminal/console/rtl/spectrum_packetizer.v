`timescale 1ns/1ps

module spectrum_packetizer(
    input wire clk,rst,file_start,sample_valid,
    input wire [3:0] file_index,
    input wire spectrum_valid,
    input wire [5:0] spectrum_bin,
    input wire [15:0] spectrum_magnitude,
    input wire transform_done,
    input wire [23:0] peak_frequency_q8,
    output wire request_valid,input wire request_ready,
    output wire [7:0] request_type,
    output reg [95:0] request_payload
);

    reg active_bank;
    reg [63:0] valid0,valid1;
    reg update_valid,update_bank;
    reg [5:0] update_bin;
    reg [7:0] update_magnitude;
    reg forward_valid,forward_bank;
    reg [5:0] forward_bin;
    reg [7:0] forward_magnitude;
    wire [7:0] q0,q1;
    reg [2:0] byte_index;
    reg read_phase,packet_ready,flush;
    reg [63:0] packet_bins;
    reg [12:0] interval_samples;
    reg [31:0] sample_position,snapshot_position;
    reg [23:0] snapshot_peak;
    reg [7:0] column_sequence;
    reg [3:0] snapshot_file,chunk;
    reg due,pending;
    wire [7:0] magnitude=|spectrum_magnitude[15:12] ? 8'hff : spectrum_magnitude[11:4];
    wire [5:0] packet_address={chunk[2:0],byte_index};
    wire [7:0] stored=update_bank ? q1 : q0;
    wire stored_valid=update_bank ? valid1[update_bin] : valid0[update_bin];
    wire forwarded=forward_valid&&forward_bank==update_bank&&forward_bin==update_bin;
    wire [7:0] previous=forwarded ? forward_magnitude : stored_valid ? stored : 8'd0;
    wire [7:0] maximum=update_magnitude>previous ? update_magnitude : previous;
    wire write_update=update_valid&&!file_start;
    buffer_ram #(.DATA_WIDTH(8),.ADDR_WIDTH(6)) bank0(
        .clk(clk),.we(write_update&&!update_bank),.wa(update_bin),
        .ra(active_bank ? packet_address : spectrum_bin),.d(maximum),.q(q0));
    buffer_ram #(.DATA_WIDTH(8),.ADDR_WIDTH(6)) bank1(
        .clk(clk),.we(write_update&&update_bank),.wa(update_bin),
        .ra(active_bank ? spectrum_bin : packet_address),.d(maximum),.q(q1));
    wire snapshot_bin_valid=active_bank ? valid0[packet_address] : valid1[packet_address];
    wire [7:0] snapshot_bin=snapshot_bin_valid ? (active_bank ? q0 : q1) : 8'd0;
    assign request_valid=pending&&packet_ready;
    assign request_type=chunk==8 ? 8'h22 : 8'h21;
    always @* begin
        request_payload={column_sequence,4'd0,chunk,4'd0,snapshot_file,8'd0,64'd0};
        if(chunk<8)request_payload[63:0]=packet_bins;
        else request_payload={column_sequence,4'd0,snapshot_file,snapshot_peak,
            snapshot_position,24'd0};
    end
    always @(posedge clk or posedge rst)begin
        if(rst)begin
            interval_samples<=0;sample_position<=0;snapshot_position<=0;
            snapshot_peak<=0;column_sequence<=0;snapshot_file<=0;chunk<=0;
            due<=0;pending<=0;active_bank<=0;valid0<=0;valid1<=0;
            update_valid<=0;update_bank<=0;update_bin<=0;update_magnitude<=0;
            forward_valid<=0;forward_bank<=0;forward_bin<=0;forward_magnitude<=0;
            byte_index<=0;read_phase<=0;packet_ready<=0;packet_bins<=0;flush<=0;
        end else begin
            update_valid<=spectrum_valid&&!file_start;
            update_bank<=active_bank;update_bin<=spectrum_bin;update_magnitude<=magnitude;
            forward_valid<=write_update;
            if(write_update)begin
                forward_bank<=update_bank;forward_bin<=update_bin;forward_magnitude<=maximum;
                if(update_bank)valid1[update_bin]<=1;else valid0[update_bin]<=1;
            end
            if(pending&&!packet_ready)begin
                if(!read_phase)read_phase<=1;
                else begin

                    packet_bins[(7-byte_index)*8 +: 8]<=snapshot_bin;read_phase<=0;
                    if(byte_index==7)begin byte_index<=0;packet_ready<=1;end
                    else byte_index<=byte_index+1'b1;
                end
            end
            if(request_valid&&request_ready)begin
                if(chunk==8)begin pending<=0;chunk<=0;packet_ready<=0;end
                else begin
                    chunk<=chunk+1'b1;packet_ready<=chunk==7;
                    byte_index<=0;read_phase<=0;
                end
            end
            if(file_start)begin
                sample_position<=0;interval_samples<=0;due<=0;
                flush<=0;forward_valid<=0;
                if(active_bank)valid1<=0;else valid0<=0;
            end else begin
                if(sample_valid)begin
                    sample_position<=sample_position+1'b1;
                    if(interval_samples==4799)begin interval_samples<=0;due<=1;end
                    else interval_samples<=interval_samples+1'b1;
                end
                if(transform_done&&due&&!pending)flush<=1;
                if(flush&&!update_valid&&!spectrum_valid&&!pending)begin
                    active_bank<=~active_bank;
                    if(active_bank)valid0<=0;else valid1<=0;
                    snapshot_peak<=peak_frequency_q8;snapshot_position<=sample_position;
                    snapshot_file<=file_index;column_sequence<=column_sequence+1'b1;
                    pending<=1;chunk<=0;due<=0;flush<=0;
                    packet_ready<=0;byte_index<=0;read_phase<=0;
                end
            end
        end
    end
endmodule
