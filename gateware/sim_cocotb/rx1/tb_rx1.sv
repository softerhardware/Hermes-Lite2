`timescale 1ps / 1ps
/* verilator lint_off WIDTH */
// cocotb/Verilator equivalent of the myhdl-generated test_rx1.v:
//   cordic -> (flushed gate) -> cic, cic in_strobe tied high.
// Parameters match the original testbench's localparams
// (cordic IN_WIDTH=12 EXTRA_BITS=5; cic STAGES=3 DECIMATION=8
//  IN_WIDTH=18 ACC_WIDTH=27 OUT_WIDTH=14).
module tb_rx1 (
  input  wire                clock,
  input  wire  signed [31:0] frequency,
  input  wire  signed [11:0] in_data,
  input  wire                flushed,
  output wire  signed [17:0] out_data_I,
  output wire  signed [17:0] out_data_Q,
  output wire                decimA_avail,
  output wire  signed [13:0] decimA_real
);

wire signed [17:0] in_data_I;

cordic #(.IN_WIDTH(12), .EXTRA_BITS(5)) cordic_i (
  .clock(clock),
  .frequency(frequency),
  .in_data(in_data),
  .out_data_I(out_data_I),
  .out_data_Q(out_data_Q)
);

assign in_data_I = flushed ? out_data_I : 0;

cic #(.STAGES(3), .DECIMATION(8), .IN_WIDTH(18),
      .ACC_WIDTH(27), .OUT_WIDTH(14)) cic_i (
  .clock(clock),
  .rst_all(1'b0),
  .in_strobe(1'b1),
  .out_strobe(decimA_avail),
  .in_data(in_data_I),
  .out_data(decimA_real)
);

endmodule
/* verilator lint_on WIDTH */
