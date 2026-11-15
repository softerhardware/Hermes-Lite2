// See http://billauer.co.il/blog/2017/06/remote-update-intel-cyclone-iv/
//
// Multi-gateware boot selection.
//
// The app image cannot pass a boot-slot request to the factory (golden)
// image through CONFIG_ADDR: an app logic-triggered reconfig does not
// preserve that parameter across the reconfiguration (verified on
// hardware). The Versa5 clock chip is a separate device whose volatile
// register 0x80 does survive reconfiguration but resets to 0 on power
// loss, so it carries the request. The host stages the slot number there
// with the existing write_versa5(0x80, N) software path, then issues the
// plain reboot command (0x3a, data 1). i2c.v reads register 0x80 during
// the Versa init sequence (STATE_CLINITBS1/2) and presents it as
// bootsel = {valid, slot[1:0]}.
//
// The golden image boots after any logic-triggered reconfig and boots the
// slot requested through Versa register 0x80:
//
//   bootsel[2] valid -> act on bootsel[1:0] (i2c.v passes the low two bits
//     of the Versa byte unchanged):
//       2'b00 -> slot 2 (previous default behavior; also the POR value)
//       2'b01 -> slot 1
//       2'b10 -> stay in the golden image: go to DONE without writing
//                CONFIG_ADDR and without reconfiguring
//       2'b11 -> slot 3
//   bootsel[2] clear (Versa read did not complete; the hardware watchdog
//                        recovers and the next golden boot stays in the
//                        factory image) -> default slot 2.
//
// There is no round-robin: the CONFIG_ADDR value the golden image booted
// from never influences the next choice. A cold power-up (Versa register
// 0x80 = 0) boots slot 2 like the stock golden image.

module remote_update (
  clk,
  rst,
  reboot,
  factory,
  bootsel,
  bootsel_done
 );

input clk;
input rst;
input reboot;
input factory;
// Boot-slot request from i2c.v (Versa volatile register 0x80): bit [2]
// valid (register has been read), bits [1:0] slot number 0-3.
input [ 2:0] bootsel;
// Held high by i2c.v once the boot-slot read has completed. The factory
// decision FSM runs far faster than the i2c Versa init sequence, so
// READ_ADDR3 waits on this before choosing a slot. If the Versa read never
// completes, bootsel_done never asserts and the hardware watchdog forces a
// reconfiguration (see the header comment).
input          bootsel_done;

logic        read_param        ;
logic [ 2:0] param             ;
logic        reset_timer = 1'b0;
logic        busy              ;
logic [28:0] data_out          ;
logic [ 1:0] read_source       ;
logic        write_param       ;
logic [23:0] data_in           ;
logic        reconfig          ;


localparam
  START           = 5'b00000,
  READ_MODE1      = 5'b00001,
  READ_MODE2      = 5'b00010,
  READ_MODE3      = 5'b00011,
  READ_STATUS1    = 5'b00100,
  READ_STATUS2    = 5'b00101,
  READ_STATUS3    = 5'b00110,
  WRITE_WATCHDOG1 = 5'b00111,
  WRITE_WATCHDOG2 = 5'b01000,
  WRITE_WATCHDOG3 = 5'b01001,
  WRITE_ADDR1     = 5'b01010,
  WRITE_ADDR2     = 5'b01011,
  WRITE_ADDR3     = 5'b01100,
  RECONFIG        = 5'b01101,
  DONE            = 5'b01110,
  READ_ADDR1      = 5'b10111,
  READ_ADDR2      = 5'b11000,
  READ_ADDR3      = 5'b11001,
  WRITE2_ADDR1    = 5'b11010,
  WRITE2_ADDR2    = 5'b11011,
  WRITE2_ADDR3    = 5'b11100,
  WRITE3_ADDR1    = 5'b11101,
  WRITE3_ADDR2    = 5'b11110,
  WRITE3_ADDR3    = 5'b11111;


logic   [ 4:0]  state = START;
logic   [ 4:0]  state_next;


always @ (posedge clk) begin
  if (rst) begin
    state <= START;
  end else begin
    state <= state_next;
  end
end

// FSM Combinational
always @* begin

  // Next State
  state_next = state;

  // Combinational output
  read_param = 1'b0;
  param = 3'b000;
  read_source = 2'b00;
  write_param = 1'b0;
  data_in = 24'h100000;
  reconfig = 1'b0;

  case (state)
    START: begin
      if (~busy) begin
        state_next = READ_MODE1;
      end
    end

    READ_MODE1: begin
      read_param = 1'b1;
      state_next = READ_MODE2;
    end

    READ_MODE2: begin
      if (~busy) state_next = READ_MODE3;
    end

    READ_MODE3: begin
      // If in app mode, go to DONE
      if (data_out[0] | factory) begin
        state_next = DONE;
      end else begin
        state_next = READ_STATUS1;
      end
    end

    READ_STATUS1: begin
      read_param = 1'b1;
      param = 3'b111;
      read_source = 2'b01;
      state_next = READ_STATUS2;
    end

    READ_STATUS2: begin
      param = 3'b111;
      read_source = 2'b01;
      if (~busy) state_next = READ_STATUS3;
    end

    READ_STATUS3: begin
      if (data_out[4:1] == 4'b0000) begin
        // Reboot since mode is factory image
        // and last config had no problems except
        // for possible logic trigger of reconfig
        state_next = WRITE_WATCHDOG1;
      end else begin
        // Stay in factory image
        state_next = DONE;
      end
    end

    WRITE_WATCHDOG1: begin
      write_param = 1'b1;
      param = 3'b010;
      data_in = 24'h000010;
      state_next = WRITE_WATCHDOG2;
    end

    WRITE_WATCHDOG2: begin
      param = 3'b010;
      data_in = 24'h000010;
      if (~busy) state_next = WRITE_WATCHDOG3;
    end

    WRITE_WATCHDOG3: begin
      param = 3'b010;
      data_in = 24'h000010;
      state_next = READ_ADDR1;
    end

    // Read CONFIG_ADDR back. Kept as a settling delay after the watchdog
    // write; the value is no longer used for slot selection (no
    // round-robin). Reads are shifted up 2 bits relative to writes, so
    // flash address bits [20:19] would appear on data_out[22:21] (p2.txt).
    READ_ADDR1: begin
      read_param = 1'b1;
      param = 3'b100;
      read_source = 2'b01;
      state_next = READ_ADDR2;
    end

    READ_ADDR2: begin
      param = 3'b100;
      read_source = 2'b01;
      if (~busy) state_next = READ_ADDR3;
    end

    READ_ADDR3: begin
      if (!bootsel_done) begin
        // Wait for the Versa boot-slot read. If it never completes, the
        // hardware watchdog armed above forces a reconfiguration.
        state_next = READ_ADDR3;
      end else if (bootsel[2] & bootsel[1:0] == 2'd0) begin
        // Slot 2 (0x100000): the stock default address. Covers a Versa
        // value of 0 (power on) and an explicit request for slot 2.
        state_next = WRITE_ADDR1;
      end else if (bootsel[2] & bootsel[1:0] == 2'd1) begin
        // Versa staged request for slot 1.
        state_next = WRITE2_ADDR1;
      end else if (bootsel[2] & bootsel[1:0] == 2'd2) begin
        // Stay in the golden image: go to DONE without writing
        // CONFIG_ADDR and without reconfiguring, like the READ_STATUS3
        // error path. A later reboot from golden falls through to the
        // factory image again while Versa keeps requesting slot 2 code.
        state_next = DONE;
      end else if (bootsel[2] & bootsel[1:0] == 2'd3) begin
        // Versa staged request for slot 3.
        state_next = WRITE3_ADDR1;
      end else begin
        // bootsel invalid (Versa read did not complete before the
        // watchdog, or i2c init still running): default slot 2.
        state_next = WRITE_ADDR1;
      end
    end

    // Slot 2: 0x100000
    WRITE_ADDR1: begin
      data_in = 24'h100000;
      write_param = 1'b1;
      param = 3'b100;
      state_next = WRITE_ADDR2;
    end

    WRITE_ADDR2: begin
      data_in = 24'h100000;
      param = 3'b100;
      if (~busy) begin
        state_next = WRITE_ADDR3;
      end
    end

    WRITE_ADDR3: begin
      data_in = 24'h100000;
      param = 3'b100;
      state_next = RECONFIG;
    end

    // Slot 1: 0x080000
    WRITE2_ADDR1: begin
      data_in = 24'h080000;
      write_param = 1'b1;
      param = 3'b100;
      state_next = WRITE2_ADDR2;
    end

    WRITE2_ADDR2: begin
      data_in = 24'h080000;
      param = 3'b100;
      if (~busy) begin
        state_next = WRITE2_ADDR3;
      end
    end

    WRITE2_ADDR3: begin
      data_in = 24'h080000;
      param = 3'b100;
      state_next = RECONFIG;
    end

    // Slot 3: 0x180000
    WRITE3_ADDR1: begin
      data_in = 24'h180000;
      write_param = 1'b1;
      param = 3'b100;
      state_next = WRITE3_ADDR2;
    end

    WRITE3_ADDR2: begin
      data_in = 24'h180000;
      param = 3'b100;
      if (~busy) begin
        state_next = WRITE3_ADDR3;
      end
    end

    WRITE3_ADDR3: begin
      data_in = 24'h180000;
      param = 3'b100;
      state_next = RECONFIG;
    end

    RECONFIG: begin
      reconfig = 1'b1;
      state_next = RECONFIG;
    end

    DONE: begin
      reconfig = reboot;
      state_next = DONE;
    end

    default: begin
      state_next = START;
    end

  endcase
end


always @ (posedge clk) reset_timer <= ~reset_timer;

altera_remote_update_core remote_update_core (
  .read_param  (read_param),
  .param       (param),
  .reconfig    (reconfig),
  .reset_timer (reset_timer),
  .clock       (clk),
  .reset       (rst),
  .busy        (busy),
  .data_out    (data_out),
  .read_source (read_source),
  .write_param (write_param),
  .data_in     (data_in),
  .ctl_nupdt   (1'b0)
);

endmodule
