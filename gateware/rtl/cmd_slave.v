//
//  Hermes Lite - command bus helper
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation; either version 2 of the License, or
//  (at your option) any later version.
//
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
// cmd_slave - canonical single-address capture on the broadcast command bus.
//
// Captures the command word and raises 'hit' one clock cycle after cmd_rqst
// when ADDR matches.  Consumers slice fields out of 'data' locally:
//
//   cmd_slave #(.ADDR(CMDA_KEYERAUX)) u_cmd (.clk, .cmd_addr, .cmd_data,
//                                            .cmd_rqst, .hit, .data);
//   always @(posedge clk) if (hit) enable <= data[24];
//
// See cmd_bus.vh for the bus protocol contract and address map.  Slaves with
// multi-cycle execution sequences (frequency pipeline in radio.v, SPI
// sequencer in ad9866ctrl.v, I2C transaction engine in i2c_bus2.v) keep
// their own FSMs and only reuse the address map symbols.
module cmd_slave #(
  parameter ADDR = 6'h00,
  parameter AW   = 6
)(
  input                 clk,
  input  [AW-1:0]       cmd_addr,
  input  [31:0]         cmd_data,
  input                 cmd_rqst,
  output reg            hit,       // one-cycle strobe, delayed one clk from rqst
  output reg [31:0]     data       // captured command word
);

  always @(posedge clk) begin
    hit  <= cmd_rqst & (cmd_addr == ADDR);
    data <= cmd_data;
  end

endmodule
