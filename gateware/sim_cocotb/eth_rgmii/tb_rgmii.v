`timescale 1ns/1ps
module tb_rgmii (
  input             clk,
  // send side
  input      [ 7:0] s_data,
  input             s_tx_enable,
  output            s_active,
  output     [ 3:0] PHY_TX,
  output            PHY_TX_EN,
  // recv side
  input             r_reset,
  input             r_speed_1gb,
  output     [ 7:0] r_data,
  output            r_active,
  input      [ 3:0] PHY_RX,
  input             PHY_DV
);
rgmii_send u_send (
  .data(s_data), .tx_enable(s_tx_enable), .active(s_active),
  .clock(clk), .PHY_TX(PHY_TX), .PHY_TX_EN(PHY_TX_EN));
rgmii_recv u_recv (
  .reset(r_reset), .clock(clk), .speed_1gb(r_speed_1gb),
  .data(r_data), .active(r_active), .PHY_RX(PHY_RX), .PHY_DV(PHY_DV));
endmodule
