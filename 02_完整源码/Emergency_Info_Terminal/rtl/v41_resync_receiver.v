`timescale 1ns/1ps

module v41_resync_receiver #(
    parameter integer ENABLE_CERTIFICATES=1,
    parameter integer CERTIFICATE_COUNT=10,
    parameter [7:0] CERTIFICATE_PURPOSE_BASE=8'h21
)(
    input wire clk,input wire rst,input wire frame_tick,
    input wire msg_valid,input wire [7:0] msg_type,
    input wire [15:0] msg_batch,input wire [95:0] msg_payload,
    input wire msg_last,input wire [3:0] certificate_lookup_index,
    output wire msg_ready,
    output wire commit_ready,
    output reg [31:0] active_parameters,
    output reg [63:0] active_event,
    output reg [7:0] active_blocked,
    output reg [95:0] active_certificate,
    output wire certificate_ready,
    output reg [15:0] active_certificate_valid_bitmap,
    output reg state_valid,output reg apply_pulse,
    output reg batch_error,output reg [15:0] active_batch
);
    localparam [CERTIFICATE_COUNT-1:0] ALL_CERTIFICATES={CERTIFICATE_COUNT{1'b1}};
    reg [15:0] staging_batch;reg [2:0] seen;
    reg [31:0] staging_parameters;reg [63:0] staging_event;
    reg [7:0] staging_blocked;
    reg [CERTIFICATE_COUNT-1:0] staging_certificate_seen;
    reg [CERTIFICATE_COUNT-1:0] staging_certificate_valid;
    reg active_bank,staging_bank,batch_in_progress,commit_pending;
    reg [2:0] seen_next;
    reg [CERTIFICATE_COUNT-1:0] certificate_seen_next;
    reg certificate_index_valid;
    reg [3:0] certificate_index;
    wire valid_record=msg_type==8'h0b||msg_type==8'h0c||msg_type==8'h0d||
        (ENABLE_CERTIFICATES&&msg_type==8'h0e&&certificate_index_valid);
    wire certificate_write=ENABLE_CERTIFICATES && msg_valid && msg_ready && batch_in_progress &&
        msg_batch==staging_batch && msg_type==8'h0e && certificate_index_valid;

    reg [95:0] certificate_write_shift,certificate_read_shift;
    reg [7:0] certificate_wa;
    reg [2:0] certificate_write_left,certificate_read_step;
    reg [4:0] certificate_read_tag;
    reg certificate_read_valid;
    reg [95:0] certificate_active_data;
    reg [3:0] certificate_active_index;
    reg certificate_active_cached;

    wire prefetch_staging=commit_pending&&certificate_write_left==0;
    wire [4:0] certificate_request_tag={prefetch_staging ? staging_bank : active_bank,
        certificate_lookup_index};
    wire [15:0] certificate_q;
    assign msg_ready=!rst&&certificate_write_left==0;
    assign commit_ready=commit_pending&&msg_ready&&(!ENABLE_CERTIFICATES||
        (certificate_read_valid&&certificate_read_tag=={staging_bank,certificate_lookup_index}));
    wire commit_now=frame_tick&&commit_ready&&!msg_valid;
    buffer_ram #(.DATA_WIDTH(16),.ADDR_WIDTH(8)) certificate_memory(
        .clk(clk),.we(certificate_write_left!=0),.wa(certificate_wa),
        .ra({certificate_request_tag,certificate_read_step}),
        .d(certificate_write_shift[15:0]),.q(certificate_q));
    assign certificate_ready=ENABLE_CERTIFICATES && !rst && certificate_active_cached &&
        certificate_active_index==certificate_lookup_index && certificate_lookup_index<CERTIFICATE_COUNT &&
        active_certificate_valid_bitmap[certificate_lookup_index];
    always @(posedge clk or posedge rst)begin
        if(rst)begin
            certificate_wa<=0;certificate_write_left<=0;
            certificate_read_tag<=0;certificate_read_step<=0;certificate_read_valid<=0;
            certificate_active_index<=0;certificate_active_cached<=0;
        end else begin
            if(certificate_write)begin
                certificate_wa<={staging_bank,certificate_index,3'd0};
                certificate_write_left<=6;
            end else if(certificate_write_left!=0)begin
                certificate_wa<=certificate_wa+1'b1;
                certificate_write_left<=certificate_write_left-1'b1;
            end
            if(certificate_read_tag!=certificate_request_tag)begin
                certificate_read_tag<=certificate_request_tag;
                certificate_read_step<=0;certificate_read_valid<=0;
            end else if(!certificate_read_valid)begin
                if(certificate_read_step==6)certificate_read_valid<=1;
                else certificate_read_step<=certificate_read_step+1'b1;
            end
            if(commit_now||(!commit_pending&&certificate_read_valid&&
                    certificate_read_tag=={active_bank,certificate_lookup_index}))begin
                certificate_active_index<=certificate_lookup_index;
                certificate_active_cached<=1;
            end
        end
    end

    always @(posedge clk)begin
        if(certificate_write)certificate_write_shift<=msg_payload;
        else if(certificate_write_left!=0)certificate_write_shift<=certificate_write_shift>>16;
        if(!certificate_read_valid&&certificate_read_step!=0)
            certificate_read_shift<={certificate_q,certificate_read_shift[95:16]};
        if(commit_now||(!commit_pending&&certificate_read_valid&&
                certificate_read_tag=={active_bank,certificate_lookup_index}))
            certificate_active_data<=certificate_read_shift;
    end

    always @* begin
        certificate_index=msg_payload[7:0]-CERTIFICATE_PURPOSE_BASE;
        certificate_index_valid=msg_payload[7:0]>=CERTIFICATE_PURPOSE_BASE&&
            msg_payload[7:0]<CERTIFICATE_PURPOSE_BASE+CERTIFICATE_COUNT;
        seen_next=seen;
        certificate_seen_next=staging_certificate_seen;
        case(msg_type)
            8'h0c:seen_next[0]=1;
            8'h0d:seen_next[1]=1;
            8'h0b:seen_next[2]=1;
            8'h0e:if(certificate_index_valid)
                certificate_seen_next[certificate_index]=1;
            default:begin end
        endcase
    end

    always @* begin
        active_certificate=0;
        if(certificate_ready)active_certificate=certificate_active_data;
    end

    always @(posedge clk or posedge rst) begin
        if(rst)begin
            staging_batch<=0;seen<=0;staging_parameters<=0;staging_event<=0;
            staging_blocked<=0;staging_certificate_seen<=0;
            staging_certificate_valid<=0;active_bank<=0;staging_bank<=1;
            batch_in_progress<=0;commit_pending<=0;
            active_parameters<=0;active_event<=0;active_blocked<=0;
            active_certificate_valid_bitmap<=0;state_valid<=0;apply_pulse<=0;
            batch_error<=0;active_batch<=0;
        end else begin
            apply_pulse<=0;batch_error<=0;
            if(msg_valid&&!msg_ready)begin

                batch_error<=1;batch_in_progress<=0;commit_pending<=0;
            end else if(msg_valid)begin
                if(!batch_in_progress||msg_batch!=staging_batch)begin
                    staging_batch<=msg_batch;seen<=0;staging_certificate_seen<=0;
                    staging_certificate_valid<=0;staging_bank<=!active_bank;
                    batch_in_progress<=1;commit_pending<=0;
                    if(msg_type==8'h0c)begin
                        staging_parameters<=msg_payload[31:0];seen<=3'b001;
                    end else begin
                        batch_error<=1;batch_in_progress<=0;
                    end
                    if(msg_last)begin batch_error<=1;batch_in_progress<=0;end
                end else begin
                    seen<=seen_next;staging_certificate_seen<=certificate_seen_next;
                    if(msg_type==8'h0c)staging_parameters<=msg_payload[31:0];
                    else if(msg_type==8'h0d)staging_event<=msg_payload[63:0];
                    else if(msg_type==8'h0b)staging_blocked<=msg_payload[7:0];
                    else if(msg_type==8'h0e&&certificate_index_valid)begin
                        staging_certificate_valid[certificate_index]<=
                            msg_payload[92:77]!=0;
                    end else begin batch_error<=1;batch_in_progress<=0;end
                    if(msg_last)begin
                        batch_in_progress<=0;
                        if(valid_record&&seen_next==3'b111&&
                                (!ENABLE_CERTIFICATES||certificate_seen_next==ALL_CERTIFICATES))
                            commit_pending<=1;
                        else batch_error<=1;
                    end
                end
            end
            if(commit_now)begin
                active_parameters<=staging_parameters;active_event<=staging_event;
                active_blocked<=staging_blocked;active_bank<=staging_bank;
                active_certificate_valid_bitmap<=!ENABLE_CERTIFICATES ? 16'd0 :
                    {{(16-CERTIFICATE_COUNT){1'b0}},staging_certificate_valid};
                active_batch<=staging_batch;state_valid<=1;apply_pulse<=1;
                commit_pending<=0;batch_in_progress<=0;
            end
        end
    end
endmodule
