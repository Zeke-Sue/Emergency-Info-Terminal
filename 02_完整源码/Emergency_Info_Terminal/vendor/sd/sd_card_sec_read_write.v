
module sd_card_sec_read_write
#(
	parameter  SPI_LOW_SPEED_DIV = 248,         // spi clk speed = clk speed /((SPI_LOW_SPEED_DIV + 2) * 2 )
	parameter  SPI_HIGH_SPEED_DIV = 0,          // spi clk speed = clk speed /((SPI_HIGH_SPEED_DIV + 2) * 2 )
    parameter integer INIT_TIMEOUT_CYCLES=100000000
)
(
	input            clk,
	input            rst,
	output reg       sd_init_done,
    output wire sd_init_failed,
	input            sd_sec_read,
	input[31:0]      sd_sec_read_addr,
	output[7:0]      sd_sec_read_data,
	output           sd_sec_read_data_valid,
	output           sd_sec_read_end,
	input            sd_sec_write,
	input[31:0]      sd_sec_write_addr,
	input[7:0]       sd_sec_write_data,
	output           sd_sec_write_data_req,
	output           sd_sec_write_end,

	output reg[15:0] spi_clk_div,
	output reg       cmd_req,
	input            cmd_req_ack,
	input            cmd_req_error,
    input [7:0] response_r1,
    input [31:0] response_data,
	output reg[47:0] cmd,
	output reg[7:0]  cmd_r1,
	output reg[15:0] cmd_data_len,
	output reg       block_read_req,
	input            block_read_valid,
	input[7:0]       block_read_data,
	input            block_read_req_ack,
	output reg       block_write_req,
	output[7:0]      block_write_data,
	input            block_write_data_rd,
	input            block_write_req_ack
);
reg[7:0] read_data;

localparam S_IDLE               = 0;
localparam S_CMD0               = 1;
localparam S_CMD8               = 2;
localparam S_CMD55              = 3;
localparam S_CMD41              = 4;
localparam S_CMD17              = 5;
localparam S_READ               = 6;
localparam S_CMD24              = 7;
localparam S_WRITE              = 8;
localparam S_ERR                = 14;
localparam S_WRITE_END          = 15;
localparam S_READ_END           = 16;
localparam S_WAIT_READ_WRITE    = 17;
localparam S_CMD16              = 18;
localparam S_CMD58              = 19;
reg card_v2,high_capacity;
reg [1:0] read_retries;
reg [1:0] init_retries;
localparam integer INIT_TIMER_BITS=$clog2(INIT_TIMEOUT_CYCLES+1);
reg [INIT_TIMER_BITS-1:0] init_timer;

reg[4:0]                       state;
reg[31:0]                      sec_addr;
assign sd_init_failed=state==S_ERR;
wire initializing=!sd_init_done&&state!=S_IDLE&&state!=S_ERR;
wire v1_response=state==S_CMD8&&response_r1==8'h05;
wire init_command_error=initializing&&cmd_req_ack&&cmd_req_error&&
    state!=S_CMD41&&!v1_response;
always @(posedge clk)begin
    if(rst||!initializing)init_timer<=0;
    else if(init_timer<INIT_TIMEOUT_CYCLES-1)init_timer<=init_timer+1'b1;
end
assign sd_sec_read_data_valid = (state == S_READ) && block_read_valid;
assign sd_sec_read_data = block_read_data;
assign sd_sec_read_end = (state == S_READ_END);
assign sd_sec_write_data_req = (state == S_WRITE) && block_write_data_rd;
assign block_write_data = sd_sec_write_data;
assign sd_sec_write_end = (state == S_WRITE_END);

// All SD commands run on clk. A synchronous reset avoids using synthesized
// command data as an asynchronous set/reset control on unrelated registers.
always@(posedge clk)
begin
	if(rst == 1'b1)
	begin
		state <= S_IDLE;
		cmd_req <= 1'b0;
		cmd_data_len <= 16'd0;
		cmd_r1 <= 8'd0;
		cmd <= 48'd0;
		spi_clk_div <= SPI_LOW_SPEED_DIV[15:0];
		block_write_req <= 1'b0;
		block_read_req <= 1'b0;
		sec_addr <= 32'd0;
		sd_init_done <= 1'b0;
        card_v2<=0;high_capacity<=0;
        read_retries<=0;init_retries<=0;
	end
	else if(initializing&&init_timer==INIT_TIMEOUT_CYCLES-1)begin
        state<=S_ERR;cmd_req<=0;block_read_req<=0;block_write_req<=0;sd_init_done<=0;
    end else if(init_command_error)begin
        cmd_req<=0;
        if(init_retries==3)state<=S_ERR;
        else init_retries<=init_retries+1'b1;
    end else begin
        if(cmd_req_ack)init_retries<=0;
		case(state)
			S_IDLE:
			begin
				state <= S_CMD0;
				sd_init_done <= 1'b0;
				spi_clk_div <= SPI_LOW_SPEED_DIV[15:0];
			end
			S_CMD0:
			begin
				if(cmd_req_ack & ~cmd_req_error)
				begin
					state <= S_CMD8;
					cmd_req <= 1'b0;
				end
				else
				begin
					cmd_req <= 1'b1;
					cmd_data_len <= 16'd0;
					cmd_r1 <= 8'h01;
					cmd <= {8'd0,8'h00,8'h00,8'h00,8'h00,8'h95};
				end
			end
			S_CMD8:
			begin
				if(cmd_req_ack & ~cmd_req_error)
				begin
                    card_v2<=1;
					state <= response_data[11:0]==12'h1aa ? S_CMD55 : S_ERR;
					cmd_req <= 1'b0;
				end
                else if(cmd_req_ack && cmd_req_error && response_r1==8'h05)begin
                    card_v2<=0;state<=S_CMD55;cmd_req<=0;
                end
				else
				begin
					cmd_req <= 1'b1;
					cmd_data_len <= 16'd4;
					cmd_r1 <= 8'h01;
					cmd <= {8'd8,8'h00,8'h00,8'h01,8'haa,8'h87};
				end
			end
			S_CMD55:
			begin
				if(cmd_req_ack & ~cmd_req_error)
				begin
					state <= S_CMD41;
					cmd_req <= 1'b0;
				end
				else
				begin
					cmd_req <= 1'b1;
					cmd_data_len <= 16'd0;
					cmd_r1 <= 8'h01;
					cmd <= {8'd55,8'h00,8'h00,8'h00,8'h00,8'hff};
				end
			end
			S_CMD41:
			begin
				if(cmd_req_ack & ~cmd_req_error)
				begin
					state <= S_CMD58;
					cmd_req <= 1'b0;
				end
				else if(cmd_req_ack)
				begin
					state <= S_CMD55;
                    cmd_req <= 1'b0;
				end
				else
				begin
					cmd_req <= 1'b1;
					cmd_data_len <= 16'd0;
					cmd_r1 <= 8'h00;
					cmd <= {8'd41,card_v2 ? 32'h40000000 : 32'd0,8'hff};
				end
			end
            S_CMD58:begin
                if(cmd_req_ack)begin
                    cmd_req<=0;
                    if(cmd_req_error||!response_data[31])state<=S_ERR;
                    else begin
                        high_capacity<=card_v2&&response_data[30];
                        state<=card_v2&&response_data[30] ? S_WAIT_READ_WRITE : S_CMD16;
                        if(card_v2&&response_data[30])sd_init_done<=1;
                    end
                end else begin
                    cmd_req<=1;cmd_data_len<=4;cmd_r1<=0;cmd<={8'd58,32'd0,8'hff};
                end
            end
			S_CMD16:
			begin
				if(cmd_req_ack & ~cmd_req_error)
				begin
					state <= S_WAIT_READ_WRITE;
					cmd_req <= 1'b0;
					sd_init_done <= 1'b1;
					spi_clk_div <= SPI_HIGH_SPEED_DIV[15:0];
				end
				else if(cmd_req_ack)
				begin
					state <= S_CMD55;
				end
				else
				begin
					cmd_req <= 1'b1;
					cmd_data_len <= 16'd0;
					cmd_r1 <= 8'h00;
					cmd <= {8'd16,32'd512,8'hff};
				end
			end			
			S_WAIT_READ_WRITE:
			begin
				if(sd_sec_write ==  1'b1)
				begin
					state <= S_CMD24;
					sec_addr <= high_capacity ? sd_sec_write_addr : sd_sec_write_addr<<9;
				end
				else if(sd_sec_read == 1'b1)
				begin
                    read_retries<=0;
					state <= S_CMD17;
					sec_addr <= high_capacity ? sd_sec_read_addr : sd_sec_read_addr<<9;
				end

				spi_clk_div <= SPI_HIGH_SPEED_DIV[15:0];
			end
			S_CMD24:
			begin
				if(cmd_req_ack & ~cmd_req_error)
				begin
					state <= S_WRITE;
					cmd_req <= 1'b0;
				end
				else
				begin
					cmd_req <= 1'b1;
					cmd_data_len <= 16'd0;
					cmd_r1 <= 8'h00;
					cmd <= {8'd24,sec_addr,8'hff};

				end
			end
			S_WRITE:
			begin
				if(block_write_req_ack == 1'b1)
				begin
					block_write_req <= 1'b0;
					state <= S_WRITE_END;
				end
				else
					block_write_req <= 1'b1;
			end
			S_CMD17:
			begin
				if(cmd_req_ack & ~cmd_req_error)
				begin
					state <= S_READ;
					cmd_req <= 1'b0;
				end
                else if(cmd_req_ack)begin
                    cmd_req<=0;
                    if(read_retries==3)state<=S_READ_END;
                    else read_retries<=read_retries+1'b1;
                end
				else
				begin
					cmd_req <= 1'b1;
					cmd_data_len <= 16'd0;
					cmd_r1 <= 8'h00;
					cmd <= {8'd17,sec_addr,8'hff};
				end
			end
			S_READ:
			begin
                if(cmd_req_error)begin
                    block_read_req<=0;
                    if(read_retries==3)state<=S_READ_END;
                    else begin read_retries<=read_retries+1'b1;state<=S_CMD17;end
                end
				else if(block_read_req_ack)
				begin
					state <= S_READ_END;
					block_read_req <= 1'b0;
				end
				else
				begin
					block_read_req <= 1'b1;
				end
			end
			S_WRITE_END:
			begin
				state <= S_WAIT_READ_WRITE;
			end
			S_READ_END:
			begin
				state <= S_WAIT_READ_WRITE;
			end
            S_ERR:begin
                cmd_req<=0;block_read_req<=0;block_write_req<=0;sd_init_done<=0;
            end
			default:
				state <= S_IDLE;
		endcase
    end
end
endmodule
