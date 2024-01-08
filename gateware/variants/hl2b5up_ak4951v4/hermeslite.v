
//  Hermes Lite
//
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation; either version 2 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program; if not, write to the Free Software
//  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

// (C) Steve Haynal KF7O 2014-2019
// This RTL originated from www.openhpsdr.org and has been modified to support
// the Hermes-Lite hardware described at http://github.com/softerhardware/Hermes-Lite2.

module hermeslite (
  // Power
  output       pwr_clk3p3           ,
  output       pwr_clk1p2           ,
  output       pwr_envpa            ,
  output       pwr_envop            ,
  output       pwr_envbias          ,
  // Ethernet PHY
  input        phy_clk125           ,
  output [3:0] phy_tx               ,
  output       phy_tx_en            ,
  output       phy_tx_clk           ,
  input  [3:0] phy_rx               ,
  input        phy_rx_dv            ,
  input        phy_rx_clk           ,
  input        phy_rst_n            ,
  inout        phy_mdio             ,
  output       phy_mdc              ,
  // Clock
  output       io_db1_1             , // AK4951 Companion Board V4 ATU ; ATU START
  inout        clk_sda1             ,
  inout        clk_scl1             ,
  // RF Frontend
  output       rffe_ad9866_rst_n    ,
  output [5:0] rffe_ad9866_tx       ,
  input  [5:0] rffe_ad9866_rx       ,
  input        rffe_ad9866_rxsync   ,
  input        rffe_ad9866_rxclk    ,
  output       rffe_ad9866_txquiet_n,
  output       rffe_ad9866_txsync   ,
  output       rffe_ad9866_sdio     ,
  output       rffe_ad9866_sclk     ,
  output       rffe_ad9866_sen_n    ,
  input        rffe_ad9866_clk76p8  ,
  output       rffe_rfsw_sel        ,
  output       rffe_ad9866_mode     ,
  output       rffe_ad9866_pga5     ,
  // IO
  output       io_led_d2            ,
  output       io_led_d3            ,
  output       io_led_d4            ,
  output       io_led_d5            ,
  //
  input  [1:0] io_link_rx           , // AK4951 Companion Board V4 ATU ; [1] ATU KEY(STATUS)
  output [1:0] io_link_tx           ,
  //
  input        io_cn8               ,
  input        io_cn9               ,
  input        io_cn10              ,
  //
  inout        io_adc_scl           ,
  inout        io_adc_sda           ,
  inout        io_scl2              ,
  inout        io_sda2              ,
  //
  output       io_db1_2             , // AK4951 Companion Board V3
  output       io_db1_3             , // AK4951 Companion Board V3
  input        io_db1_4             , // AK4951 Companion Board V3
  output       io_db1_5             , // AK4951 Companion Board V3
  output       io_db1_6             , // AK4951 Companion Board V3
  input        io_phone_tip         ,
  input        io_phone_ring        ,
  input        io_tp2               ,
  input        io_tp7               ,
  input        io_tp8               ,
  input        io_tp9               ,
  //
  output       pa_inttr             ,
  output       pa_exttr
);

wire    io_atu_req;                // AK4951 Companion Board V4 ATU
assign  io_db1_1   = ~io_atu_req;  // AK4951 Companion Board V4 ATU

  hermeslite_core #(
    .BOARD   (5                                    ),
    .IP      ({8'd0,8'd0,8'd0,8'd0}                ),
    .MAC     ({8'h00,8'h1c,8'hc0,8'ha2,8'h13,8'hdd}),
    .NR      (4                                    ),
    .NT      (1                                    ),
    .UART    (1                                    ),
    .ATU     (1                                    ), // AK4951 Companion Board V4 ATU
    .FAN     (0                                    ),
    .PSSYNC  (1                                    ),
    .CW      (2                                    ), // CW_OPENHPSDR
    .ASMII   (1                                    ),
    .HL2LINK (0                                    ),
    .AK4951  (1                                    ),
    .FAST_LNA(1                                    ),
    .EXTENDED_RESP(1                               )
  ) hermeslite_core_i (
    .pwr_clk3p3                (pwr_clk3p3           ),
    .pwr_clk1p2                (pwr_clk1p2           ),
    .pwr_envpa                 (pwr_envpa            ),
    .pwr_envop                 (pwr_envop            ),
    .pwr_envbias               (pwr_envbias          ),
    .phy_clk125                (phy_clk125           ),
    .phy_tx                    (phy_tx               ),
    .phy_tx_en                 (phy_tx_en            ),
    .phy_tx_clk                (phy_tx_clk           ),
    .phy_rx                    (phy_rx               ),
    .phy_rx_dv                 (phy_rx_dv            ),
    .phy_rx_clk                (phy_rx_clk           ),
    .phy_rst_n                 (phy_rst_n            ),
    .phy_mdio                  (phy_mdio             ),
    .phy_mdc                   (phy_mdc              ),
    .clk_sda1                  (clk_sda1             ),
    .clk_scl1                  (clk_scl1             ),
    .rffe_ad9866_rst_n         (rffe_ad9866_rst_n    ),
    .rffe_ad9866_tx            (rffe_ad9866_tx       ),
    .rffe_ad9866_rx            (rffe_ad9866_rx       ),
    .rffe_ad9866_rxsync        (rffe_ad9866_rxsync   ),
    .rffe_ad9866_rxclk         (rffe_ad9866_rxclk    ),
    .rffe_ad9866_txquiet_n     (rffe_ad9866_txquiet_n),
    .rffe_ad9866_txsync        (rffe_ad9866_txsync   ),
    .rffe_ad9866_sdio          (rffe_ad9866_sdio     ),
    .rffe_ad9866_sclk          (rffe_ad9866_sclk     ),
    .rffe_ad9866_sen_n         (rffe_ad9866_sen_n    ),
    .rffe_ad9866_clk76p8       (rffe_ad9866_clk76p8  ),
    .rffe_rfsw_sel             (rffe_rfsw_sel        ),
    .rffe_ad9866_mode          (rffe_ad9866_mode     ),
    .rffe_ad9866_pga5          (rffe_ad9866_pga5     ),
    .io_led_run                (io_led_d2            ),
    .io_led_tx                 (io_led_d3            ),
    .io_led_adc75              (io_led_d4            ),
    .io_led_adc100             (io_led_d5            ),
    .io_tx_envelope_pwm_out    (                     ), // AK4951 Companion Board V4 ATU
    .io_tx_envelope_pwm_out_inv(                     ),
    .io_tx_inhibit             (io_cn8               ),
    .io_id_hermeslite          (io_cn9               ),
    .io_alternate_mac          (io_cn10              ),
    .io_adc_scl                (io_adc_scl           ),
    .io_adc_sda                (io_adc_sda           ),
    .io_scl2                   (io_scl2              ),
    .io_sda2                   (io_sda2              ),
    .io_uart_txd               (io_db1_3             ), // AK4951 Companion Board V3
    .io_uart_rxd               (1'b0                 ),
    .io_cw_keydown             (                     ),
    .io_phone_tip              (io_phone_tip         ),
    .io_phone_ring             (io_phone_ring        ),
    .io_atu_ack                (~io_link_rx[1]       ), // AK4951 Companion Board V4 ATU
    .io_atu_req                (io_atu_req           ), // AK4951 Companion Board V4 ATU
    .pa_inttr                  (pa_inttr             ),
    .pa_exttr                  (pa_exttr             ),
    .fan_pwm                   (                     ),

    .pa_exttr_clone            (io_db1_5             ), // AK4951 Companion Board V3
    .io_ptt_in                 (io_db1_4             ), // AK4951 Companion Board V3
    .i2s_pdn                   (io_db1_6             ), // AK4951 Companion Board V3
    .i2s_bck                   (io_link_tx[0]        ), // AK4951 Companion Board V3
    .i2s_lrck                  (io_link_tx[1]        ), // AK4951 Companion Board V3
    .i2s_miso                  (io_link_rx[0]        ), // AK4951 Companion Board V3
    .i2s_mosi                  (io_db1_2             )  // AK4951 Companion Board V3
  );

endmodule



