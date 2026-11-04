`timescale 1ps / 1ps
/* verilator lint_off WIDTH */
// cocotb/Verilator equivalent of the myhdl-generated test_rx2.v:
//   cordic -> flushed1 -> cic -> flushed2 -> varcic.
// Parameters from the original testbench localparams:
//   CORDIC_IN_WIDTH=12 CORDIC_EXTRA_BITS=5 CIC_STAGES=3
//   CIC_DECIMATION=8 CIC_OUT_WIDTH=14 VAR_STAGES=5 CICRATE=8
//   VAR_OUT_WIDTH=16, VAR_ACC_WIDTH=39, CIC_ACC_WIDTH=27 (rate 8).
module tb_rx2 (
  input  wire                clock,
  input  wire  signed [31:0] frequency,
  input  wire  signed [11:0] in_data,
  input  wire                flushed1,
  input  wire                flushed2,
  input  wire        [5:0]   var_decimation,
  output wire  signed [17:0] out_data_I,
  output wire  signed [17:0] out_data_Q,
  output wire                decimA_avail,
  output wire  signed [13:0] decimA_real,
  output wire                decimB_avail,
  output wire  signed [15:0] decimB_real
);

wire signed [17:0] in_data_I;
wire signed [13:0] out_decimA_real;

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
  .out_data(out_decimA_real)
);

assign decimA_real = flushed2 ? out_decimA_real : 0;

varcic #(.STAGES(5), .IN_WIDTH(14), .ACC_WIDTH(39),
         .OUT_WIDTH(16), .CICRATE(8)) varcic_i (
  .clock(clock),
  .rst_all(1'b0),
  .decimation(var_decimation),
  .in_strobe(decimA_avail),
  .out_strobe(decimB_avail),
  .in_data(decimA_real),
  .out_data(decimB_real)
);

endmodule
/* verilator lint_on WIDTH */
