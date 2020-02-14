module led_flash (
  clk,
  cnt,
  sig,
  led
);
input       clk;
input       cnt;
input       sig;
output      led;

localparam  STATE_CLR   = 2'b00,
            STATE_SET   = 2'b01,
            STATE_WAIT1 = 2'b10,
            STATE_WAIT2 = 2'b11;

logic [1:0] state = STATE_CLR;
logic [1:0] state_next;

always @(posedge clk) state <= state_next;

// LED remains on for 2-3 ticks of cnt
always @* begin
  state_next = state;

  case (state)
    STATE_CLR: begin
      led = 1'b1; // 1 clears LED
      if (sig) state_next = STATE_SET;
    end

    STATE_SET: begin
      led = 1'b0;
      if (cnt) state_next = STATE_WAIT1;
    end

    STATE_WAIT1: begin
      led = 1'b0;
      if (cnt) state_next = STATE_WAIT2;
    end

    STATE_WAIT2: begin
      led = 1'b0;
      if (cnt) state_next = STATE_CLR;
    end
  endcase
end

endmodule
