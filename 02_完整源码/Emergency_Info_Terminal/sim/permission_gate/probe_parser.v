module probe_parser(input clk,rst,byte_valid,input [7:0] byte_data,
 output valid,output [7:0] kind,output [95:0] payload,output [15:0] batch,output last,crc_error,frame_error);
 uart_protocol_parser #(.CLK_HZ(25000000),.CERTIFICATE_COUNT(15),.SINGLE_CARD_CONTROL(1),.ENABLE_EVENT_SNAPSHOT(1)) parser(
 .clk(clk),.rst(rst),.byte_valid(byte_valid),.byte_data(byte_data),.us_tick(1'b0),
 .service_valid(valid),.service_type(kind),.service_payload(payload),.service_batch(batch),.service_last(last),
 .crc_error(crc_error),.frame_error(frame_error));
endmodule
