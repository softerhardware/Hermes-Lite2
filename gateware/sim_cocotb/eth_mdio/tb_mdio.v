// Testbench wrapper around mdio.v: exposes the mdio inout as a plain
// wire with a second, testbench-controlled driver so cocotb can model
// the PHY side (drive turnaround and read data).
`timescale 1ns/1ps

module tb_mdio (
  input         clock,
  input  [ 4:0] addr,
  input         rd_request,
  input         wr_request,
  output        ready,
  input  [15:0] wr_data,
  output [15:0] rd_data,
  output        mdc_pin,

  // testbench PHY driver
  input         tb_en,
  input         tb_val,

  inout         mdio_pin
);

assign mdio_pin = tb_en ? tb_val : 1'bz;

mdio mdio_inst (
  .clock      (clock),
  .addr       (addr),
  .rd_request (rd_request),
  .wr_request (wr_request),
  .ready      (ready),
  .wr_data    (wr_data),
  .rd_data    (rd_data),
  .mdio_pin   (mdio_pin),
  .mdc_pin    (mdc_pin)
);

endmodule
