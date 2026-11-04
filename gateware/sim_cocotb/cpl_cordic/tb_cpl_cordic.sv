`timescale 1ps / 1ps
/* verilator lint_off WIDTH */
// Wrapper for cocotb/Verilator around cpl_cordic with the same explicit
// parameter override the original myhdl testbench used:
//   cpl_cordic #(.OUT_WIDTH(16))
// (the cpl_cordic.v default OUT_WIDTH is the raw WR = 23-bit datapath).
// IN_WIDTH=16 and EXTRA_BITS=5 are the RTL defaults, passed explicitly.
module tb_cpl_cordic (
  input  wire                clock,
  input  wire  signed [31:0] frequency,
  input  wire  signed [15:0] in_data_I,
  input  wire  signed [15:0] in_data_Q,
  output wire  signed [15:0] out_data_I,
  output wire  signed [15:0] out_data_Q
);

cpl_cordic #(.IN_WIDTH(16), .EXTRA_BITS(5), .OUT_WIDTH(16)) UUT (
  .clock(clock),
  .frequency(frequency),
  .in_data_I(in_data_I),
  .in_data_Q(in_data_Q),
  .out_data_I(out_data_I),
  .out_data_Q(out_data_Q)
);

endmodule
/* verilator lint_on WIDTH */
