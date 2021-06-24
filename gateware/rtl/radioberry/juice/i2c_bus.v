`timescale 1ns / 1ps

module i2c_bus
(
  clk,
  rst,
  
  //slow adc
  sample,
  
  ain0,
  ain1,
  ain2,
  ain3,

  cmd_addr,
  cmd_data,
  cmd_rqst,
  cmd_ack,
  cmd_resp_data,

  read_done,
  ready,

  scl_i,
  scl_o,
  scl_t,
  sda_i,
  sda_o,
  sda_t
);

input			clk;
input			rst;

input			sample;

output [11:0] 	ain0;
output [11:0]	ain1;
output [11:0]	ain2;
output [11:0]	ain3;

// Command slave interface
input  [5:0]  cmd_addr;
input  [31:0] cmd_data;
input         cmd_rqst;
output        cmd_ack;
output [31:0] cmd_resp_data;

output  logic read_done;
output        ready;

input         scl_i;
output        scl_o;
output        scl_t;
input         sda_i;
output        sda_o;
output        sda_t;

logic [6:0]   cmd_address;
logic         cmd_start;
logic         cmd_read;
logic         cmd_write;
logic         cmd_write_multiple;
logic         cmd_stop;
logic         cmd_valid;
logic         cmd_ready;

logic [7:0]   data_in;
logic         data_in_valid;
logic         data_in_ready;
logic         data_in_last;

logic [7:0]   data_out;
logic         data_out_valid;
logic         data_out_ready;
logic         data_out_last;

logic [4:0]   state, state_next;
logic         busy, missed_ack;

logic [6:0]   cmd_reg, cmd_next;
logic [7:0]   data0_reg, data0_next, data1_reg, data1_next;

logic         cmd_ack_reg, cmd_ack_next;

logic [6:0]   filter_select_reg, filter_select_next;
logic         rx_antenna_reg, rx_antenna_next;

logic [31:0]  resp_data_next, resp_data=32'h00000000;

logic [3:0]  msbnibble;


// Control
localparam [4:0]
  STATE_IDLE          = 5'h0,
  STATE_CMDADDR       = 5'h1,
  STATE_WRITE_DATA0   = 5'h2,
  STATE_WRITE_DATA1   = 5'h3,
  STATE_FCMDADDR      = 5'h5,
  STATE_WRITE_FDATA0  = 5'h6,
  STATE_WRITE_FDATA1  = 5'h7,
  STATE_WRITE_FDATA2  = 5'h4,
  STATE_READ_CMDADDR  = 5'h8,
  STATE_READ_DATA0    = 5'h9,
  STATE_READ_DATA1    = 5'ha,
  STATE_READ_DATA2    = 5'hb,
  STATE_READ_DATA3    = 5'hc,
  STATE_READ_DATA4    = 5'hd,
  READ0  = 5'h10,
  READ1  = 5'h11,
  READ2  = 5'h12,
  READ3  = 5'h13,
  READ4  = 5'h14,
  READ5  = 5'h15,
  READ6  = 5'h16,
  READ7  = 5'h17,
  WRITE0 = 5'h18,
  WRITE1 = 5'h19;

always @(posedge clk) begin
  if (rst) begin
    state <= STATE_IDLE;
    cmd_reg <= 'h0;
    data0_reg <= 'h0;
    data1_reg <= 'h0;
    cmd_ack_reg <= 1'b0;
    filter_select_reg <= 'h0;
    rx_antenna_reg <= 1'b0;
  end else begin
    state <= state_next;
    cmd_reg <= cmd_next;
    data0_reg <= data0_next;
    data1_reg <= data1_next;
    cmd_ack_reg <= cmd_ack_next;
    filter_select_reg <= filter_select_next;
    rx_antenna_reg <= rx_antenna_next;
  end
  resp_data <= resp_data_next;
end

assign cmd_address = cmd_reg;
assign cmd_start = 1'b0;
assign cmd_write_multiple = 1'b0;

assign data_in_last = 1'b1;

assign data_out_ready = 1'b1;

assign cmd_ack = cmd_ack_reg;

assign cmd_resp_data = resp_data;


always @* begin
  state_next = state;
  resp_data_next = resp_data;
  cmd_ack_next = cmd_ack;
  filter_select_next = filter_select_reg;
  rx_antenna_next = rx_antenna_reg;

  cmd_next = cmd_reg;
  data0_next = data0_reg;
  data1_next = data1_reg;


  cmd_valid = 1'b1;
  cmd_write = 1'b0;
  cmd_read  = 1'b0;
  cmd_stop = 1'b0;
  read_done = 1'b0;

  data_in = data0_reg;
  data_in_valid = 1'b0;

  ready = 1'b0;

  case(state)

    STATE_IDLE: begin
      cmd_valid = 1'b0;
      cmd_ack_next = 1'b1;
      ready = ~busy;
	  
      if (cmd_rqst) begin
			if (cmd_addr == 6'h3d) begin
			  // Must send
			  if (~busy) begin
				cmd_next = cmd_data[22:16];
				data0_next  = cmd_data[15:8];
				data1_next = cmd_data[7:0];
				state_next = cmd_data[24] ? STATE_READ_CMDADDR : STATE_CMDADDR;
			  end else begin
				cmd_ack_next = 1'b0; // Missed
			  end
			end
			// Filter select update
			if (cmd_addr == 6'h00) begin
			  if ((cmd_data[23:17] != filter_select_reg) | (cmd_data[13] != rx_antenna_reg)) begin
				// Must send
				if (~busy) begin
				  filter_select_next = cmd_data[23:17];
				  rx_antenna_next = cmd_data[13];
				  cmd_next = 'h20;
				  data0_next = 'h0a;
				  // Alex rx antenna option passed to GP7 on MCP23008 GP7
				  data1_next = {cmd_data[13],cmd_data[23:17]};
				  state_next = STATE_FCMDADDR;
				end else begin
				  cmd_ack_next = 1'b0; // Missed
				end
			  end          
			end		
      end else if (sample & ~busy) begin
			cmd_next = 7'h34;
			data0_next = 8'h07;
			state_next = WRITE0;
		end
    end

    STATE_CMDADDR: begin
      cmd_write = 1'b1;
      if (cmd_ready) state_next = STATE_WRITE_DATA0;
    end

    STATE_WRITE_DATA0: begin
      cmd_write = 1'b1;
      data_in_valid = 1'b1;
      data_in = data0_reg;
      if (data_in_ready) state_next = STATE_WRITE_DATA1;
    end

    STATE_WRITE_DATA1: begin
      cmd_write = 1'b1;
      data_in_valid = 1'b1;
      data_in = data1_reg;
      if (data_in_ready) state_next = STATE_IDLE;
    end

    STATE_READ_CMDADDR: begin
      cmd_ack_next = 1'b0; // Hold ack low until read data is ready
      cmd_write = 1'b1;
      cmd_stop = 1'b1;
      if (cmd_ready) state_next = STATE_READ_DATA0;
    end

    STATE_READ_DATA0: begin
      cmd_read = 1'b1;
      data_in_valid = 1'b1;
      data_in = data0_reg;
      if (data_in_ready) state_next = STATE_READ_DATA1;
    end

    STATE_READ_DATA1: begin
      cmd_read = 1'b1;
      resp_data_next = {resp_data[31:8],data_out};
      if (data_out_valid) state_next = STATE_READ_DATA2;
    end

    STATE_READ_DATA2: begin
      cmd_read = 1'b1;
      resp_data_next = {resp_data[31:16],data_out,resp_data[7:0]};
      if (data_out_valid) state_next = STATE_READ_DATA3;
    end

    STATE_READ_DATA3: begin
      cmd_read = 1'b1;
      resp_data_next = {resp_data[31:24],data_out,resp_data[15:0]};
      if (data_out_valid) state_next = STATE_READ_DATA4;
    end

    STATE_READ_DATA4: begin
      cmd_stop = 1'b1;
      cmd_read = 1'b1;
      resp_data_next = {data_out,resp_data[23:0]};
      if (data_out_valid) begin
        read_done = 1'b1;
        state_next = STATE_IDLE;
      end
    end

    STATE_FCMDADDR: begin
      cmd_write = 1'b1;
      if (cmd_ready) state_next = STATE_WRITE_FDATA0;
    end

    STATE_WRITE_FDATA0: begin
      cmd_write = 1'b1;
      data_in_valid = 1'b1;
      data_in = data0_reg;
      if (data_in_ready) state_next = STATE_WRITE_FDATA1;
    end

    STATE_WRITE_FDATA1: begin
      cmd_write = 1'b1;
      data_in_valid = 1'b1;
      data_in = data1_reg;
      if (data_in_ready) state_next = STATE_WRITE_FDATA2;
    end

    STATE_WRITE_FDATA2: begin
      cmd_write = 1'b1;
      data_in_valid = 1'b1;
      data_in = 'h00;
      if (data_in_ready) state_next = STATE_IDLE;
    end
	
	// slow adc	
	WRITE0: begin
      cmd_read = 1'b0;
      cmd_write = 1'b1;
      cmd_stop = 1'b1;
      if (cmd_ready) state_next = WRITE1;
    end

    WRITE1: begin
      data_in_valid = 1'b1;
      if (data_in_ready) state_next = READ0;
    end

    READ0: begin  cmd_read = 1'b1; if (data_out_valid) state_next = READ1; end
    READ1: begin  cmd_read = 1'b1; if (data_out_valid) state_next = READ2; end
    READ2: begin  cmd_read = 1'b1; if (data_out_valid) state_next = READ3; end
    READ3: begin  cmd_read = 1'b1; if (data_out_valid) state_next = READ4; end
    READ4: begin  cmd_read = 1'b1; if (data_out_valid) state_next = READ5; end
    READ5: begin  cmd_read = 1'b1; if (data_out_valid) state_next = READ6; end
    READ6: begin  cmd_read = 1'b1; if (data_out_valid) state_next = READ7; end

    READ7: begin
	  cmd_read = 1'b1; 
      cmd_stop = 1'b1;
      if (data_out_valid) state_next = STATE_IDLE;
    end

  endcase
end

always @(posedge clk) begin
  if (data_out_valid & state[4]) begin
    if (~state[0]) msbnibble <= data_out[3:0];

    case(state)
      READ1: ain0 <= {msbnibble,data_out};
      READ3: ain1 <= {msbnibble,data_out};
      READ5: ain2 <= {msbnibble,data_out};
      READ7: ain3 <= {msbnibble,data_out};
    endcase
  end
end

i2c_master i2c_master_i (
  .clk(clk),
  .rst(rst),
  /*
   * Host interface
   */
  .cmd_address(cmd_address),
  .cmd_start(cmd_start),
  .cmd_read(cmd_read),
  .cmd_write(cmd_write),
  .cmd_write_multiple(cmd_write_multiple),
  .cmd_stop(cmd_stop),
  .cmd_valid(cmd_valid),
  .cmd_ready(cmd_ready),

  .data_in(data_in),
  .data_in_valid(data_in_valid),
  .data_in_ready(data_in_ready),
  .data_in_last(data_in_last),

  .data_out(data_out),
  .data_out_valid(data_out_valid),
  .data_out_ready(data_out_ready),
  .data_out_last(data_out_last),

  // I2C
  .scl_i(scl_i),
  .scl_o(scl_o),
  .scl_t(scl_t),
  .sda_i(sda_i),
  .sda_o(sda_o),
  .sda_t(sda_t),

  // Status
  .busy(busy),
  .bus_control(),
  .bus_active(),
  .missed_ack(missed_ack),

  // Configuration
  .prescale(16'h0002),
  .stop_on_idle(1'b1)
);

endmodule


