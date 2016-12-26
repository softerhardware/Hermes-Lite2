
module leds (

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


    reg [31:0]  counter = 32'b10101010101010101010101010101010;

    always @(posedge phy_clk125) counter <= counter + 1;

    assign io_led_d2 = counter[31];
    assign io_led_d3 = counter[30];
    assign io_led_d4 = counter[29];
    assign io_led_d5 = counter[28];

    assign pwr_clk3p3 = 1'b0;
    assign pwr_clk1p2 = 1'b0;
    assign pwr_clkvpa = 1'b0;
    assign pwr_envpa = 1'b0;

    assign phy_tx = 4'h0;
    assign phy_tx_en = 1'b0;              
    assign phy_tx_clk = 1'b0;              
    assign phy_rst_n = 1'b1;
    assign phy_mdio  = counter[31] ? counter[30] : 1'bZ;
    assign phy_mdc = 1'b0;

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

endmodule




