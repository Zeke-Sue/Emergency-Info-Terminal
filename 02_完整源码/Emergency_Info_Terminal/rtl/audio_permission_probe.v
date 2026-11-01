`timescale 1ns/1ps

module audio_permission_probe(
    input wire clk,rst,service_valid,service_last,
    input wire [7:0] service_type,
    input wire [15:0] service_batch,
    input wire [95:0] service_payload,
    input wire apply,state_valid,allowed,batch_error,crc_error,frame_error,
    input wire [31:0] active_parameters,
    output wire [19:0] status,
    output reg [31:0] last_parameters
);
    reg [3:0] records,commits,errors;
    reg blocked_last_seen,ever_allowed,have_parameters;
    reg [15:0] parameter_batch;
    assign status={records,
        (last_parameters[31:20]==12'ha61),last_parameters[0],blocked_last_seen,ever_allowed,
        state_valid,(active_parameters[31:20]==12'ha61),active_parameters[0],allowed,
        commits,errors};
    always @(posedge clk or posedge rst)begin
        if(rst)begin
            records<=0;commits<=0;errors<=0;last_parameters<=0;
            blocked_last_seen<=0;ever_allowed<=0;have_parameters<=0;parameter_batch<=0;
        end else begin
            if(allowed)ever_allowed<=1;
            if(apply&&commits!=15)commits<=commits+1'b1;
            if(batch_error)errors[3]<=1;
            if(crc_error)errors[2]<=1;
            if(frame_error)errors[1]<=1;
            if(service_valid)case(service_type)
                8'h20:records[3]<=1;
                8'h0c:begin
                    records[2]<=1;last_parameters<=service_payload[31:0];
                    parameter_batch<=service_batch;have_parameters<=1;
                end
                8'h0d:begin
                    records[1]<=1;
                    if(!have_parameters||service_batch!=parameter_batch)errors[0]<=1;
                end
                8'h0b:begin
                    records[0]<=1;
                    if(service_last)blocked_last_seen<=1;
                    if(!have_parameters||service_batch!=parameter_batch)errors[0]<=1;
                end
                default:begin end
            endcase
        end
    end
endmodule
