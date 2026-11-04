// Testbench wrapper around network.v, the full Metis-style ethernet stack.
//
// Clocks are generated here (not in cocotb) because the dhcp/phy state
// machine runs on clock_2_5MHz and needs millions of its edges before the
// stack leaves ST_PHY_SETTLE; a Verilog oscillator runs that stretch at
// native Verilator speed.  The 2.5MHz "seconds" timers count cycles, not
// real time, so it may run far faster than 2.5MHz without changing any
// behaviour relevant to these tests.
//
// The PHY_MDIO inout gets a minimal clause-22 PHY model (tb_phy_mdio
// below): Verilator resolves an undriven inout to 0, phy_cfg would see no
// PHY and the whole stack would stay in reset.  Every read returns
// 16'h0090, which through mdio.v's one-bit-late capture (rd_data =
// 0x8000 | data>>1) reads back 0x8048: speed 2'b10 (1 Gbps), full
// duplex, so phy_connected goes high.
`timescale 1ns/1ps

module tb_network (
  output       clock_2_5MHz,
  output       tx_clock,
  input  [1:0] udp_tx_request,
  input  [15:0] udp_tx_length,
  input  [7:0] udp_tx_data,
  output       udp_tx_enable,
  input        run,
  input  [7:0] port_id,
  output       rx_clock,
  output [15:0] to_port,
  output [7:0] udp_rx_data,
  output       udp_rx_active,
  output       broadcast,
  output       dst_unreachable,
  input  [7:0] eeprom_config,
  input  [31:0] static_ip,
  input  [47:0] local_mac,
  output       speed_1gb,
  output       network_state_dhcp,
  output       network_state_fixedip,
  output [1:0] network_speed,
  output       phy_connected,
  output       is_ksz9021,
  output [3:0] PHY_TX,
  output       PHY_TX_EN,
  input  [3:0] PHY_RX,
  input        PHY_DV,
  inout        PHY_MDIO,
  output       PHY_MDC
);

//-----------------------------------------------------------------------------
// clocks: 125MHz tx/rx, "2.5MHz" control clock (fast in simulation, see note)
reg clk25 = 1'b0, ctx = 1'b0, crx = 1'b0;
always #2.0 clk25 = ~clk25;   // 4 ns period control clock
always #4.0 ctx = ~ctx;       // 8 ns period tx clock
always #4.0 crx = ~crx;       // 8 ns period rx clock
assign clock_2_5MHz = clk25;
assign tx_clock = ctx;
assign rx_clock = crx;

network dut (
  .clock_2_5MHz(clock_2_5MHz),
  .tx_clock(tx_clock),
  .udp_tx_request(udp_tx_request),
  .udp_tx_length(udp_tx_length),
  .udp_tx_data(udp_tx_data),
  .udp_tx_enable(udp_tx_enable),
  .run(run),
  .port_id(port_id),
  .rx_clock(rx_clock),
  .to_port(to_port),
  .udp_rx_data(udp_rx_data),
  .udp_rx_active(udp_rx_active),
  .broadcast(broadcast),
  .dst_unreachable(dst_unreachable),
  .eeprom_config(eeprom_config),
  .static_ip(static_ip),
  .local_mac(local_mac),
  .speed_1gb(speed_1gb),
  .network_state_dhcp(network_state_dhcp),
  .network_state_fixedip(network_state_fixedip),
  .network_speed(network_speed),
  .phy_connected(phy_connected),
  .is_ksz9021(is_ksz9021),
  .PHY_TX(PHY_TX),
  .PHY_TX_EN(PHY_TX_EN),
  .PHY_RX(PHY_RX),
  .PHY_DV(PHY_DV),
  .PHY_MDIO(PHY_MDIO),
  .PHY_MDC(PHY_MDC)
);


tb_phy_mdio phy_model (.mdc(PHY_MDC), .mdio_pin(PHY_MDIO));

endmodule

//-----------------------------------------------------------------------------
// Minimal clause-22 PHY on the MDIO bus.
//
// The MAC side (mdio.v) counts one bit per falling clock edge: preamble
// intervals 1..32, ST=01 at 33-34, OP at 35-36 (read=10, write=01),
// PHYAD, REGAD 42..46, then releases the pin at the end of interval 46.
// A PHY turns around there, holds the bus high through 47/48 and drives
// data15..data0 during intervals 49..64.
//
// Frame start is re-synchronised on the first 0 level after at least 32
// consecutive sampled 1s (the preamble), so any inter-frame gap works.
module tb_phy_mdio (
  input  mdc,        // PHY_MDC, which mdio.v ties to its clock
  inout  mdio_pin
);
  integer highs;  // consecutive intervals sampled high
  integer idx;    // interval whose value was just sampled
  integer dbit;
  bit b;
  reg op1 = 0, op0 = 0;
  reg drive = 0;
  reg dval = 1;

  localparam [15:0] RESP = 16'h0090;

  assign mdio_pin = drive ? dval : 1'bz;

  initial begin
    highs = 0;
    idx = 0;
    dbit = 0;
  end

  always @(negedge mdc) begin
    b = mdio_pin;
    drive <= 0;
    if (b) begin
      highs = highs + 1;
      idx = idx + 1;
    end else begin
      if (highs >= 32) idx = 33;  // first 0 of ST -> this is interval 33
      else idx = idx + 1;
      highs = 0;
    end
    case (idx)
      35: op1 <= b;
      36: op0 <= b;
      46: if (op1 && !op0) begin   // read frame: turn around
            drive <= 1; dval <= 1; dbit <= 15;
          end
      47: if (op1 && !op0) begin drive <= 1; dval <= 1; end
      default: ;
    endcase
    if (op1 && !op0 && idx >= 48 && idx <= 63) begin
      drive <= 1;
      dval <= RESP[dbit];
      dbit = dbit - 1;
    end
  end
endmodule
