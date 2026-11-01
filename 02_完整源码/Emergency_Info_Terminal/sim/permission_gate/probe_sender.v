module probe_sender(input clk,rst,go,ready,input [31:0] parameters,
 output valid,output [7:0] kind,output [95:0] payload,output [15:0] batch,output last);
 v41_resync_sender #(.ENABLE_CERTIFICATES(0),.CERTIFICATE_COUNT(15)) sender(
 .clk(clk),.rst(rst),.heartbeat_valid(1'b0),.remote_boot_count(32'd0),.force_resync(go),
 .parameters(parameters),.event_state(64'h0123456789abcdef),.blocked_set(8'h5a),
 .certificate_update_valid(1'b0),.certificate_update_index(4'd0),.certificate_update(96'd0),
 .msg_valid(valid),.msg_ready(ready),.msg_type(kind),.msg_batch(batch),.msg_payload(payload),.msg_last(last),
 .resync_active(),.resync_done());
endmodule
