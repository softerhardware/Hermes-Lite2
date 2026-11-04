`timescale 1ps / 1ps
/* verilator lint_off WIDTH */
// Wrapper for cocotb/Verilator around cordic with the same explicit
// parameter overrides the original myhdl testbench used:
//   cordic #(.IN_WIDTH(12), .EXTRA_BITS(5))
// (the cordic.v default EXTRA_BITS is 6).
module tb_cordic (
  input  wire               clock,
  input  wire  signed [31:0] frequency,
  input  wire  signed [11:0] in_data,
  output wire  signed [17:0] out_data_I,
  output wire  signed [17:0] out_data_Q
);

cordic #(.IN_WIDTH(12), .EXTRA_BITS(5)) UUT (
  .clock(clock),
  .frequency(frequency),
  .in_data(in_data),
  .out_data_I(out_data_I),
  .out_data_Q(out_data_Q)
);

endmodule
/* verilator lint_on WIDTH */
