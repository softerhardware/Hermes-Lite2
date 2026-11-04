`timescale 1ps / 1ps
/* verilator lint_off WIDTH */
// Wrapper for cocotb/Verilator around mix1.
//
// mix1.v references an undeclared implicit net `clk_2x` for its multiplier
// clocks (an artifact of the efinix restructure; iverilog's -g2012 let this
// float, leaving the multipliers clocked by clk). Verilator requires the net
// to exist, so this wrapper creates it and ties it to clk, matching the
// behaviour of the original myhdl/iverilog testbench. mix1 is instantiated
// with default parameters (CALCTYPE=3), as the original test did.
module tb_mix1 (
  input  wire               clk,
  input  wire               rst,
  input  wire       [31:0]  phi,
  input  wire  signed [11:0] adc,
  output wire  signed [17:0] i_data,
  output wire  signed [17:0] q_data
);

mix1 UUT (
  .clk(clk),
  .rst(rst),
  .phi(phi),
  .adc(adc),
  .i_data(i_data),
  .q_data(q_data)
);

assign UUT.clk_2x = clk;

endmodule
/* verilator lint_on WIDTH */
