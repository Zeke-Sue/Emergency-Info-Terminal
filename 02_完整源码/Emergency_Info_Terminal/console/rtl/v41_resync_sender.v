`timescale 1ns/1ps

module v41_resync_sender #(
    parameter integer ENABLE_CERTIFICATES=1,
    parameter integer CERTIFICATE_COUNT=10,
    parameter [7:0] CERTIFICATE_PURPOSE_BASE=8'h21
)(
    input wire clk,input wire rst,
    input wire heartbeat_valid,input wire [31:0] remote_boot_count,
    input wire force_resync,
    input wire [31:0] parameters,input wire [63:0] event_state,
    input wire [7:0] blocked_set,
    input wire certificate_update_valid,input wire [3:0] certificate_update_index,
    input wire [95:0] certificate_update,
    output reg msg_valid,input wire msg_ready,output reg [7:0] msg_type,
    output reg [15:0] msg_batch,output reg [95:0] msg_payload,
    output reg msg_last,output reg resync_active,output reg resync_done
);
    localparam integer LAST_INDEX=ENABLE_CERTIFICATES ? CERTIFICATE_COUNT+2 : 2;

    localparam integer INDEX_BITS=$clog2(CERTIFICATE_COUNT+3);
    reg boot_seen;reg [31:0] last_boot;reg [INDEX_BITS-1:0] index;
    reg [31:0] parameters_q;reg [63:0] event_q;reg [7:0] blocked_q;
    wire [63:0] event_handoff;
    console_hold_buffer #(.WIDTH(64)) event_hold(.d(event_state),.q(event_handoff));
    reg [95:0] certificate_table [0:CERTIFICATE_COUNT-1];
    reg [CERTIFICATE_COUNT-1:0] certificate_valid;
    reg resync_pending;
    wire boot_changed=heartbeat_valid&&(!boot_seen||remote_boot_count!=last_boot);
    wire [3:0] certificate_index=index-3;
    wire [7:0] placeholder_purpose=CERTIFICATE_PURPOSE_BASE+certificate_index;

    always @(posedge clk or posedge rst)begin
        if(rst)begin
            msg_valid<=0;msg_type<=0;msg_batch<=0;msg_payload<=0;msg_last<=0;
            resync_active<=0;resync_done<=0;boot_seen<=0;last_boot<=0;index<=0;
            parameters_q<=0;event_q<=0;blocked_q<=0;certificate_valid<=0;
            resync_pending<=0;
        end else begin
            resync_done<=0;
            if(heartbeat_valid)begin boot_seen<=1;last_boot<=remote_boot_count;end
            if(ENABLE_CERTIFICATES&&certificate_update_valid&&certificate_update_index<CERTIFICATE_COUNT)begin
                certificate_table[certificate_update_index]<=certificate_update;
                certificate_valid[certificate_update_index]<=1;
            end
            if((boot_changed||force_resync)&&resync_active)resync_pending<=1;
            if((boot_changed||force_resync||resync_pending)&&!resync_active)begin
                resync_active<=1;index<=0;msg_batch<=msg_batch+1'b1;
                parameters_q<=parameters;event_q<=event_handoff;blocked_q<=blocked_set;
                resync_pending<=0;
            end
            if(resync_active&&!msg_valid)begin
                msg_valid<=1;msg_last<=index==LAST_INDEX;

                case(index)
                    0:begin msg_type<=8'h0c;msg_payload<={64'd0,parameters_q};end
                    1:begin msg_type<=8'h0d;msg_payload<={32'd0,event_q};end
                    2:begin msg_type<=8'h0b;msg_payload<={88'd0,blocked_q};end
                    default:begin
                        msg_type<=8'h0e;
                        if(ENABLE_CERTIFICATES&&certificate_valid[certificate_index])
                            msg_payload<=certificate_table[certificate_index];
                        else msg_payload<={88'd0,placeholder_purpose};
                    end
                endcase
            end
            if(msg_valid&&msg_ready)begin
                msg_valid<=0;
                if(index==LAST_INDEX)begin
                    resync_active<=0;resync_done<=1;index<=0;
                end else index<=index+1'b1;
            end
        end
    end
endmodule
