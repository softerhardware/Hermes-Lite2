
module top (

    // Power
    output          pwr_clk3p3,
    output          pwr_clk1p2,
    output          pwr_clkvpa,
    output          pwr_envpa,

    // Ethernet PHY
    input           phy_clk125,
    output  [3:0]   phy_tx,
    output          phy_tx_en,
    output          phy_tx_clk,
    input   [3:0]   phy_rx,
    input           phy_rx_dv,
    input           phy_rx_clk,
    output          phy_rst_n,
    inout           phy_mdio,
    output          phy_mdc,

    // Clock
    output          clk_recovered,
    inout           clk_sda1,
    output          clk_scl1,

    // RF Frontend
    output          rffe_ad9866_rst_n,
    //(* useioff = 1 *)
    output  [5:0]   rffe_ad9866_tx,
    input   [5:0]   rffe_ad9866_rx,
    input           rffe_ad9866_rxsync,
    //(* useioff = 1 *)
    output          rffe_ad9866_txsync,
    output          rffe_ad9866_txquiet_n,
    output          rffe_ad9866_sdio,
    output          rffe_ad9866_sclk,
    output          rffe_ad9866_sen_n,
    output  [5:0]   rffe_ad9866_pga,
    input           rffe_ad9866_rxclk,
    input           rffe_ad9866_clk76p8,
    output          rffe_rfsw_sel,

    // IO
    output          io_led_d2,
    output          io_led_d3,
    output          io_led_d4,
    output          io_led_d5,
    input           io_cn4_2,
    input           io_cn4_3,
    input           io_cn4_6,
    input           io_cn4_7,
    input           io_cn5_2,
    input           io_cn5_3,
    input           io_cn5_6,
    input           io_cn5_7,
    input           io_db22_2,
    input           io_db22_3,
    output          io_adc_scl,
    inout           io_adc_sda,
    input           io_cn8,
    input           io_cn9,
    input           io_cn10,
    output          io_scl2,
    inout           io_sda2,
    input           io_tp2,
    input           io_db24,

    // PA
    output          pa_tr,
    output          pa_en);

    wire this_MAC;
    wire run;
    wire reset;

    reg [31:0]  counter = 32'b10101010101010101010101010101010;


    wire clock_125_mhz_0_deg;
    wire clock_125_mhz_90_deg;
    wire clock_12_5MHz;
    wire clock_2_5MHz;

    ethpll ethpll_inst (
    	.inclk0   (phy_clk125),   //  refclk.clk
    	.areset   (1'b0),      //   reset.reset
    	.c0 (clock_125_mhz_0_deg), // outclk0.clk
    	.c1 (clock_125_mhz_90_deg), // outclk1.clk
    	.c2 (clock_12_5MHz), // outclk2.clk
    	.c3 (clock_2_5MHz) // outclk3.clk
    );

    assign phy_tx_clk = clock_125_mhz_90_deg;

    always @(posedge clock_125_mhz_0_deg) counter <= counter + 1;

    assign io_led_d4 = 1'b1;
    assign io_led_d5 = 1'b1;

    assign pwr_clk3p3 = 1'b0;
    assign pwr_clk1p2 = 1'b0;
    assign pwr_clkvpa = 1'b0;
    assign pwr_envpa = 1'b0;

    assign clk_recovered = 1'b0;
    assign clk_sda1 = counter[29] ? counter[28] : 1'bZ;
    assign clk_scl1 = 1'b0;

    assign rffe_ad9866_rst_n = 1'b0;
    assign rffe_ad9866_tx = 6'b000000;
    assign rffe_ad9866_txsync = 1'b0;
    assign rffe_ad9866_txquiet_n = 1'b0;
    assign rffe_ad9866_sdio= 1'b0;
    assign rffe_ad9866_sclk = 1'b0;
    assign rffe_ad9866_sen_n = 1'b1;
    assign rffe_ad9866_pga = 6'b000000;
    assign rffe_rfsw_sel = 1'b0;

    assign io_adc_scl = 1'b0;
    assign io_adc_sda = counter[30] ? counter[29] : 1'bZ;
    assign io_scl2 = 1'b0;
    assign io_sda2 = counter[28] ? counter[27] : 1'bZ;

    assign pa_tr = 1'b0;
    assign pa_en = 1'b0;


    ethernet #(.MAC({8'h00,8'h1c,8'hc0,8'ha2,8'h22,8'hdd}), .IP({8'd0,8'd0,8'd0,8'd0}), .Hermes_serialno(8'd31)) ethernet_inst (

      // Send to ethernet
      .clock_2_5MHz(clock_2_5MHz),
      .tx_clock(clock_125_mhz_0_deg),
      .Tx_fifo_rdreq_o(),
      .PHY_Tx_data_i(8'h00),
      .PHY_Tx_rdused_i(11'h000),

      .sp_fifo_rddata_i(8'h00),
      .sp_data_ready_i(1'b0),
      .sp_fifo_rdreq_o(),

      // Receive from ethernet
      .PHY_data_clock_o(),
      .Rx_enable_o(),
      .Rx_fifo_data_o(),

      // Status
      .this_MAC_o(this_MAC),
      .run_o(run),
      .IF_rst_i(1'b0),
      .reset_o(reset),
      .dipsw_i(2'b01),
      .AssignNR(8'h01),

      // MII Ethernet PHY
      .PHY_TX(phy_tx),
      .PHY_TX_EN(phy_tx_en),              //PHY Tx enable
      .PHY_RX(phy_rx),
      .RX_DV(phy_rx_dv),                  //PHY has data flag
      .PHY_RX_CLOCK(phy_rx_clk),           //PHY Rx data clock
      .PHY_RESET_N(phy_rst_n),
      .PHY_MDIO(phy_mdio),
      .PHY_MDC(phy_mdc)
    );

    // Really 0.16 seconds at Hermes-Lite 61.44 MHz clock
    localparam half_second = 10000000; // at 48MHz clock rate

    Led_flash Flash_LED4(.clock(clock_125_mhz_0_deg), .signal(this_MAC), .LED(io_led_d2), .period(half_second));
    Led_flash Flash_LED5(.clock(clock_125_mhz_0_deg), .signal(run), .LED(io_led_d3), .period(half_second));

endmodule
