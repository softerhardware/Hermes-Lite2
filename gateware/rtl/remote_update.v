
// See http://billauer.co.il/blog/2017/06/remote-update-intel-fpga-cyclone-iv/

module remote_update (
  clk,
  rst,
  reboot,
  factory
  //debug
 );

input clk;
input rst;
input reboot;
input factory;
//output logic [3:0] debug = 4'b1110;

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
  START           = 4'b0000,
  READ_MODE1      = 4'b0001,
  READ_MODE2      = 4'b0010,
  READ_MODE3      = 4'b0011,
  READ_STATUS1    = 4'b0100,
  READ_STATUS2    = 4'b0101,
  READ_STATUS3    = 4'b0110,
  WRITE_WATCHDOG1 = 4'b0111,
  WRITE_WATCHDOG2 = 4'b1000,
  WRITE_WATCHDOG3 = 4'b1001,
  WRITE_ADDR1     = 4'b1010,
  WRITE_ADDR2     = 4'b1011,
  WRITE_ADDR3     = 4'b1100,
  RECONFIG        = 4'b1101,
  DONE            = 4'b1110;


logic   [ 3:0]  state = START;
logic   [ 3:0]  state_next;

//logic   [ 3:0]  debug_next;

always @ (posedge clk) begin
  if (rst) begin
    state <= START;
    //debug <= 4'b1110;
  end else begin
    state <= state_next;
    //debug <= debug_next;
  end
end

// FSM Combinational
always @* begin

  // Next State
  state_next = state;
  //debug_next = debug;

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
      // If in app mode, go to DONE_APP
      //state_next = data_out[0] ? DONE : READ_STATUS1;
      if (data_out[0] | factory) begin
        //debug_next = {2'b00,data_out[1:0]};
        state_next = DONE;
      end else begin
        //debug_next = {2'b10,data_out[1:0]};
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
        //debug_next = {1'b0,data_out[3],data_out[1:0]};
        // Reboot since mode is factory image
        // and last config had no problems except
        // for possible logic trigger of reconfig
        state_next = WRITE_WATCHDOG1;
      end else begin
        //debug_next = {1'b1,data_out[3],data_out[1:0]};
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
      state_next = WRITE_ADDR1;
    end

    WRITE_ADDR1: begin
      write_param = 1'b1;
      param = 3'b100;
      state_next = WRITE_ADDR2;
    end

    WRITE_ADDR2: begin
      //write_param = 1'b1;
      param = 3'b100;
      if (~busy) begin
        state_next = WRITE_ADDR3;
      end
    end

    WRITE_ADDR3: begin
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
