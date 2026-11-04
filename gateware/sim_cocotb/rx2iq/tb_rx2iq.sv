`timescale 1ps / 1ps
/* verilator lint_off WIDTH */
// cocotb/Verilator equivalent of the myhdl-generated test_rx2.v used by
// sim/test_rx2IQ.py: cordic -> flushed1 -> two cics (I and Q) ->
// flushed2 -> two varcics (I and Q).
// Parameters from the original localparams:
//   CORDIC_IN_WIDTH=12 CORDIC_EXTRA_BITS=5 CIC_STAGES=3
//   CIC_DECIMATION=8 CIC_OUT_WIDTH=14 VAR_STAGES=5 CICRATE=8
//   VAR_OUT_WIDTH=16 VAR_DECIMATION=12,
//   VAR_ACC_WIDTH=37, CIC_ACC_WIDTH=27 (rate 8 defaults).
module tb_rx2iq (
  input  wire                clock,
  input  wire  signed [31:0] frequency,
  input  wire  signed [11:0] in_data,
  input  wire                flushed1,
  input  wire                flushed2,
  output wire  signed [17:0] out_data_I,
  output wire  signed [17:0] out_data_Q,
  output wire                decimA_avail,
  output wire  signed [13:0] decimA_realI,
  output wire  signed [13:0] decimA_realQ,
  output wire                decimB_avail,
  output wire  signed [15:0] decimB_realI,
  output wire  signed [15:0] decimB_realQ
);

wire signed [17:0] in_data_I;
wire signed [17:0] in_data_Q;
wire signed [13:0] out_decimA_realI;
wire signed [13:0] out_decimA_realQ;

cordic #(.IN_WIDTH(12), .EXTRA_BITS(5)) cordic_i (
  .clock(clock),
  .frequency(frequency),
  .in_data(in_data),
  .out_data_I(out_data_I),
  .out_data_Q(out_data_Q)
);

assign in_data_I = flushed1 ? out_data_I : 0;

cic #(.STAGES(3), .DECIMATION(8), .IN_WIDTH(18),
      .ACC_WIDTH(27), .OUT_WIDTH(14)) cic_i (
  .clock(clock),
  .rst_all(1'b0),
  .in_strobe(1'b1),
  .out_strobe(decimA_avail),
  .in_data(in_data_I),
  .out_data(out_decimA_realI)
);

assign in_data_Q = flushed1 ? out_data_Q : 0;

// the original bench leaves cic_q's out_strobe unconnected
cic #(.STAGES(3), .DECIMATION(8), .IN_WIDTH(18),
      .ACC_WIDTH(27), .OUT_WIDTH(14)) cic_q (
  .clock(clock),
  .rst_all(1'b0),
  .in_strobe(1'b1),
  .out_strobe(),
  .in_data(in_data_Q),
  .out_data(out_decimA_realQ)
);

assign decimA_realI = flushed2 ? out_decimA_realI : 0;

varcic #(.STAGES(5), .IN_WIDTH(14), .ACC_WIDTH(37),
         .OUT_WIDTH(16), .CICRATE(8)) varcic_i (
  .clock(clock),
  .rst_all(1'b0),
  .decimation(6'd12),
  .in_strobe(decimA_avail),
  .out_strobe(decimB_avail),
  .in_data(decimA_realI),
  .out_data(decimB_realI)
);

assign decimA_realQ = flushed2 ? out_decimA_realQ : 0;

// the original bench leaves varcic_q's out_strobe unconnected too
varcic #(.STAGES(5), .IN_WIDTH(14), .ACC_WIDTH(37),
         .OUT_WIDTH(16), .CICRATE(8)) varcic_q (
  .clock(clock),
  .rst_all(1'b0),
  .decimation(6'd12),
  .in_strobe(decimA_avail),
  .out_strobe(),
  .in_data(decimA_realQ),
  .out_data(decimB_realQ)
);

endmodule
/* verilator lint_on WIDTH */
