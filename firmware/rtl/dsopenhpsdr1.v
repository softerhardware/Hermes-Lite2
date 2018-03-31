// OpenHPSDR downstream (PC->Card) protocol unpacker

module dsopenhpsdr1 (
  clk,
  eth_port,
  eth_broadcast,
  eth_valid,
  eth_data,
  eth_unreachable,
  eth_metis_discovery,

  run,
  wide_spectrum,

  rx_fifo_data,
  rx_fifo_valid
);

input           clk;

input   [15:0]  eth_port;
input           eth_broadcast;
input           eth_valid;
input   [ 7:0]  eth_data;
input           eth_unreachable;
output          eth_metis_discovery;

output logic    run = 1'b0;
output logic    wide_spectrum = 1'b0;

output  [ 7:0]  rx_fifo_data;
output          rx_fifo_valid;

localparam START        = 'h0,
           PREAMBLE     = 'h1,
           DECODE       = 'h2,
           RUNSTOP      = 'h3,
           DISCOVERY    = 'h4,
           ENDPOINT     = 'h5,
           SEQNO1       = 'h6,
           SEQNO2       = 'h7,
           SEQNO3       = 'h8,           
           SEQNO4       = 'ha,
           FRAMES       = 'hb;

logic   [ 3:0]  state = START;
logic   [ 3:0]  state_next;

logic   [ 9:0]  count = 10'h000;
logic   [ 9:0]  count_next; 

logic           run_next;
logic           wide_spectrum_next;

// State
always @ (posedge clk) begin
  count <= count_next;
  if (eth_unreachable) begin
    state <= START;
    run <= 1'b0;
    wide_spectrum <= 1'b0;
  end else if (~eth_valid) begin
    state <= START;
  end else begin
    state <= state_next;
    run <= run_next;
    wide_spectrum <= wide_spectrum_next;
  end
end

// FSM Combinational
always @* begin

  // Next State
  state_next = START;
  run_next = run;
  wide_spectrum_next = wide_spectrum;
  count_next = 10'h000;

  // Combinational output
  eth_metis_discovery = 1'b0;
  rx_fifo_valid = 1'b0;

  case (state)
    START: begin
      if ((eth_data == 8'hef) & (eth_port == 1024)) state_next = PREAMBLE;
    end

    PREAMBLE: begin
      if ((eth_data == 8'hfe) & (eth_port == 1024)) state_next = DECODE;
    end

    DECODE: begin
      if (eth_data == 8'h01) state_next = ENDPOINT;
      else if (eth_data == 8'h04) state_next = RUNSTOP;
      else if ((eth_data == 8'h02) & eth_broadcast) state_next = DISCOVERY;
    end

    RUNSTOP: begin
      run_next = eth_data[0];
      wide_spectrum_next = eth_data[1];
    end

    DISCOVERY: begin
      eth_metis_discovery = 1'b1;
    end

    ENDPOINT: begin
      // FIXME: Can use end point for other information
      if (eth_data == 8'h02) state_next = SEQNO1;
    end

    SEQNO1: begin
      state_next = SEQNO2;
    end

    SEQNO2: begin
      state_next = SEQNO3;
    end

    SEQNO3: begin
      state_next = SEQNO4;
    end

    SEQNO4: begin
      state_next = FRAMES;
    end

    FRAMES: begin
      rx_fifo_valid = 1'b1;
      count_next = count + 10'h001;
      if (~(&count)) state_next = FRAMES;
    end

    default: begin
      state_next = START;
    end

  endcase
end

assign rx_fifo_data = eth_data;

endmodule

