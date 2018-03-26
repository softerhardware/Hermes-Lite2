module radio (

  clk_ad9866,

  ptt,

  // Transmit
  tx_tdata,
  tx_tid,
  tx_tlast,
  tx_tready,
  tx_tvalid,

  tx_cw_key,
  tx_cw_level,
  tx_data_dac,

  // Optional audio stream for repurposed programming
  lr_tdata,
  lr_tid,
  lr_tlast,
  lr_tready,
  lr_tvalid,

  // Receive
  rx_data_adc,

  rx_tdata,
  rx_tid,
  rx_tlast,
  rx_tready,
  rx_tvalid,

  // Wishbone slave interface
  wbs_adr_i,
  wbs_dat_i,
  wbs_we_i,
  wbs_stb_i,
  wbs_ack_o,
  wbs_cyc_i
);


parameter         WB_DATA_WIDTH = 32;
parameter         WB_ADDR_WIDTH = 6;

parameter         NR = 3;
parameter         NT = 1;
parameter         PREDISTORT = 0;
parameter         CLK_FREQ = 76800000;

// B57 = 2^57.   M2 = B57/OSC
// 61440000
//localparam M2 = 32'd2345624805;
// 61440000-400
//localparam M2 = 32'd2345640077;
localparam M2 = (CLK_FREQ == 61440000) ? 32'd2345640077 : (CLK_FREQ == 79872000) ? 32'd1804326773 : (CLK_FREQ == 76800000) ? 32'd1876499845 : 32'd1954687338;

// M3 = 2^24 to round as version 2.7
localparam M3 = 32'd16777216;

localparam CICRATE = (CLK_FREQ == 61440000) ? 6'd10 : (CLK_FREQ == 79872000) ? 6'd13 : (CLK_FREQ == 76800000) ? 6'd05 : 6'd08;
localparam GBITS = (CLK_FREQ == 61440000) ? 30 : (CLK_FREQ == 79872000) ? 31 : (CLK_FREQ == 76800000) ? 31 : 31;
localparam RRRR = (CLK_FREQ == 61440000) ? 160 : (CLK_FREQ == 79872000) ? 208 : (CLK_FREQ == 76800000) ? 200 : 192;

// Decimation rates
localparam RATE48  = (CLK_FREQ == 61440000) ? 6'd16 : (CLK_FREQ == 79872000) ? 6'd16 : (CLK_FREQ == 76800000) ? 6'd40 : 6'd24;
localparam RATE96  =  RATE48  >> 1;
localparam RATE192 =  RATE96  >> 1;
localparam RATE384 =  RATE192 >> 1;


input             clk_ad9866;

input             ptt;

input   [31:0]    tx_tdata;
input   [ 2:0]    tx_tid;
input             tx_tlast;
output            tx_tready;
input             tx_tvalid;

input   [31:0]    lr_tdata;
input   [ 2:0]    lr_tid;
input             lr_tlast;
output            lr_tready;
input             lr_tvalid;

input             tx_cw_key;
input   [17:0]    tx_cw_level;
output  [11:0]    tx_data_dac;

input   [11:0]    rx_data_adc;

output  [29:0]    rx_tdata;
output  [ 4:0]    rx_tid;
output            rx_tlast;
input             rx_tready;
output            rx_tvalid;


// Wishbone slave interface
input  [WB_ADDR_WIDTH-1:0]  wbs_adr_i;
input  [WB_DATA_WIDTH-1:0]  wbs_dat_i;
input                       wbs_we_i;
input                       wbs_stb_i;
output                      wbs_ack_o;   
input                       wbs_cyc_i;

logic [ 1:0]        tx_predistort = 2'b00;
logic [ 1:0]        tx_predistort_next;

logic               pure_signal = 1'b0;
logic               pure_signal_next;

logic               vna = 1'b0;
logic               vna_next;

logic  [ 1:0]       rx_rate = 2'b00;
logic  [ 1:0]       rx_rate_next;

logic  [ 4:0]       last_chan = 5'h0;
logic  [ 4:0]       last_chan_next;

logic  [ 4:0]       chan = 5'h0;
logic  [ 4:0]       chan_next;

logic               duplex = 1'b0;
logic               duplex_next;

logic   [5:0]       rate;
logic   [11:0]      adcpipe [0:3];

logic signed [15:0] tx_fir_i;
logic signed [15:0] tx_fir_q;

logic         req2;
logic [19:0]  y1_r, y1_i;
logic [15:0]  y2_r, y2_i;

logic signed [15:0] tx_cordic_i_out;
logic signed [15:0] tx_cordic_q_out;
logic signed [31:0] tx_phase_word;

logic signed [15:0] tx_i;
logic signed [15:0] tx_q;

logic signed [15:0] txsum;
logic signed [15:0] txsumq;

logic [23:0]  rx_data_i [0:NR-1];
logic [23:0]  rx_data_q [0:NR-1];
logic         rx_data_rdy [0:NR-1];

logic [63:0]  freqcomp;
logic [31:0]  freqcompp [0:3];
logic [5:0]   chanp [0:3];

logic [31:0]  tx_phase [0:NT-1];
logic [31:0]  rx_phase [0:NR-1];

localparam 
  WBS_IDLE    = 2'b00,
  WBS_FREQ1   = 2'b01,
  WBS_FREQ2   = 2'b11,
  WBS_FREQ3   = 2'b10;

logic [1:0]   wbs_state = WBS_IDLE;
logic [1:0]   wbs_state_next;

localparam 
  RXUS_WAIT1  = 2'b00,
  RXUS_I      = 2'b10,
  RXUS_Q      = 2'b11,
  RXUS_WAIT0  = 2'b01;

logic [1:0]   rxus_state = RXUS_WAIT1;
logic [1:0]   rxus_state_next;

// Wishbone Slave State Machine
always @(posedge clk_ad9866) begin
  wbs_state <= wbs_state_next;
  vna <= vna_next;
  rx_rate <= rx_rate_next;
  pure_signal <= pure_signal_next;
  tx_predistort <= tx_predistort_next;
  last_chan <= last_chan_next;
  duplex <= duplex_next;
end

always @* begin
  wbs_state_next = wbs_state;
  wbs_ack_o = 1'b0;
  vna_next = vna;
  rx_rate_next = rx_rate;
  pure_signal_next = pure_signal;
  tx_predistort_next = tx_predistort;
  last_chan_next = last_chan;
  duplex_next = duplex;

  case(wbs_state)

    WBS_IDLE: begin
      if (wbs_we_i & wbs_stb_i) begin
        case (wbs_adr_i)
          // Frequency changes
          6'h01:    wbs_state_next    = WBS_FREQ1;
          6'h02:    wbs_state_next    = WBS_FREQ1;
          6'h03:    wbs_state_next    = WBS_FREQ1;
          6'h04:    wbs_state_next    = WBS_FREQ1;
          6'h05:    wbs_state_next    = WBS_FREQ1;
          6'h06:    wbs_state_next    = WBS_FREQ1;
          6'h07:    wbs_state_next    = WBS_FREQ1;
          6'h08:    wbs_state_next    = WBS_FREQ1;
          6'h12:    wbs_state_next    = WBS_FREQ1;
          6'h13:    wbs_state_next    = WBS_FREQ1;
          6'h14:    wbs_state_next    = WBS_FREQ1;
          6'h15:    wbs_state_next    = WBS_FREQ1;
          6'h16:    wbs_state_next    = WBS_FREQ1;

          // Control with no acknowledge
          6'h00: begin
            rx_rate_next              = wbs_dat_i[25:24];
            last_chan_next            = wbs_dat_i[7:3];
            duplex_next               = wbs_dat_i[2];
          end

          6'h09:    vna_next          = wbs_dat_i[23];
          6'h0a:    pure_signal_next  = wbs_dat_i[22];

          6'h2b: begin
            //predistortion control sub index
            if(wbs_dat_i[31:24]==8'h00) begin
              tx_predistort_next      = wbs_dat_i[17:16];
            end
          end

          default:  wbs_state_next = wbs_state;
        endcase 
      end        
    end

    WBS_FREQ1: begin
      wbs_state_next = WBS_FREQ2;
    end

    WBS_FREQ2: begin
      wbs_state_next = WBS_FREQ3;
    end

    WBS_FREQ3: begin
      wbs_state_next = WBS_IDLE;
      wbs_ack_o = 1'b1;
    end
  endcase
end


// Frequency computation
// Always compute frequency
// This really should be done on the PC and not in the FPGA....
assign freqcomp = wbs_dat_i * M2 + M3;

// Pipeline freqcomp
always @ (posedge clk_ad9866) begin
  // Pipeline to allow 2 cycles for multiply
  if (wbs_state == WBS_FREQ2) begin
    freqcompp[0] <= freqcomp[56:25];
    freqcompp[1] <= freqcomp[56:25];
    freqcompp[2] <= freqcomp[56:25];
    freqcompp[3] <= freqcomp[56:25];
    chanp[0] <= wbs_adr_i;
    chanp[1] <= wbs_adr_i;
    chanp[2] <= wbs_adr_i;
    chanp[3] <= wbs_adr_i;
  end
end

// TX0 and RX0
always @ (posedge clk_ad9866) begin
  if (wbs_state == WBS_FREQ3) begin
    if (chanp[0] == 6'h01) begin 
      tx_phase[0] <= freqcompp[0]; 
      if (!duplex && (last_chan == 5'b00000)) rx_phase[0] <= freqcompp[0];
    end

    if (chanp[0] == 6'h02) begin 
      if (!duplex && (last_chan == 5'b00000)) rx_phase[0] <= tx_phase[0];
      else rx_phase[0] <= freqcompp[0];
    end
  end
end

// TX > 1
genvar c;
generate
  for (c = 1; c < NT; c = c + 1) begin: TXIFFREQ
    always @ (posedge clk_ad9866) begin
      if (wbs_state == WBS_FREQ3) begin
        if (chanp[c/8] == ((c < 7) ? c+2 : c+11)) begin
          tx_phase[c] <= freqcompp[c/8]; 
        end
      end
    end
  end
endgenerate

// RX > 1
generate
  for (c = 1; c < NR; c = c + 1) begin: RXIFFREQ
    always @ (posedge clk_ad9866) begin
      if (wbs_state == WBS_FREQ3) begin
        if (chanp[c/8] == ((c < 7) ? c+2 : c+11)) begin
          rx_phase[c] <= freqcompp[c/8]; 
        end
      end
    end
  end
endgenerate

// Pipeline for adc fanout
always @ (posedge clk_ad9866) begin
  adcpipe[0] <= rx_data_adc;
  adcpipe[1] <= rx_data_adc;
  adcpipe[2] <= rx_data_adc;
  adcpipe[3] <= rx_data_adc;
end

// set the decimation rate 40 = 48k.....2 = 960k
always @ (rx_rate) begin
  case (rx_rate)
    0: rate <= RATE48;     //  48ksps
    1: rate <= RATE96;     //  96ksps
    2: rate <= RATE192;    //  192ksps
    3: rate <= RATE384;    //  384ksps
    default: rate <= RATE48;
  endcase
end

generate
  for (c = 0; c < NR; c = c + 1) begin: MDC
    if((c==3 && NR>3) || (c==1 && NR<=3)) begin
        receiver #(.CICRATE(CICRATE)) receiver_inst (
          .clock(clk_ad9866),
          .rate(rate),
          .frequency(rx_phase[c]),
          .out_strobe(rx_data_rdy[c]),
          .in_data((ptt & pure_signal) ? tx_data_dac : adcpipe[c/8]), //tx_data was pipelined here once
          .out_data_I(rx_data_i[c]),
          .out_data_Q(rx_data_q[c])
        );
    end else begin
        receiver #(.CICRATE(CICRATE)) receiver_inst (
          .clock(clk_ad9866),
          .rate(rate),
          .frequency(rx_phase[c]),
          .out_strobe(rx_data_rdy[c]),
          .in_data(adcpipe[c/8]),
          .out_data_I(rx_data_i[c]),
          .out_data_Q(rx_data_q[c])
        );
    end
  end
endgenerate


// Send RX data upstream
// rx_tdata is:
// rx_tdata[29]    is IQ identifier, I is 0, Q is 1
// rx_tdata[28:24] is RX channel
// rx_tdata[23:0]  is actual 24 bit data

// rx_tid[4:0] is future synchronization identifier
// rx_tlast 

always @(posedge clk_ad9866) begin
  rxus_state <= rxus_state_next;
  chan <= chan_next;
end

always @* begin
  // Sequential
  rxus_state_next = rxus_state;
  chan_next = chan;

  // Combinational
  rx_tdata  = 30'h0;
  rx_tid    = 5'h0;
  rx_tlast  = 1'b0;
  rx_tvalid = 1'b0;

  case(rxus_state)
    RXUS_WAIT1: begin
      chan_next = 5'h0;
      if (rx_data_rdy[0] & rx_tready) begin
        rxus_state_next = RXUS_I;
      end
    end

    RXUS_I: begin
      rx_tvalid = 1'b1;
      rx_tdata = {1'b0,chan,rx_data_i[chan]};
      rxus_state_next = RXUS_Q;
    end

    RXUS_Q: begin
      rx_tvalid = 1'b1;
      rx_tdata = {1'b1,chan,rx_data_q[chan]};

      if (chan == last_chan) begin
        rx_tlast = 1'b1;
        rxus_state_next = RXUS_WAIT0;
      end else begin
        chan_next = chan + 5'h1;
        rxus_state_next = RXUS_I;
      end
    end

    RXUS_WAIT0: begin
      chan_next = 5'h0;
      if (~rx_data_rdy[0]) begin
        rxus_state_next = RXUS_WAIT1;
      end
    end

  endcase // rxus_state
end



//---------------------------------------------------------
//                 Transmitter code
//---------------------------------------------------------

/*
    The gain distribution of the transmitter code is as follows.
    Since the CIC interpolating filters do not interpolate by 2^n they have an overall loss.

    The overall gain in the interpolating filter is ((RM)^N)/R.  So in this case its 2560^4.
    This is normalised by dividing by ceil(log2(2560^4)).

    In which case the normalized gain would be (2560^4)/(2^46) = .6103515625

    The CORDIC has an overall gain of 1.647.

    Since the CORDIC takes 16 bit I & Q inputs but output needs to be truncated to 14 bits, in order to
    interface to the DAC, the gain is reduced by 1/4 to 0.41175

    We need to be able to drive to DAC to its full range in order to maximise the S/N ratio and
    minimise the amount of PA gain.  We can increase the output of the CORDIC by multiplying it by 4.
    This is simply achieved by setting the CORDIC output width to 16 bits and assigning bits [13:0] to the DAC.

    The gain distripution is now:

    0.61 * 0.41174 * 4 = 1.00467

    This means that the DAC output will wrap if a full range 16 bit I/Q signal is received.
    This can be prevented by reducing the output of the CIC filter.

    If we subtract 1/128 of the CIC output from itself the level becomes

    1 - 1/128 = 0.9921875

    Hence the overall gain is now

    0.61 * 0.9921875 * 0.41174 * 4 = 0.996798


*/

// latch I&Q data on strobe from FIR
// FIXME: no backpressure from FIR for now
always @ (posedge clk_ad9866) begin
  if (tx_tready & tx_tvalid) begin
    tx_fir_i = tx_tdata[31:16];
    tx_fir_q = tx_tdata[15:0];
  end
end

// Interpolate I/Q samples from 48 kHz to the clock frequency
FirInterp8_1024 fi (clk_ad9866, req2, tx_tready, tx_fir_i, tx_fir_q, y1_r, y1_i);  // req2 enables an output sample, tx_tready requests next input sample.

// GBITS reduced to 30
CicInterpM5 #(.RRRR(RRRR), .IBITS(20), .OBITS(16), .GBITS(GBITS)) in2 ( clk_ad9866, 1'd1, req2, y1_r, y1_i, y2_r, y2_i);

//---------------------------------------------------------
//    CORDIC NCO
//---------------------------------------------------------

// Code rotates input at set frequency and produces I & Q
// if in VNA mode use the Rx[0] phase word for the Tx
assign tx_phase_word = vna ? rx_phase[0] : tx_phase[0];
assign          tx_i = vna ? 16'h4d80 : (tx_cw_key ? {1'b0, tx_cw_level[17:3]} : y2_i);    // select vna mode if active. Set CORDIC for max DAC output
assign          tx_q = (vna | tx_cw_key) ? 16'h0 : y2_r;                   // taking into account CORDICs gain i.e. 0x7FFF/1.7


// NOTE:  I and Q inputs reversed to give correct sideband out
cpl_cordic #(.OUT_WIDTH(16)) cordic_inst (
  .clock(clk_ad9866), 
  .frequency(tx_phase_word), 
  .in_data_I(tx_i),
  .in_data_Q(tx_q), 
  .out_data_I(tx_cordic_i_out), 
  .out_data_Q(tx_cordic_q_out)
);

/*
  We can use either the I or Q output from the CORDIC directly to drive the DAC.

    exp(jw) = cos(w) + j sin(w)

  When multplying two complex sinusoids f1 and f2, you get only f1 + f2, no
  difference frequency.

      Z = exp(j*f1) * exp(j*f2) = exp(j*(f1+f2))
        = cos(f1 + f2) + j sin(f1 + f2)
*/

// the CORDIC output is stable on the negative edge of the clock

generate
  if (NT == 1) begin: SINGLETX
    //gain of 4
    assign txsum = (tx_cordic_i_out  >>> 2); // + {15'h0000, tx_cordic_i_out[1]};
    assign txsumq = (tx_cordic_q_out  >>> 2);

  end else begin: DUALTX
    logic signed [15:0] tx_cordic_tx2_i_out;
    logic signed [15:0] tx_cordic_tx2_q_out;

    cpl_cordic #(.OUT_WIDTH(16)) cordic_tx2_inst (
      .clock(clk_ad9866), 
      .frequency(tx_phase[1]), 
      .in_data_I(tx_i),
      .in_data_Q(tx_q), 
      .out_data_I(tx_cordic_tx2_i_out), 
      .out_data_Q(tx_cordic_tx2_q_out)
    );

    assign txsum = (tx_cordic_i_out + tx_cordic_tx2_i_out) >>> 3;
    assign txsumq = (tx_cordic_q_out + tx_cordic_tx2_q_out) >>> 3;

  end
endgenerate

// LFSR for dither
//reg [15:0] lfsr = 16'h0001;
//always @ (negedge clk_ad9866 or negedge extreset)
//    if (~extreset) lfsr <= 16'h0001;
//    else lfsr <= {lfsr[0],lfsr[15],lfsr[14] ^ lfsr[0], lfsr[13] ^ lfsr[0], lfsr[12], lfsr[11] ^ lfsr[0], lfsr[10:1]};

// apply amplitude & phase linearity correction

/*
Lookup tables
These are sent continuously in the unused audio out packets sent to the radio.
The left channel is an index into the table and the right channel has the value.
Indexes 0-4097 go into DACLUTI and 4096-8191 go to DACLUTQ.
The values are sent as signed 16bit numbers but the value is never bigger than 13 bits.

DACLUTI has the out of phase distortion and DACLUTQ has the in phase distortion.

The tables can represent arbitary functions, for now my console software just uses a power series

DACLUTI[x] = 0x + gain2*sin(phase2)*x^2 +  gain3*sin(phase3)*x^3 + gain4*sin(phase4)*x^4 + gain5*sin(phase5)*x^5
DACLUTQ[x] = 1x + gain2*cos(phase2)*x^2 +  gain3*cos(phase3)*x^3 + gain4*cos(phase4)*x^4 + gain5*cos(phase5)*x^5

The table indexes are signed so the tables are in 2's complement order ie. 0,1,2...2047,-2048,-2047...-1.

The table values are scaled to keep the output of DACLUTI[I]-DACLUTI[Q]+DACLUTQ[(I+Q)/root2] to fit in 12 bits,
the intermediate values and table values can be larger.
Zero input produces centre of the dac range output(signed 0) so with some settings one end or the other of the dac range is not used.

The predistortion is turned on and off by a new command and control packet this follows the last of the 32 receiver frequencies.
There is a sub index so this can be used for many other things.
control cc packet

c0 101011x
c1 sub index 0 for predistortion control-
c2 mode 0 off 1 on, (higher numbers can be used to experiment without so much fpga recompilation).

*/
generate
  if (PREDISTORT == 1) begin: PD1

  // lookup tables for dac phase and amplitude linearity correction
  logic signed [12:0] DACLUTI[4096];
  logic signed [12:0] DACLUTQ[4096];

  logic signed [15:0] distorted_dac;

  logic signed [15:0] iplusq;
  logic signed [15:0] iplusq_over_root2;

  logic signed [15:0] txsumr;
  logic signed [15:0] txsumqr;
  logic signed [15:0] iplusqr;

  //FSM to write DACLUTI and DACLUTQ
  assign lr_tready = 1'b1; // Always ready
  always @(posedge clk_ad9866) begin
    if (lr_tvalid) begin
      if (lr_tdata[12+16]) begin // Always write??
        DACLUTQ[lr_tdata[(11+16):16]] <= lr_tdata[12:0];
      end else begin
        DACLUTI[lr_tdata[(11+16):16]] <= lr_tdata[12:0];
      end
    end
  end

  assign iplusq = txsum+txsumq;

  always @ (posedge clk_ad9866) begin
    txsumr<=txsum;
    txsumqr<=txsumq;
    iplusqr<=iplusq;
  end

  //approximation to dividing by root 2 to reduce lut size, the error can be corrected in the lut data
  assign iplusq_over_root2 = iplusqr+(iplusqr>>>2)+(iplusqr>>>3)+(iplusqr>>>5);

  logic signed [15:0] txsumr2;
  logic signed [15:0] txsumqr2;
  logic signed [15:0] iplusq_over_root2r;

  always @ (posedge clk_ad9866) begin
    txsumr2<=txsumr;
    txsumqr2<=txsumqr;
    iplusq_over_root2r<=iplusq_over_root2;
  end
  
  assign distorted_dac = DACLUTI[txsumr2[11:0]]-DACLUTI[txsumqr2[11:0]]+DACLUTQ[iplusq_over_root2r[12:1]];

  always @ (posedge clk_ad9866) begin
    case( tx_predistort[1:0] )
      0: tx_data_dac <= txsum[11:0];
      1: tx_data_dac <= distorted_dac[11:0];
      //other modes
      default: tx_data_dac <= txsum[11:0];
    endcase
  end

end else begin

  assign lr_tready = 1'b0;

  always @ (posedge clk_ad9866)
    tx_data_dac <= txsum[11:0]; // + {10'h0,lfsr[2:1]};

end
endgenerate

endmodule
