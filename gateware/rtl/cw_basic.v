

module cw_basic (
  input         clk               ,
  input  [ 5:0] cmd_addr          ,
  input  [31:0] cmd_data          ,
  input         cmd_rqst          ,
  input         msec_pulse        ,
  input         dot_key           ,
  input         dash_key          ,
  input         dot_key_debounced ,
  input         dash_key_debounced,
  input         cwx               ,
  output        cw_power_on       ,
  output        cw_keydown
);

localparam
  IDLE = 2'b00,
  PREKEY = 2'b01,
  KEY = 2'b11,
  POSTKEY = 2'b10;

logic [1:0]   state_next, state = IDLE;

// Delay CW for 8ms to allow for T/R switch
logic [7:0]   cw_delay_line = 8'h00;
logic [9:0]   cw_hang_time;
logic [9:0]   cw_hang_counter_next, cw_hang_counter;

always @(posedge clk) begin
  if (cmd_rqst) begin
    if (cmd_addr == 6'h10) begin
      cw_hang_time <= {cmd_data[31:24], cmd_data[17:16]};
    end
  end
end

always @(posedge clk) begin
  if (msec_pulse) begin
    state <= state_next;
    cw_hang_counter <= cw_hang_counter_next;
    cw_delay_line <= {cw_delay_line[6:0], (dot_key_debounced | cwx)};
  end
end

// FSM Combinational
always @* begin

  state_next = state;
  // Include 4 ms for signal decay
  cw_hang_counter_next = cw_hang_time + 10'h04;

  cw_power_on = 1'b0;
  cw_keydown = 1'b0;

  case (state)

    IDLE: begin
      if (dot_key_debounced | cwx) state_next = PREKEY;
    end

    PREKEY: begin
      cw_power_on = 1'b1;
      if (cw_delay_line[7]) state_next = KEY;
      else if (cw_delay_line == 8'h00) state_next = IDLE;
    end

    KEY: begin
      cw_power_on = 1'b1;
      cw_keydown = 1'b1;
      if (~cw_delay_line[7]) state_next = POSTKEY;
    end

    POSTKEY: begin
      cw_power_on = 1'b1;
      cw_hang_counter_next = cw_hang_counter - 10'h01;
      if (cw_hang_counter == 10'h00) state_next = IDLE;
      else if (dot_key_debounced | cwx) state_next = PREKEY;
    end
  endcase
end

endmodule