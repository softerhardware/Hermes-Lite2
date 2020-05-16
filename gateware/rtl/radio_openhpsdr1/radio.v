module radio (

  clk,
  clk_2x,

  run,
  qmsec_pulse,
  ext_keydown,

  tx_on,
  cw_on,

  // Transmit
  tx_tdata,
  tx_tlast,
  tx_tready,
  tx_tvalid,
  tx_tuser,

  tx_data_dac,

  clk_envelope,
  tx_envelope_pwm_out,
  tx_envelope_pwm_out_inv,

  // Optional audio stream for repurposed programming or EER
  lr_tdata,
  lr_tid,
  lr_tlast,
  lr_tready,
  lr_tvalid,

  // Receive
  rx_data_adc,

  rx_tdata,
  rx_tlast,
  rx_tready,
  rx_tvalid,
  rx_tuser,

  // Command slave interface
  cmd_addr,
  cmd_data,
  cmd_rqst,
  cmd_ack,

  debug_out
);

parameter         NR = 3;
parameter         NT = 1;
parameter         LRDATA = 0;
parameter         VNA = 1;
parameter         CLK_FREQ = 76800000;

parameter         RECEIVER2 = 0;
parameter         QS1R = 0;

parameter         DEBUGRX = 0;

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


input             clk;
input             clk_2x;

input             run;
input             qmsec_pulse;
input             ext_keydown;
output            tx_on;
output            cw_on;

input             clk_envelope;
output            tx_envelope_pwm_out;
output            tx_envelope_pwm_out_inv;

input   [31:0]    tx_tdata;
input             tx_tlast;
output            tx_tready;
input             tx_tvalid;
input   [ 3:0]    tx_tuser;

input   [31:0]    lr_tdata;
input   [ 2:0]    lr_tid;
input             lr_tlast;
output            lr_tready;
input             lr_tvalid;

output  [11:0]    tx_data_dac;

input   [11:0]    rx_data_adc;

output  [23:0]    rx_tdata;
output            rx_tlast;
input             rx_tready;
output            rx_tvalid;
output  [ 1:0]    rx_tuser;


// Command slave interface
input   [5:0]     cmd_addr;
input   [31:0]    cmd_data;
input             cmd_rqst;
output            cmd_ack;

output signed [15:0] debug_out;


logic [ 1:0]        tx_predistort = 2'b00;
logic [ 1:0]        tx_predistort_next;

logic               pure_signal = 1'b0;
logic               pure_signal_next;

logic               vna = 1'b0;
logic               vna_next;
logic  [15:0]       vna_count;
logic  [15:0]       vna_count_next;

logic  [ 1:0]       rx_rate = 2'b00;
logic  [ 1:0]       rx_rate_next;

logic  [ 4:0]       last_chan = 5'h0;
logic  [ 4:0]       last_chan_next;

logic  [ 4:0]       chan = 5'h0;
logic  [ 4:0]       chan_next;

logic               duplex = 1'b0;
logic               duplex_next;

logic               pa_mode = 1'b0;
logic               pa_mode_next;
logic  [ 9:0]       PWM_min = 10'd0; // minimum width of TX envelope PWM pulse
logic  [ 9:0]       PWM_min_next;
logic  [ 9:0]       PWM_max = 10'd1023; // maximum width of TX envelope PWM pulse
logic  [ 9:0]       PWM_max_next;

logic   [5:0]       rate;
logic   [11:0]      adcpipe [0:3];


logic [23:0]  rx_data_i [0:5];
logic [23:0]  rx_data_q [0:5];
logic         rx_data_rdy [0:5];

logic [63:0]  freqcomp;
logic [31:0]  freqcompp [0:3];
logic [5:0]   chanp [0:3];


logic [31:0]  rx_phase [0:5];    // The Rx phase calculated from the frequency sent by the PC.
logic [31:0]  tx_phase0;

logic signed [17:0]   mixdata_i [0:5];
logic signed [17:0]   mixdata_q [0:5];

logic [33:0] debug;

genvar c;

localparam
  CMD_IDLE    = 2'b00,
  CMD_FREQ1   = 2'b01,
  CMD_FREQ2   = 2'b11,
  CMD_FREQ3   = 2'b10;

logic [1:0]   cmd_state = CMD_IDLE;
logic [1:0]   cmd_state_next;

// Command Slave State Machine
always @(posedge clk) begin
  cmd_state <= cmd_state_next;
  vna <= vna_next;
  vna_count <= vna_count_next;
  rx_rate <= rx_rate_next;
  pure_signal <= pure_signal_next;
  tx_predistort <= tx_predistort_next;
  last_chan <= last_chan_next;
  duplex <= duplex_next;
  pa_mode <= pa_mode_next;
  PWM_min <= PWM_min_next;
  PWM_max <= PWM_max_next;
end

always @* begin
  cmd_state_next = cmd_state;
  cmd_ack = 1'b0;
  vna_next = vna;
  vna_count_next = vna_count;
  rx_rate_next = rx_rate;
  pure_signal_next = pure_signal;
  tx_predistort_next = tx_predistort;
  last_chan_next = last_chan;
  duplex_next = duplex;
  pa_mode_next = pa_mode;
  PWM_min_next = PWM_min;
  PWM_max_next = PWM_max;

  case(cmd_state)

    CMD_IDLE: begin
      if (cmd_rqst) begin
        case (cmd_addr)
          // Frequency changes
          6'h01:    cmd_state_next    = CMD_FREQ1;
          6'h02:    cmd_state_next    = CMD_FREQ1;
          6'h03:    cmd_state_next    = CMD_FREQ1;
          6'h04:    cmd_state_next    = CMD_FREQ1;
          6'h05:    cmd_state_next    = CMD_FREQ1;
          6'h06:    cmd_state_next    = CMD_FREQ1;
          6'h07:    cmd_state_next    = CMD_FREQ1;
          6'h08:    cmd_state_next    = CMD_FREQ1;
          6'h12:    cmd_state_next    = CMD_FREQ1;
          6'h13:    cmd_state_next    = CMD_FREQ1;
          6'h14:    cmd_state_next    = CMD_FREQ1;
          6'h15:    cmd_state_next    = CMD_FREQ1;
          6'h16:    cmd_state_next    = CMD_FREQ1;

          // Control with no acknowledge
          6'h00: begin
            rx_rate_next              = cmd_data[25:24];
            pa_mode_next              = cmd_data[16];
            last_chan_next            = cmd_data[7:3];
            duplex_next               = cmd_data[2];
          end

          6'h09: begin
            vna_next         = cmd_data[23];
            vna_count_next   = cmd_data[15:0];
          end
          6'h0a:    pure_signal_next  = cmd_data[22];

          6'h11: begin
            // TX envelope PWM min and max
            PWM_min_next = {cmd_data[31:24], cmd_data[17:16]};
            PWM_max_next = {cmd_data[15:8], cmd_data[1:0]};
          end

          6'h2b: begin
            //predistortion control sub index
            if(cmd_data[31:24]==8'h00) begin
              tx_predistort_next      = cmd_data[17:16];
            end
          end

          default:  cmd_state_next = cmd_state;
        endcase
      end
    end

    CMD_FREQ1: begin
      cmd_state_next = CMD_FREQ2;
    end

    CMD_FREQ2: begin
      cmd_state_next = CMD_FREQ3;
    end

    CMD_FREQ3: begin
      cmd_state_next = CMD_IDLE;
      cmd_ack = 1'b1;
    end
  endcase
end


// Frequency computation
// Always compute frequency
// This really should be done on the PC and not in the FPGA....
// This is not guarded by CDC handshake, but use of freqcomp
// is guarded by CDC handshake
assign freqcomp = cmd_data * M2 + M3;

// Pipeline freqcomp
always @ (posedge clk) begin
  // Pipeline to allow 2 cycles for multiply
  if (cmd_state == CMD_FREQ2) begin
    freqcompp[0] <= freqcomp[56:25];
    freqcompp[1] <= freqcomp[56:25];
    freqcompp[2] <= freqcomp[56:25];
    freqcompp[3] <= freqcomp[56:25];
    chanp[0] <= cmd_addr;
    chanp[1] <= cmd_addr;
    chanp[2] <= cmd_addr;
    chanp[3] <= cmd_addr;
  end
end

// TX0 and RX0
always @ (posedge clk) begin
  if (cmd_state == CMD_FREQ3) begin
    if (chanp[0] == 6'h01) begin
      tx_phase0 <= freqcompp[0];
      if (!duplex && (last_chan == 5'b00000)) rx_phase[0] <= freqcompp[0];
    end

    if (chanp[0] == 6'h02) begin
      if (!duplex && (last_chan == 5'b00000)) rx_phase[0] <= tx_phase0;
      else rx_phase[0] <= freqcompp[0];
    end
  end
end

// RX > 1
generate
  for (c = 1; c < NR; c = c + 1) begin: RXIFFREQ
    always @ (posedge clk) begin
      if (cmd_state == CMD_FREQ3) begin
        if (chanp[c/8] == ((c < 7) ? c+2 : c+11)) begin
          rx_phase[c] <= freqcompp[c/8];
        end
      end
    end
  end
endgenerate



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

logic [31:0]  tx0_phase;    // For VNAscan, starts at tx_phase0 and increments for vna_count points; else tx_phase0.
logic [ 1:0]  tx0_phase_zero; // True when tx0_phase should be reset to zero

//generate if (VNA == 1) begin: VNA1

// VNA scanning code added by Jim Ahlstrom, N2ADR, May 2018.
// The firmware can scan frequencies for the VNA if vna_count > 0. The vna then controls the Rx and Tx frequencies.
// The starting frequency is tx_phase0, the increment is rx_phase[0], and there are vna_count points.

logic [31:0]  rx0_phase;    // For VNAscan, equals tx0_phase; else rx_phase[0].
// This firmware supports two VNA modes: scanning by the PC (original method) and scanning in the FPGA.
// The VNA bit must be turned on for either.  So VNA is one for either method, and zero otherwise.
// The scan method depends on the number of VNA scan points, vna_count.  This is zero for the original method.
// wire VNA_SCAN_PC   = vna & (vna_count == 0);    // The PC changes the frequency for VNA.
wire VNA_SCAN_FPGA = vna & (vna_count != 0);    // The firmware changes the frequency.

wire signed [17:0] cordic_data_I, cordic_data_Q;
wire vna_strobe, rx0_strobe;
wire signed [23:0] vna_out_I, vna_out_Q, rx0_out_I, rx0_out_Q;

assign rx_data_rdy[0] = VNA_SCAN_FPGA ? vna_strobe : rx0_strobe;
assign rx_data_i[0] = VNA_SCAN_FPGA ? vna_out_I : rx0_out_I;
assign rx_data_q[0] = VNA_SCAN_FPGA ? vna_out_Q : rx0_out_Q;

// This module is a replacement for receiver zero when the FPGA scans in VNA mode.
vna_scanner #(.CICRATE(CICRATE), .RATE48(RATE48)) rx_vna (  // use this output for VNA_SCAN_FPGA
    //control
    .clk(clk),
    .freq_delta(rx_phase[0]),
    .output_strobe(vna_strobe),
    //input
    .cordic_data_I(cordic_data_I),
    .cordic_data_Q(cordic_data_Q),
    //output
    .out_data_I(vna_out_I),
    .out_data_Q(vna_out_Q),
    // VNA mode data
    .vna(vna),
    .tx_freq_in(tx_phase0),
    .tx_freq(tx0_phase),
    .tx_zero(tx0_phase_zero),
    .rx0_phase(rx0_phase),
    .vna_count(vna_count)
    );


  // One receiver minimum
  mix2 #(.CALCTYPE(3)) mix2_0 (
    .clk(clk),
    .clk_2x(clk_2x),
    .rst(&tx0_phase_zero),
    .phi0(rx0_phase),
    .phi1(rx_phase[2]),
    .adc(adcpipe[0]),
    .mixdata0_i(mixdata_i[0]),
    .mixdata0_q(mixdata_q[0]),
    .mixdata1_i(mixdata_i[2]),
    .mixdata1_q(mixdata_q[2])
  );
  assign cordic_data_I = mixdata_i[0];
  assign cordic_data_Q = mixdata_q[0];

  receiver_nco #(.CICRATE(CICRATE)) receiver_0 (
    .clock(clk),
    .clock_2x(clk_2x),
    .rate(rate),
    .mixdata_I(mixdata_i[0]),
    .mixdata_Q(mixdata_q[0]),
    .out_strobe(rx0_strobe),
    .out_data_I(rx0_out_I),
    .out_data_Q(rx0_out_Q),
    .debug(debug)
  );


generate

if (NR >= 2) begin: MIX1_3
  // Always build second mixer for second receiver for PureSignal support
  mix2 #(.CALCTYPE(3)) mix2_2 (
    .clk(clk),
    .clk_2x(clk_2x),
    .rst(1'b0),
    .phi0(rx_phase[1]),
    .phi1(rx_phase[3]),
    .adc((tx_on & pure_signal) ? tx_data_dac : adcpipe[1]),
    .mixdata0_i(mixdata_i[1]),
    .mixdata0_q(mixdata_q[1]),
    .mixdata1_i(mixdata_i[3]),
    .mixdata1_q(mixdata_q[3])
  );
end

if (NR >= 2) begin: RECEIVER1
  receiver_nco #(.CICRATE(CICRATE)) receiver_1 (
    .clock(clk),
    .clock_2x(clk_2x),
    .rate(rate),
    .mixdata_I(mixdata_i[1]),
    .mixdata_Q(mixdata_q[1]),
    .out_strobe(rx_data_rdy[1]),
    .out_data_I(rx_data_i[1]),
    .out_data_Q(rx_data_q[1])
  );
end

if (NR >= 3) begin: RECEIVER2
  receiver_nco #(.CICRATE(CICRATE)) receiver_2 (
    .clock(clk),
    .clock_2x(clk_2x),
    .rate(rate),
    .mixdata_I(mixdata_i[2]),
    .mixdata_Q(mixdata_q[2]),
    .out_strobe(rx_data_rdy[2]),
    .out_data_I(rx_data_i[2]),
    .out_data_Q(rx_data_q[2])
  );
end

if (NR >= 4) begin: RECEIVER3
  receiver_nco #(.CICRATE(CICRATE)) receiver_3 (
    .clock(clk),
    .clock_2x(clk_2x),
    .rate(rate),
    .mixdata_I(mixdata_i[3]),
    .mixdata_Q(mixdata_q[3]),
    .out_strobe(rx_data_rdy[3]),
    .out_data_I(rx_data_i[3]),
    .out_data_Q(rx_data_q[3])
  );
end

if (NR >= 5) begin: MIX4_5
  // Build double mixer
  mix2 #(.CALCTYPE(3)) mix2_4 (
    .clk(clk),
    .clk_2x(clk_2x),
    .rst(1'b0),
    .phi0(rx_phase[4]),
    .phi1(rx_phase[5]),
    .adc(adcpipe[2]),
    .mixdata0_i(mixdata_i[4]),
    .mixdata0_q(mixdata_q[4]),
    .mixdata1_i(mixdata_i[5]),
    .mixdata1_q(mixdata_q[5])
  );
end

if (NR >= 5) begin: RECEIVER4
  receiver_nco #(.CICRATE(CICRATE)) receiver_4 (
    .clock(clk),
    .clock_2x(clk_2x),
    .rate(rate),
    .mixdata_I(mixdata_i[4]),
    .mixdata_Q(mixdata_q[4]),
    .out_strobe(rx_data_rdy[4]),
    .out_data_I(rx_data_i[4]),
    .out_data_Q(rx_data_q[4])
  );
end

if (NR >= 6) begin: RECEIVER5
  receiver_nco #(.CICRATE(CICRATE)) receiver_5 (
    .clock(clk),
    .clock_2x(clk_2x),
    .rate(rate),
    .mixdata_I(mixdata_i[5]),
    .mixdata_Q(mixdata_q[5]),
    .out_strobe(rx_data_rdy[5]),
    .out_data_I(rx_data_i[5]),
    .out_data_Q(rx_data_q[5])
  );
end

endgenerate



// Send RX data upstream
localparam
  RXUS_WAIT1  = 2'b00,
  RXUS_I      = 2'b10,
  RXUS_Q      = 2'b11,
  RXUS_WAIT0  = 2'b01;

logic [1:0]   rxus_state = RXUS_WAIT1;
logic [1:0]   rxus_state_next;

always @(posedge clk) begin
  rxus_state <= rxus_state_next;
  chan <= chan_next;
end

always @* begin
  // Sequential
  rxus_state_next = rxus_state;
  chan_next = chan;

  // Combinational
  rx_tdata  = 24'h0;
  rx_tlast  = 1'b0;
  rx_tvalid = 1'b0;
  rx_tuser  = 2'b00;

  case(rxus_state)
    RXUS_WAIT1: begin
      chan_next = 5'h0;
      if (rx_data_rdy[0] & rx_tready) begin
        rxus_state_next = RXUS_I;
      end
    end

    RXUS_I: begin
      rx_tvalid = 1'b1;
      rx_tdata = rx_data_i[chan];
      rx_tuser = 2'b00; // Bit 0 will appear as left mic LSB in VNA mode, add VNA here
      rxus_state_next = RXUS_Q;
    end

    RXUS_Q: begin
      rx_tvalid = 1'b1;
      rx_tdata = rx_data_q[chan];

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

generate if (NT == 0) begin
  // No transmit
  assign tx_tready = 1'b0;
  assign tx_data_dac = 12'h000;

end else begin

// At least one transmit
logic signed [15:0] tx_fir_i, tx_fir_i_next;
logic signed [15:0] tx_fir_q, tx_fir_q_next;

logic         req2;
logic [19:0]  y1_r, y1_i;
logic [15:0]  y2_r, y2_i;

logic signed [15:0] tx_cordic_i_out;
logic signed [15:0] tx_cordic_q_out;

logic signed [15:0] tx_i;
logic signed [15:0] tx_q;

logic signed [15:0] txsum;
logic signed [15:0] txsumq;

logic [ 6:0]  tx_qmsectimer_next, tx_qmsectimer = 7'h00;
logic [18:0]  tx_cwlevel_next, tx_cwlevel = 19'h0;

logic cwx;
logic ptt;
logic fir_tready;

localparam
  NOTX      = 3'b000,
  PTTTX     = 3'b011,
  PRETX     = 3'b001,
  CWTX      = 3'b101,
  CWHANG    = 3'b100;
//  CWXTX     = 3'b010,
//  CWXHANG   = 3'b011;

logic [ 2:0] tx_state           = NOTX ;
logic [ 2:0] tx_state_next             ;
logic        tx_cw_key                 ;
logic [ 9:0] cw_hang_time              ;
logic [10:0] accumdelay                ;
logic        accumdelay_incr           ;
logic        accumdelay_decr           ;
logic        accumdelay_notzero        ;
logic [ 4:0] tx_buffer_latency  = 5'h0a; // Default to 10ms
logic [ 4:0] ptt_hang_time      = 5'h04; // Default to 4 ms

localparam MAX_CWLEVEL = 19'h4d800; //(16'h4d80 << 4);
localparam MIN_CWLEVEL = 19'h0;

always @(posedge clk) begin
  if (accumdelay_incr) accumdelay <= accumdelay + 1;
  else if (accumdelay_decr & accumdelay_notzero) accumdelay <= accumdelay -1;
end
assign accumdelay_notzero = |accumdelay;


always @(posedge clk) begin
  if (cmd_rqst) begin
    if (cmd_addr == 6'h10) begin
      cw_hang_time <= {cmd_data[31:24], cmd_data[17:16]};
    end else if (cmd_addr == 6'h17) begin
      tx_buffer_latency <= cmd_data[4:0];
      ptt_hang_time <= cmd_data[12:8];
    end
  end
end


// TX run state machine
always @(posedge clk) begin
  tx_state      <= run ? tx_state_next : NOTX;
  tx_qmsectimer <= tx_qmsectimer_next;
  tx_cwlevel    <= tx_cwlevel_next;
  tx_fir_i      <= tx_fir_i_next;
  tx_fir_q      <= tx_fir_q_next;
end

always @* begin
  cwx = tx_tuser[2] & tx_tvalid;
  ptt = tx_tuser[3] & tx_tvalid;


  tx_state_next      = tx_state;
  tx_qmsectimer_next = tx_qmsectimer;
  tx_cwlevel_next    = tx_cwlevel;
  tx_fir_i_next      = tx_fir_i;
  tx_fir_q_next      = tx_fir_q;

  tx_on = 1'b1;
  cw_on = 1'b0;
  tx_cw_key = 1'b0;
  tx_tready = fir_tready; // Empty FIFO

  accumdelay_incr = 1'b0;
  accumdelay_decr = 1'b0;

  case (tx_state)

    NOTX: begin
      tx_fir_i_next = 16'h00;
      tx_fir_q_next = 16'h00;
      tx_cwlevel_next = 19'h00;
      tx_qmsectimer_next = {tx_buffer_latency, 2'b00};
      tx_on = 1'b0;

      // Free accumulated samples to maintain time coherency in tape recorder mode
      accumdelay_decr = ~fir_tready;
      tx_tready = accumdelay_notzero | fir_tready;

      if (ext_keydown | cwx | ptt) tx_state_next = PRETX;
    end

    PRETX: begin
      tx_tready = 1'b0; //Stall data to fill FIFO unless in CWX mode
      accumdelay_incr = fir_tready; // Count samples accumulated
      if (tx_qmsectimer != 7'h00) begin
        if (qmsec_pulse) tx_qmsectimer_next = tx_qmsectimer - 7'h01;
        if (~(ext_keydown | cwx | ptt)) tx_state_next = NOTX;
      end else begin
        if (cwx | ext_keydown) tx_state_next = CWTX;
        else tx_state_next = PTTTX;
      end
    end

    PTTTX: begin
      if (ptt) begin
        tx_qmsectimer_next = {ptt_hang_time, 2'b00};
        if (fir_tready) begin
          tx_fir_i_next = tx_tdata[31:16];
          tx_fir_q_next = tx_tdata[15:0];
        end
      end else begin
        if (tx_qmsectimer != 7'h00) begin
          if (qmsec_pulse) tx_qmsectimer_next = tx_qmsectimer - 7'h01;
        end else begin
          tx_state_next = NOTX;
        end
      end
    end



    CWTX: begin
      cw_on = 1'b1;
      tx_cw_key = 1'b1;
      if (ext_keydown | cwx) begin
        // Shape CW on
        if (tx_cwlevel != MAX_CWLEVEL) tx_cwlevel_next = tx_cwlevel + 19'h01;
        tx_qmsectimer_next = {tx_buffer_latency, 2'b00};
      end else begin
        // Extend CW on to match tx_buffer_latency if ext key
        if (tx_qmsectimer != 7'h00) begin
          if (qmsec_pulse) tx_qmsectimer_next = tx_qmsectimer - 7'h01;
        end else if (tx_cwlevel != 19'h00) tx_cwlevel_next = tx_cwlevel - 19'h01;
        else begin
          tx_qmsectimer_next = {tx_buffer_latency, 2'b00};
          tx_cwlevel_next = {7'b0000000, cw_hang_time, 2'b00};
          tx_state_next = CWHANG;
        end
      end
    end

    CWHANG: begin
      cw_on = 1'b1;
      if (ext_keydown | cwx) begin
        // delay ext CW by tx_buffer_latency
        if (tx_qmsectimer != 7'h00) begin
          if (qmsec_pulse) tx_qmsectimer_next = tx_qmsectimer - 7'h01;
        end else begin
          tx_qmsectimer_next = {tx_buffer_latency, 2'b00};
          tx_cwlevel_next = 19'h0;
          tx_state_next = CWTX;
        end
      end else begin
        if (tx_cwlevel != 19'h0) begin
          if (qmsec_pulse) tx_cwlevel_next = tx_cwlevel - 19'h01;
        end else begin
          tx_state_next = NOTX;
        end
      end
    end



//CWXTX: begin
//  cw_on = 1'b1;
//  tx_cw_key = 1'b1;
//  if (cwx) begin
//    // Shape CW on
//    if (tx_cwlevel != MAX_CWLEVEL) tx_cwlevel_next = tx_cwlevel + 19'h01;
//  end else begin
//    if (tx_cwlevel != 19'h00) tx_cwlevel_next = tx_cwlevel - 19'h01;
//    else begin
//      tx_cwlevel_next = {7'b0000000, cw_hang_time, 2'b00};
//      tx_state_next = CWXHANG;
//    end
//  end
//end

//CWXHANG: begin
//  cw_on = 1'b1;
//  if (cwx) begin
//    tx_state_next = CWXTX;
//  end else begin
//    if (tx_cwlevel != 19'h0) begin
//      if (qmsec_pulse) tx_cwlevel_next = tx_cwlevel - 19'h01;
//    end else begin
//      tx_state_next = NOTX;
//    end
//  end
//end

  endcase
end

// Interpolate I/Q samples from 48 kHz to the clock frequency
FirInterp8_1024 fi (clk, req2, fir_tready, tx_fir_i, tx_fir_q, y1_r, y1_i);  // req2 enables an output sample, tx_tready requests next input sample.

// GBITS reduced to 30
CicInterpM5 #(.RRRR(RRRR), .IBITS(20), .OBITS(16), .GBITS(GBITS)) in2 ( clk, 1'd1, req2, y1_r, y1_i, y2_r, y2_i);

//---------------------------------------------------------
//    CORDIC NCO
//---------------------------------------------------------

// Code rotates input at set frequency and produces I & Q
assign tx_i = vna ? 16'h4d80 : (tx_cw_key ? {1'b0, tx_cwlevel[18:4]} : y2_i);    // select vna mode if active. Set CORDIC for max DAC output
assign tx_q = (vna | tx_cw_key) ? 16'h0 : y2_r;                   // taking into account CORDICs gain i.e. 0x7FFF/1.7


// NOTE:  I and Q inputs reversed to give correct sideband out
cpl_cordic #(.OUT_WIDTH(16)) cordic_inst (
  .clock(clk),
  .frequency(tx0_phase),
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


//gain of 4
assign txsum = (tx_cordic_i_out  >>> 2); // + {15'h0000, tx_cordic_i_out[1]};
assign txsumq = (tx_cordic_q_out  >>> 2);


// LFSR for dither
//reg [15:0] lfsr = 16'h0001;
//always @ (negedge clk or negedge extreset)
//    if (~extreset) lfsr <= 16'h0001;
//    else lfsr <= {lfsr[0],lfsr[15],lfsr[14] ^ lfsr[0], lfsr[13] ^ lfsr[0], lfsr[12], lfsr[11] ^ lfsr[0], lfsr[10:1]};


case (LRDATA)
  0: begin // Left/Right downstream (PC->Card) audio data not used
    assign lr_tready = 1'b0;
    assign tx_envelope_pwm_out = 1'b0;
    assign tx_envelope_pwm_out_inv = 1'b0;

   always @ (posedge clk)
      tx_data_dac <= txsum[11:0]; // + {10'h0,lfsr[2:1]};
  end
  1: begin: PD1 // TX predistortion
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

    // lookup tables for dac phase and amplitude linearity correction
    logic signed [12:0] DACLUTI[4096];
    logic signed [12:0] DACLUTQ[4096];

    logic signed [15:0] distorted_dac;

    logic signed [15:0] iplusq;
    logic signed [15:0] iplusq_over_root2;

    logic signed [15:0] txsumr;
    logic signed [15:0] txsumqr;
    logic signed [15:0] iplusqr;

    assign tx_envelope_pwm_out = 1'b0;
    assign tx_envelope_pwm_out_inv = 1'b0;
    //FSM to write DACLUTI and DACLUTQ
    assign lr_tready = 1'b1; // Always ready
    always @(posedge clk) begin
      if (lr_tvalid) begin
        if (lr_tdata[12+16]) begin // Always write??
          DACLUTQ[lr_tdata[(11+16):16]] <= lr_tdata[12:0];
        end else begin
          DACLUTI[lr_tdata[(11+16):16]] <= lr_tdata[12:0];
        end
      end
    end

    assign iplusq = txsum+txsumq;

    always @ (posedge clk) begin
      txsumr<=txsum;
      txsumqr<=txsumq;
      iplusqr<=iplusq;
    end

    //approximation to dividing by root 2 to reduce lut size, the error can be corrected in the lut data
    assign iplusq_over_root2 = iplusqr+(iplusqr>>>2)+(iplusqr>>>3)+(iplusqr>>>5);

    logic signed [15:0] txsumr2;
    logic signed [15:0] txsumqr2;
    logic signed [15:0] iplusq_over_root2r;

    always @ (posedge clk) begin
      txsumr2<=txsumr;
      txsumqr2<=txsumqr;
      iplusq_over_root2r<=iplusq_over_root2;
    end

    assign distorted_dac = DACLUTI[txsumr2[11:0]]-DACLUTI[txsumqr2[11:0]]+DACLUTQ[iplusq_over_root2r[12:1]];

    always @ (posedge clk) begin
      case( tx_predistort[1:0] )
        0: tx_data_dac <= txsum[11:0];
        1: tx_data_dac <= distorted_dac[11:0];
        //other modes
        default: tx_data_dac <= txsum[11:0];
      endcase
    end
  end

  2: begin: EER1 // TX envelope PWM generation for ET/EER
    //   cannot be used with TX predistortion as it uses the same audio lrdata
    always @ (posedge clk)
      tx_data_dac <= txsum[11:0]; // + {10'h0,lfsr[2:1]};

    reg signed [15:0]tx_EER_fir_i;
    reg signed [15:0]tx_EER_fir_q;

    // latch I&Q data on strobe from FIR
    // FIXME: no backpressure from FIR for now
    always @ (posedge clk) begin
      if (lr_tready & lr_tvalid) begin
        tx_EER_fir_i = lr_tdata[31:16];
        tx_EER_fir_q = lr_tdata[15:0];
      end
    end

    // Interpolate by 5 FIR for Envelope generation - straight FIR, no CIC compensation.
    wire [19:0] I_EER, Q_EER;
    wire EER_req;

    // Note: Coefficients are scaled by 0.85 so that unity I&Q input give unity amplitude envelope signal.
    FirInterp5_1025_EER fiEER (clk, EER_req, lr_tready, tx_EER_fir_i, tx_EER_fir_q, I_EER, Q_EER);   // EER_req enables an output sample, lr_tready requests next input sample.

    assign EER_req = (ramp == 10'd0 | ramp == 10'd1 | ramp == 10'd2 | ramp == 10'd3); // need an enable wide enough to be sampled by clk to enable EER FIR data out

    // calculate the envelope of the SSB signal using SQRT(I^2 + Q^2)
    wire [31:0] Isquare;
    wire [31:0] Qsquare;
    wire [32:0] sum;                // 32 bits + 32 bits requires 33 bit accumulator.
    wire [15:0] envelope;

    // use I&Q x 5 from EER iFIR output
    //square square_I (.clock(clk), .dataa(I_EER[19:4]), .result(Isquare));
    //square square_Q (.clock(clk), .dataa(Q_EER[19:4]), .result(Qsquare));
    square square_I (.dataa(I_EER[19:4]), .result(Isquare));
    square square_Q (.dataa(Q_EER[19:4]), .result(Qsquare));
    assign sum = Isquare + Qsquare;
    sqroot sqroot_inst (.clk(clk), .radical(sum[32:1]), .q(envelope));

    //--------------------------------------------------------
    // Generate 240 kHz PWM signal from Envelope
    //--------------------------------------------------------
    // Since the envelope will always have positive values we can ignore the sign bit.
    // Also use the top 10 bits since this is what the ramp uses.
    // clock clk_envelope runs at 245.76 MHz (1024 x 240 kHz).
    reg  [9:0] ramp = 0;
    reg PWM = 0;

    counter counter_inst (.clock(clk_envelope), .q(ramp));  // count to 1024 [10:0] = 240kHz, 640 [9:0] for 384kHz

    wire [14:0] envelope_scaled = envelope + (envelope >>> 2) + (envelope >>> 3);  // Multiply by 1.375, keep all bits for proper rounding
    wire [9:0] envelope_level = envelope_scaled[14:5];

    always @ (posedge clk_envelope)
    begin
      if ((ramp < PWM_min | envelope_level > ramp) && ramp < PWM_max)
        PWM <= 1'b1;
      else
        PWM <= 1'b0;
    end

    // FIXME: disable EER when VNA is enabled? is CW handled correctly?
    assign tx_envelope_pwm_out = (tx_on & pa_mode) ? PWM : 1'b0;  // PWM only when TX and EER mode are selected
    assign tx_envelope_pwm_out_inv = ~tx_envelope_pwm_out;

  end
endcase

end

endgenerate


generate if (DEBUGRX == 1) begin: DEBUGRX

logic [3:0] synthetic_count;
logic signed [11:0] synthetic_adc;
logic signed [15:0] debugreg0;
logic signed [15:0] debugreg1;
logic signed [15:0] debugreg2;
logic signed [15:0] debugreg3;
logic [1:0] debugsel;

always @ (posedge clk) begin
  if (cmd_rqst & cmd_addr == 6'h39) begin
    debugreg0 <= 0;
    debugreg1 <= 0;
    debugreg2 <= 0;
    debugreg3 <= 0;
    debugsel  <= cmd_data[1:0];
  end else begin
    if ($signed(mixdata_i[0][17:2]) > debugreg0) debugreg0 <= $signed(mixdata_i[0][17:2]);
    if (rx0_strobe & ($signed(rx0_out_I[23:8]) > debugreg1)) debugreg1 <= $signed(rx0_out_I[23:8]);
    if (debug[16] & ($signed(debug[15:0]) > debugreg2)) debugreg2 <= $signed(debug[15:0]);
    if (debug[33] & ($signed(debug[32:17]) > debugreg3)) debugreg3 <= $signed(debug[32:17]);
  end
end

always @* begin
  case (debugsel)
    2'h0: debug_out = debugreg0;
    2'h1: debug_out = debugreg1;
    2'h2: debug_out = debugreg2;
    2'h3: debug_out = debugreg3;
  endcase
end


// Synthetic 76.8/13 = 5.907 MHz Signal
always @ (posedge clk) begin
  if (synthetic_count == 4'hc) synthetic_count <= 4'h0;
  else synthetic_count <= synthetic_count + 1;
end

// i from 0 to 12
//int(round((2**11-1)*np.sin(2*np.pi*i/13+(np.pi/2)+.01)))
always @* begin
  case (synthetic_count)
    4'h0: synthetic_adc = 2047;
    4'h1: synthetic_adc = 1803;
    4'h2: synthetic_adc = 1146;
    4'h3: synthetic_adc = 226;
    4'h4: synthetic_adc = -745;
    4'h5: synthetic_adc = -1546;
    4'h6: synthetic_adc = -1992;
    4'h7: synthetic_adc = -1983;
    4'h8: synthetic_adc = -1519;
    4'h9: synthetic_adc = -707;
    4'ha: synthetic_adc = 267;
    4'hb: synthetic_adc = 1180;
    4'hc: synthetic_adc = 1822;
    default: synthetic_adc = 2047;
  endcase
end


// Pipeline for adc fanout
always @ (posedge clk) begin
  adcpipe[0] <= synthetic_adc;
  adcpipe[1] <= rx_data_adc;
  adcpipe[2] <= rx_data_adc;
  adcpipe[3] <= rx_data_adc;
end

end else begin

  // Pipeline for adc fanout
always @ (posedge clk) begin
  adcpipe[0] <= rx_data_adc;
  adcpipe[1] <= rx_data_adc;
  adcpipe[2] <= rx_data_adc;
  adcpipe[3] <= rx_data_adc;
end

assign debug_out = 16'd0;

end
endgenerate



endmodule
