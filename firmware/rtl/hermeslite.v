//
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

// (C) Phil Harman VK6APH, Kirk Weedman KD7IRS  2006, 2007, 2008, 2009, 2010, 2011, 2012, 2013, 2014
// (C) Steve Haynal KF7O 2014-2017


// This RTL originated from www.openhpsdr.org and has been modified to support
// the Hermes-Lite hardware described at http://github.com/softerhardware/Hermes-Lite2.

module hermeslite(

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
  input           phy_rst_n,
  inout           phy_mdio,
  output          phy_mdc,

  // Clock
  output          clk_recovered,
  inout           clk_sda1,
  inout           clk_scl1,

  // RF Frontend
  output          rffe_ad9866_rst_n,
  (* useioff = 1 *) output  [5:0]   rffe_ad9866_tx,
  input   [5:0]   rffe_ad9866_rx,
  input           rffe_ad9866_rxsync,
  (* useioff = 1 *) output          rffe_ad9866_txsync,
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
  output          io_adc_sda,
  input           io_cn8,
  input           io_cn9,
  input           io_cn10,
  inout           io_scl2,
  inout           io_sda2,
  input           io_tp2,
  input           io_db24,

  // PA
  output          pa_tr,
  output          pa_en);


// PARAMETERS

// Ethernet Interface
parameter MAC = {8'h00,8'h1c,8'hc0,8'ha2,8'h12,8'hdd};
parameter IP = {8'd0,8'd0,8'd0,8'd0};

// ADC Oscillator
parameter CLK_FREQ = 76800000;

// B57 = 2^57.   M2 = B57/OSC
// 61440000
//localparam M2 = 32'd2345624805;
// 61440000-400
//localparam M2 = 32'd2345640077;
localparam M2 = (CLK_FREQ == 61440000) ? 32'd2345640077 : (CLK_FREQ == 79872000) ? 32'd1804326773 : (CLK_FREQ == 76800000) ? 32'd1876499845 : 32'd1954687338;

// M3 = 2^24 to round as version 2.7
localparam M3 = 32'd16777216;

// Decimation rates
localparam RATE48  = (CLK_FREQ == 61440000) ? 6'd16 : (CLK_FREQ == 79872000) ? 6'd16 : (CLK_FREQ == 76800000) ? 6'd40 : 6'd24;
localparam RATE96  =  RATE48  >> 1;
localparam RATE192 =  RATE96  >> 1;
localparam RATE384 =  RATE192 >> 1;

localparam CICRATE = (CLK_FREQ == 61440000) ? 6'd10 : (CLK_FREQ == 79872000) ? 6'd13 : (CLK_FREQ == 76800000) ? 6'd05 : 6'd08;
localparam GBITS = (CLK_FREQ == 61440000) ? 30 : (CLK_FREQ == 79872000) ? 31 : (CLK_FREQ == 76800000) ? 31 : 31;
localparam RRRR = (CLK_FREQ == 61440000) ? 160 : (CLK_FREQ == 79872000) ? 208 : (CLK_FREQ == 76800000) ? 200 : 192;


// VNA Settings
localparam VNATXGAIN = 6'h10;
localparam DUPRXMAXGAIN = 6'h12;
localparam DUPRXMINGAIN = 6'h06;

// Number of Receivers
parameter NR = 2;     // number of receivers to implement
wire [7:0] AssignNR;         // IP address read from EEPROM
assign AssignNR = NR;

// Number of transmitters Be very careful when using more than 1 transmitter!
parameter NT = 1;

// Experimental Predistort On=1 Off=0
parameter PREDISTORT = 0;

wire FPGA_PTT;

parameter M_TPD   = 4;
parameter IF_TPD  = 2;

parameter  Hermes_serialno = 8'd31;     // Serial number of this version
localparam Penny_serialno = 8'd00;      // Use same value as equ1valent Penny code
localparam Merc_serialno = 8'd00;       // Use same value as equivalent Mercury code

localparam RX_FIFO_SZ  = 4096;          // 16 by 4096 deep RX FIFO
localparam TX_FIFO_SZ  = 1024;          // 16 by 1024 deep TX FIFO
localparam SP_FIFO_SZ = 2048;           // 16 by 8192 deep SP FIFO, was 16384 but wouldn't fit


localparam bit [0:19][8:0] initarray_nointerpolation = {
    // First bit is 1'b1 for write enable to that address
    {1'b1,8'h80}, // Address 0x00, enable 4 wire SPI
    {1'b0,8'h00}, // Address 0x01,
    {1'b0,8'h00}, // Address 0x02,
    {1'b0,8'h00}, // Address 0x03,
    {1'b1,8'h00}, // Address 0x04, // No multiply of oscillator for no interpolation
    {1'b0,8'h00}, // Address 0x05,
    {1'b1,8'h00}, // Address 0x06, // No divide down for FPGA clock
    {1'b1,8'h21}, // Address 0x07, Initiate DC offset calibration and RX filter on
    {1'b1,8'h4b}, // Address 0x08, RX filter f-3db at ~34 MHz after scaling
    {1'b0,8'h00}, // Address 0x09,
    {1'b0,8'h00}, // Address 0x0a,
    {1'b1,8'h20}, // Address 0x0b, RX gain only on PGA
    {1'b1,8'h81}, // Address 0x0c, TX twos complement and interpolation factor
    {1'b1,8'h01}, // Address 0x0d, RT twos complement
    {1'b0,8'h01}, // Address 0x0e, Enable/Disable IAMP
    {1'b0,8'h00}, // Address 0x0f,
    {1'b0,8'h84}, // Address 0x10, Select TX gain
    {1'b1,8'h00}, // Address 0x11, Select TX gain
    {1'b0,8'h00}, // Address 0x12,
    {1'b0,8'h00}  // Address 0x13,
};

localparam bit [0:19][8:0] initarray_2xosc = {
    // First bit is 1'b1 for write enable to that address
    {1'b1,8'h80}, // Address 0x00, enable 4 wire SPI
    {1'b0,8'h00}, // Address 0x01,
    {1'b0,8'h00}, // Address 0x02,
    {1'b0,8'h00}, // Address 0x03,
    {1'b1,8'h16}, // Address 0x04,
    {1'b0,8'h00}, // Address 0x05,
    {1'b0,8'h00}, // Address 0x06,
    {1'b1,8'h21}, // Address 0x07, Initiate DC offset calibration and RX filter on
    {1'b1,8'h4b}, // Address 0x08, RX filter f-3db at ~34 MHz after scaling
    {1'b0,8'h00}, // Address 0x09,
    {1'b0,8'h00}, // Address 0x0a,
    {1'b1,8'h20}, // Address 0x0b, RX gain only on PGA
    {1'b1,8'h41}, // Address 0x0c, TX twos complement and interpolation factor
    {1'b1,8'h01}, // Address 0x0d, RT twos complement
    {1'b0,8'h01}, // Address 0x0e, Enable/Disable IAMP
    {1'b0,8'h00}, // Address 0x0f,
    {1'b0,8'h84}, // Address 0x10, Select TX gain
    {1'b1,8'h00}, // Address 0x11, Select TX gain
    {1'b0,8'h00}, // Address 0x12,
    {1'b0,8'h00}  // Address 0x13,
};

localparam bit [0:19][8:0] initarray_disable_IAMP = {
    // First bit is 1'b1 for write enable to that address
    {1'b0,8'h80}, // Address 0x00, enable 4 wire SPI
    {1'b0,8'h00}, // Address 0x01,
    {1'b0,8'h00}, // Address 0x02,
    {1'b0,8'h00}, // Address 0x03,
    {1'b0,8'h00}, // Address 0x04,
    {1'b0,8'h00}, // Address 0x05,
    {1'b0,8'h00}, // Address 0x06,
    {1'b1,8'h21}, // Address 0x07, Initiate DC offset calibration and RX filter on
    {1'b1,8'h4b}, // Address 0x08, RX filter f-3db at ~34 MHz after scaling
    {1'b0,8'h00}, // Address 0x09,
    {1'b0,8'h00}, // Address 0x0a,
    {1'b1,8'h20}, // Address 0x0b, RX gain only on PGA
    {1'b1,8'h41}, // Address 0x0c, TX twos complement and interpolation factor
    {1'b1,8'h01}, // Address 0x0d, RT twos complement
    {1'b1,8'h01}, // Address 0x0e, Enable/Disable IAMP
    {1'b0,8'h00}, // Address 0x0f,
    {1'b0,8'h84}, // Address 0x10, Select TX gain
    {1'b1,8'h00}, // Address 0x11, Select TX gain
    {1'b0,8'h00}, // Address 0x12,
    {1'b0,8'h00}  // Address 0x13,
};

localparam bit [0:19][8:0] initarray_6m = {
    // First bit is 1'b1 for write enable to that address
    {1'b1,8'h80}, // Address 0x00, enable 4 wire SPI
    {1'b0,8'h00}, // Address 0x01,
    {1'b0,8'h00}, // Address 0x02,
    {1'b0,8'h00}, // Address 0x03,
    {1'b1,8'h00}, // Address 0x04, // No multiply of oscillator for no interpolation
    {1'b0,8'h00}, // Address 0x05,
    {1'b1,8'h00}, // Address 0x06, // No divide down for FPGA clock
    {1'b1,8'h20}, // Address 0x07, Initiate DC offset calibration and RX filter *OFF*
    {1'b1,8'h4b}, // Address 0x08, RX filter f-3db at ~34 MHz after scaling
    {1'b0,8'h00}, // Address 0x09,
    {1'b0,8'h00}, // Address 0x0a,
    {1'b1,8'h20}, // Address 0x0b, RX gain only on PGA
    {1'b1,8'h81}, // Address 0x0c, TX twos complement and interpolation factor
    {1'b1,8'h01}, // Address 0x0d, RX twos complement
    {1'b1,8'h01}, // Address 0x0e, Enable/Disable IAMP
    {1'b0,8'h00}, // Address 0x0f,
    {1'b0,8'h84}, // Address 0x10, Select TX gain
    {1'b1,8'h00}, // Address 0x11, Select TX gain
    {1'b0,8'h00}, // Address 0x12,
    {1'b0,8'h00}  // Address 0x13,
};

localparam bit [0:19][8:0] initarray_regular = {
    // First bit is 1'b1 for write enable to that address
    {1'b0,8'h80}, // Address 0x00, enable 4 wire SPI
    {1'b0,8'h00}, // Address 0x01,
    {1'b0,8'h00}, // Address 0x02,
    {1'b0,8'h00}, // Address 0x03,
    {1'b0,8'h00}, // Address 0x04,
    {1'b0,8'h00}, // Address 0x05,
    {1'b0,8'h00}, // Address 0x06,
    {1'b1,8'h21}, // Address 0x07, Initiate DC offset calibration and RX filter on
    {1'b1,8'h4b}, // Address 0x08, RX filter f-3db at ~34 MHz after scaling
    {1'b0,8'h00}, // Address 0x09,
    {1'b0,8'h00}, // Address 0x0a,
    {1'b1,8'h20}, // Address 0x0b, RX gain only on PGA
    {1'b1,8'h41}, // Address 0x0c, TX twos complement and interpolation factor
    {1'b1,8'h01}, // Address 0x0d, RT twos complement
    {1'b0,8'h01}, // Address 0x0e, Enable/Disable IAMP
    {1'b0,8'h00}, // Address 0x0f,
    {1'b0,8'h84}, // Address 0x10, Select TX gain
    {1'b1,8'h00}, // Address 0x11, Select TX gain
    {1'b0,8'h00}, // Address 0x12,
    {1'b0,8'h00}  // Address 0x13,
};


localparam disable_IAMP = 1'b1;
localparam bit [0:19][8:0] initarray0 = (disable_IAMP == 1) ? initarray_disable_IAMP : initarray_regular;


// Set initarray1 to other value to select between two configurations
// Must reset or repower HL to take effect
localparam bit [0:19][8:0] initarray1 = initarray0;

// No interpolation and not filter for 6M
//localparam bit [0:19][8:0] initarray1 = initarray_6m;

// Based on dip switch
// SDK has just two dip switches, dipsw[2]==dipsw[1] in SDK, dipsw[1]
// CV has three dip switches
// CVA9 has four dip switches but only three are currently connected
// dipsw[2:1] select alternate MAC addresses
// dipsw[0] selects to identify as hermes or hermes-lite
// Use dipsw[2] is used for initarray selection. This will also change the MAC but that is okay and may be desirable


assign pwr_clk3p3 = 1'b0;
assign pwr_clk1p2 = 1'b0;
assign pwr_clkvpa = 1'b0;
assign pwr_envpa = 1'b1;

assign io_adc_scl = 1'b0;
assign io_adc_sda = 1'b0;
//assign io_scl2 = 1'b0;
//assign io_sda2 = 1'b0;

assign clk_recovered = 1'b0;


// Reset and Clock Control

wire clock_125_mhz_0_deg;
wire clock_125_mhz_90_deg;
wire clock_2_5MHz;
wire ethpll_locked;

ethpll ethpll_inst (
    .inclk0   (phy_clk125),   //  refclk.clk
    .c0 (clock_125_mhz_0_deg), // outclk0.clk
    .c1 (clock_125_mhz_90_deg), // outclk1.clk
    .c2 (clock_2_5MHz), // outclk2.clk
    .locked (ethpll_locked)
);

wire ethup;

// phy_rst_n will go high after ~50ms due to RC
// ethpll_locked will go high once pll is locked
assign ethup = ethpll_locked & phy_rst_n;

// ethup starts I2C configuration of the Versa
// the PLL may lock twice the frequency changes

wire clock_76p8_mhz;
wire clock_153p6_mhz;
wire ad9866pll_locked;

ad9866pll ad9866pll_inst (
  .inclk0   (rffe_ad9866_clk76p8),   //  refclk.clk
  .areset   (~ethup),      //   reset.reset
  .c0 (clock_76p8_mhz), // outclk0.clk
  .c1 (clock_153p6_mhz), // outclk1.clk
  .locked (ad9866pll_locked)
);

// Most FPGA logic is reset when ethernet is up and ad9866 PLL is locked
// AD9866 is released from reset
wire rst;
wire clk_i2c_rst;
wire clk_i2c_start;

reg [15:0] resetcounter = 16'h0000;
always @ (posedge clock_2_5MHz)
  if (~resetcounter[15] & ethup) resetcounter <= resetcounter + 16'h01;

assign clk_i2c_rst = ~(|resetcounter[15:10]);
assign clk_i2c_start = ~(|resetcounter[15:11]);
assign rst = ~(|resetcounter[15:14]);

reg ad9866_rst_n = 1'b0;

always @ (posedge clock_2_5MHz)
  if (resetcounter[15] & ad9866pll_locked) ad9866_rst_n <= 1'b1;

assign rffe_ad9866_rst_n = ad9866_rst_n;







//--------------------------------------------------------------
// Reset Lines - C122_rst, rst
//--------------------------------------------------------------


// transfer rst to 122.88MHz clock domain to generate C122_rst
cdc_sync #(1)
    reset_C122 (.siga(rst), .rstb(rst), .clkb(clock_76p8_mhz), .sigb(C122_rst)); // 122.88MHz clock domain reset

//---------------------------------------------------------
//      CLOCKS
//---------------------------------------------------------

wire CLRCLK;

wire C122_cbclk, C122_cbrise, C122_cbfall;
Hermes_clk_lrclk_gen #(.CLK_FREQ(CLK_FREQ)) clrgen (.reset(C122_rst), .CLK_IN(clock_76p8_mhz), .BCLK(C122_cbclk),
                             .Brise(C122_cbrise), .Bfall(C122_cbfall), .LRCLK(CLRCLK));


wire Tx_fifo_rdreq;
wire [10:0] PHY_Tx_rdused;
wire PHY_data_clock;
wire Rx_enable;
wire [7:0] Rx_fifo_data;

wire this_MAC;
wire run;



assign phy_tx_clk = clock_125_mhz_90_deg;


// FIXME: Proper frequency for IF_clk or remove
// FIXME: Proper frequency for slow clock or remove
// FIXME: Slow clock proper frequench or remove
wire IF_clk;
wire ad9866spiclk;


wire cwkey_i;
wire ptt_i;
wire [7:0] leds;

assign IF_clk = clock_76p8_mhz;
assign ad9866spiclk = clock_76p8_mhz;

assign cwkey_i = 1'b1;
assign ptt_i = 1'b1;


ethernet #(.MAC(MAC), .IP(IP), .Hermes_serialno(Hermes_serialno)) ethernet_inst (

    // Send to ethernet
    .clock_2_5MHz(clock_2_5MHz),
    .tx_clock(clock_125_mhz_0_deg),
    .Tx_fifo_rdreq_o(Tx_fifo_rdreq),
    .PHY_Tx_data_i(PHY_Tx_data),
    .PHY_Tx_rdused_i(PHY_Tx_rdused),

    .sp_fifo_rddata_i(sp_fifo_rddata),
    .sp_data_ready_i(sp_data_ready),
    .sp_fifo_rdreq_o(sp_fifo_rdreq),

    // Receive from ethernet
    .PHY_data_clock_o(PHY_data_clock),
    .Rx_enable_o(Rx_enable),
    .Rx_fifo_data_o(Rx_fifo_data),

    // Status
    .this_MAC_o(this_MAC),
    .run_o(run),
    .dipsw_i(2'b01),
    .AssignNR(AssignNR),

    // MII Ethernet PHY
    .PHY_TX(phy_tx),
    .PHY_TX_EN(phy_tx_en),              //PHY Tx enable
    .PHY_RX(phy_rx),
    .RX_DV(phy_rx_dv),                  //PHY has data flag
    .PHY_RX_CLOCK(phy_rx_clk),           //PHY Rx data clock
    .PHY_MDIO(phy_mdio),
    .PHY_MDC(phy_mdc)
);



//----------------------------------------------------
//   Receive PHY FIFO
//----------------------------------------------------

/*
                        PHY_Rx_fifo (16k bytes)

                        ---------------------
      Rx_fifo_data |data[7:0]     wrfull | PHY_wrfull ----> Flash LED!
                        |                        |
        Rx_enable   |wrreq                 |
                        |                         |
    PHY_data_clock  |>wrclk                |
                        ---------------------
  IF_PHY_drdy     |rdreq          q[15:0]| IF_PHY_data [swap Endian]
                       |                          |
                    |                rdempty| IF_PHY_rdempty
                     |                    |
             IF_clk |>rdclk rdusedw[12:0]|
                       ---------------------
                       |                    |
             rst  |aclr                |
                       ---------------------

 NOTE: the rdempty stays asserted until enough words have been written to the input port to fill an entire word on the
 output port. Hence 4 writes must take place for this to happen.
 Also, rdusedw indicates how many 16 bit samples are available to be read.

*/

wire PHY_wrfull;
wire IF_PHY_rdempty;
wire IF_PHY_drdy;


PHY_Rx_fifo PHY_Rx_fifo_inst(.wrclk (PHY_data_clock),.rdreq (IF_PHY_drdy),.rdclk (IF_clk),.wrreq(Rx_enable),
                .data (Rx_fifo_data),.q ({IF_PHY_data[7:0],IF_PHY_data[15:8]}), .rdempty(IF_PHY_rdempty),
                .wrfull(PHY_wrfull),.aclr(rst | PHY_wrfull));




//------------------------------------------------
//   SP_fifo  (16384 words) dual clock FIFO
//------------------------------------------------

/*
        The spectrum data FIFO is 16 by 16384 words long on the input.
        Output is in Bytes for easy interface to the PHY code
        NB: The output flags are only valid after a read/write clock has taken place


                               SP_fifo
                        ---------------------
          temp_ADC |data[15:0]     wrfull| sp_fifo_wrfull
                        |                        |
    sp_fifo_wrreq   |wrreq       wrempty| sp_fifo_wrempty
                        |                        |
            C122_clk    |>wrclk              |
                        ---------------------
    sp_fifo_rdreq   |rdreq         q[7:0]| sp_fifo_rddata
                        |                    |
                        |                        |
        clock_125_mhz_0_deg  |>rdclk              |
                        |                      |
                        ---------------------
                        |                    |
     C122_rst OR   |aclr                |
        !run       |                    |
                        ---------------------

*/

wire  sp_fifo_rdreq;
wire [7:0]sp_fifo_rddata;
wire sp_fifo_wrempty;
wire sp_fifo_wrfull;
wire sp_fifo_wrreq;
wire have_sp_data;

//--------------------------------------------------
//   Wideband Spectrum Data
//--------------------------------------------------

//  When wide_spectrum is set and sp_fifo_wrempty then fill fifo with 16k words
// of consecutive ADC samples.  Pass have_sp_data to Tx_MAC to indicate that
// data is available.
// Reset fifo when !run so the data always starts at a known state.


SP_fifo  SPF (.aclr(C122_rst | !run), .wrclk (clock_76p8_mhz), .rdclk(clock_125_mhz_0_deg),
             .wrreq (sp_fifo_wrreq), .data ({{4{temp_ADC[11]}},temp_ADC}), .rdreq (sp_fifo_rdreq),
             .q(sp_fifo_rddata), .wrfull(sp_fifo_wrfull), .wrempty(sp_fifo_wrempty));


sp_rcv_ctrl SPC (.clk(clock_76p8_mhz), .reset(C122_rst), .sp_fifo_wrempty(sp_fifo_wrempty),
                 .sp_fifo_wrfull(sp_fifo_wrfull), .write(sp_fifo_wrreq), .have_sp_data(have_sp_data));

// the wideband data is presented too fast for the PC to swallow so slow down

wire sp_data_ready;



// rate is 125e6/2**19
reg [18:0]sp_delay;
always @ (posedge clock_125_mhz_0_deg)
    sp_delay <= sp_delay + 15'd1;
assign sp_data_ready = (sp_delay == 0 && have_sp_data);


assign IF_mic_Data = 0;

//---------------------------------------------------------
//      De-ramdomizer
//---------------------------------------------------------

/*

 A Digital Output Randomizer is fitted to the LTC2208. This complements bits 15 to 1 if
 bit 0 is 1. This helps to reduce any pickup by the A/D input of the digital outputs.
 We need to de-ramdomize the LTC2208 data if this is turned on.

*/

//Test sine wave for DAC
//reg [11:0] cosv;
// reg [5:0] cosi;
// always @(posedge clock_76p8_mhz)
//     if (cosi < 58) cosi <= cosi + 1;
//     else cosi <= 0;
//
// wire [11:0] cosv;
// always @(cosi)
//   begin
//     case (cosi)
//         6'h00 : cosv = 12'h07fe;
//         6'h01 : cosv = 12'h0bbe;
//         6'h02 : cosv = 12'h0c89;
//         6'h03 : cosv = 12'h07f5;
//         6'h04 : cosv = 12'h0afe;
//         6'h05 : cosv = 12'h0d59;
//         6'h06 : cosv = 12'h07db;
//         6'h07 : cosv = 12'h0a4e;
//         6'h08 : cosv = 12'h0e2a;
//         6'h09 : cosv = 12'h07ad;
//         6'h0a : cosv = 12'h09b2;
//         6'h0b : cosv = 12'h0efb;
//         6'h0c : cosv = 12'h0768;
//         6'h0d : cosv = 12'h092e;
//         6'h0e : cosv = 12'h0fcc;
//         6'h0f : cosv = 12'h070a;
//         6'h10 : cosv = 12'h08c4;
//         6'h11 : cosv = 12'h009c;
//         6'h12 : cosv = 12'h0693;
//         6'h13 : cosv = 12'h0873;
//         6'h14 : cosv = 12'h016d;
//         6'h15 : cosv = 12'h0603;
//         6'h16 : cosv = 12'h083a;
//         6'h17 : cosv = 12'h023f;
//         6'h18 : cosv = 12'h055c;
//         6'h19 : cosv = 12'h0815;
//         6'h1a : cosv = 12'h0310;
//         6'h1b : cosv = 12'h04a3;
//         6'h1c : cosv = 12'h0804;
//         6'h1d : cosv = 12'h03dd;
//         6'h1e : cosv = 12'h03dd;
//         6'h1f : cosv = 12'h0804;
//         6'h20 : cosv = 12'h04a3;
//         6'h21 : cosv = 12'h0310;
//         6'h22 : cosv = 12'h0815;
//         6'h23 : cosv = 12'h055c;
//         6'h24 : cosv = 12'h023f;
//         6'h25 : cosv = 12'h083a;
//         6'h26 : cosv = 12'h0603;
//         6'h27 : cosv = 12'h016d;
//         6'h28 : cosv = 12'h0873;
//         6'h29 : cosv = 12'h0693;
//         6'h2a : cosv = 12'h009c;
//         6'h2b : cosv = 12'h08c4;
//         6'h2c : cosv = 12'h070a;
//         6'h2d : cosv = 12'h0fcc;
//         6'h2e : cosv = 12'h092e;
//         6'h2f : cosv = 12'h0768;
//         6'h30 : cosv = 12'h0efb;
//         6'h31 : cosv = 12'h09b2;
//         6'h32 : cosv = 12'h07ad;
//         6'h33 : cosv = 12'h0e2a;
//         6'h34 : cosv = 12'h0a4e;
//         6'h35 : cosv = 12'h07db;
//         6'h36 : cosv = 12'h0d59;
//         6'h37 : cosv = 12'h0afe;
//         6'h38 : cosv = 12'h07f5;
//         6'h39 : cosv = 12'h0c89;
//         default : cosv = 12'h0bbe;
//     endcase
//   end



reg [11:0]temp_ADC;
//reg [15:0] temp_DACD; // for pre-distortion Tx tests
//reg ad9866clipp, ad9866clipn;
//reg ad9866nearclip;
//reg ad9866goodlvlp, ad9866goodlvln;

//assign temp_DACD = 0;

wire rxclipp = (temp_ADC == 12'b011111111111);
wire rxclipn = (temp_ADC == 12'b100000000000);

// Near clips occur just over 1 dB from full range
// 2**12 = 4096
// (6.02*12)+1.76 = 74
// 2**11.8074 = 3584
// 4096-3584 = 512 (256 from positive and 256 from negtive clips)
// (6.02*11.8074)+1.76 = 72.84
// 74 - 72.84 = ~1.16 dB from full range
wire rxnearclip = (temp_ADC[11:8] == 4'b0111) | (temp_ADC[11:8] == 4'b1000);


// Like above but 2**11.585 = (4096-1024) = 3072
wire rxgoodlvlp = (temp_ADC[11:9] == 3'b011);
wire rxgoodlvln = (temp_ADC[11:9] == 3'b100);


// Pipeline DACD just before IO, negedge as in historical RTL
reg [11:0] DACDp;
always @ (negedge clock_76p8_mhz)
    DACDp <= DACD;
    //DACDp <= cosv;


reg [11:0] ad9866_rx_stage;
reg [11:0] ad9866_rx_input;

// Assume that ad9866_rxclk is synchronous to ad9866clk
// Don't know the phase relation
always @(posedge rffe_ad9866_rxclk)
    begin
        if (rffe_ad9866_rxsync) begin
            ad9866_rx_stage[5:0] <= rffe_ad9866_rx;
        end else begin
            ad9866_rx_stage[11:6] <= rffe_ad9866_rx;
            ad9866_rx_input <= ad9866_rx_stage;
        end
    end

reg iad9866_txsync;
reg [11:0] ad9866_tx_stage;
// TX path
always @(negedge rffe_ad9866_rxclk)
    begin
        if (iad9866_txsync) begin
            iad9866_txsync <= 1'b0;
            ad9866_tx_stage <= ( (FPGA_PTT | VNA) ? DACDp : 12'b000);
        end else begin
            iad9866_txsync <= 1'b1;
        end
    end

reg [5:0] ad9866_txr;
reg ad9866_txsyncr;

always @(negedge rffe_ad9866_rxclk)
    begin
        ad9866_txr <= iad9866_txsync ? ad9866_tx_stage[5:0] : ad9866_tx_stage[11:6];
        ad9866_txsyncr <= iad9866_txsync;
    end

assign rffe_ad9866_txquiet_n = (FPGA_PTT | VNA); //1'b0;
assign rffe_ad9866_tx = ad9866_txr;
assign rffe_ad9866_txsync = ad9866_txsyncr;



//assign userout = IF_OC;


// Pipeline RX



always @ (posedge clock_76p8_mhz)
  begin
    temp_ADC <= ad9866_rx_input;
  end

// AGC

reg agc_nearclip;
reg agc_goodlvl;
reg [25:0] agc_delaycnt;
reg [5:0] agc_value;
wire agc_clrnearclip;
wire agc_clrgoodlvl;

always @(posedge clock_76p8_mhz)
begin
    if (agc_clrnearclip) agc_nearclip <= 1'b0;
    else if (rxnearclip) agc_nearclip <= 1'b1;
end

always @(posedge clock_76p8_mhz)
begin
    if (agc_clrgoodlvl) agc_goodlvl <= 1'b0;
    else if (rxgoodlvlp | rxgoodlvln) agc_goodlvl <= 1'b1;
end

// Used for heartbeat too
always @(posedge clock_76p8_mhz)
begin
    agc_delaycnt <= agc_delaycnt + 1;
end

always @(posedge clock_76p8_mhz)
begin
    if (C122_rst)
        agc_value <= 6'b011111;
    // Decrease gain if near clip seen
    else if ( ((agc_clrnearclip & agc_nearclip & (agc_value != 6'b000000)) | agc_value > gain_value ) & ~FPGA_PTT )
        agc_value <= agc_value - 6'h01;
    // Increase if not in the sweet spot of seeing agc_nearclip
    // But no more than ~26dB (38) as that is the place of diminishing returns re the datasheet
    else if ( agc_clrgoodlvl & ~agc_goodlvl & (agc_value <= gain_value) & ~FPGA_PTT )
        agc_value <= agc_value + 6'h01;
end

// tp = 1.0/61.44e6
// 2**26 * tp = 1.0922 seconds
// PGA settling time is less than 500 ns
// Do decrease possible every 2 us (2**7 * tp)
assign agc_clrnearclip = (agc_delaycnt[6:0] == 7'b1111111);
// Do increase possible every 68 ms, 1us before/after a possible descrease
assign agc_clrgoodlvl = (agc_delaycnt[21:0] == 22'b1011111111111110111111);


//------------------------------------------------------------------------------
//                 Transfer  Data from IF clock to 122.88MHz clock domain
//------------------------------------------------------------------------------

// cdc_sync is used to transfer from a slow to a fast clock domain

wire  [31:0] C122_LR_data;
wire  C122_DFS0, C122_DFS1;
wire  C122_rst;
wire  signed [15:0] C122_I_PWM;
wire  signed [15:0] C122_Q_PWM;

cdc_sync #(32)
    freq0 (.siga(IF_frequency[0]), .rstb(C122_rst), .clkb(clock_76p8_mhz), .sigb(C122_frequency_HZ_Tx)); // transfer Tx frequency

cdc_sync #(2)
    rates (.siga({IF_DFS1,IF_DFS0}), .rstb(C122_rst), .clkb(clock_76p8_mhz), .sigb({C122_DFS1, C122_DFS0})); // sample rate

cdc_sync #(16)
    Tx_I  (.siga(IF_I_PWM), .rstb(C122_rst), .clkb(clock_76p8_mhz), .sigb(C122_I_PWM )); // Tx I data

cdc_sync #(16)
    Tx_Q  (.siga(IF_Q_PWM), .rstb(C122_rst), .clkb(clock_76p8_mhz), .sigb(C122_Q_PWM)); // Tx Q data



reg signed [15:0]C122_cic_i;
reg signed [15:0]C122_cic_q;
wire C122_ce_out_i;
wire C122_ce_out_q;

//------------------------------------------------------------------------------
//                 Pulse generators
//------------------------------------------------------------------------------

wire IF_CLRCLK;

//  Create short pulse from posedge of CLRCLK synced to IF_clk for RXF read timing
//  First transfer CLRCLK into IF clock domain
cdc_sync cdc_CRLCLK (.siga(CLRCLK), .rstb(rst), .clkb(IF_clk), .sigb(IF_CLRCLK));
//  Now generate the pulse
pulsegen cdc_m   (.sig(IF_CLRCLK), .rst(rst), .clk(IF_clk), .pulse(IF_get_samples));


//---------------------------------------------------------
//      Convert frequency to phase word
//---------------------------------------------------------

/*
     Calculates  ratio = fo/fs = frequency/122.88Mhz where frequency is in MHz
     Each calculation should take no more than 1 CBCLK

     B scalar multiplication will be used to do the F/122.88Mhz function
     where: F * C = R
     0 <= F <= 65,000,000 hz
     C = 1/122,880,000 hz
     0 <= R < 1

     This method will use a 32 bit by 32 bit multiply to obtain the answer as follows:
     1. F will never be larger than 65,000,000 and it takes 26 bits to hold this value. This will
        be a B0 number since we dont need more resolution than 1 Hz - i.e. fractions of a hertz.
     2. C is a constant.  Notice that the largest value we could multiply this constant by is B26
        and have a signed value less than 1.  Multiplying again by B31 would give us the biggest
        signed value we could hold in a 32 bit number.  Therefore we multiply by B57 (26+31).
        This gives a value of M2 = 1,172,812,403 (B57/122880000)
     3. Now if we multiply the B0 number by the B57 number (M2) we get a result that is a B57 number.
        This is the result of the desire single 32 bit by 32 bit multiply.  Now if we want a scaled
        32 bit signed number that has a range -1 <= R < 1, then we want a B31 number.  Thus we shift
        the 64 bit result right 32 bits (B57 -> B31) or merely select the appropriate bits of the
        64 bit result. Sweet!  However since R is always >= 0 we will use an unsigned B32 result
*/

//------------------------------------------------------------------------------
//                 All DSP code is in the Receiver module
//------------------------------------------------------------------------------

reg       [31:0] C122_frequency_HZ [0:NR-1];   // frequency control bits for CORDIC
reg       [31:0] C122_frequency_HZ_Tx;
reg       [31:0] C122_last_freq [0:NR-1];
reg       [31:0] C122_last_freq_Tx;
wire      [31:0] C122_sync_phase_word [0:NR-1];
wire      [31:0] C122_sync_phase_word_Tx;
wire      [63:0] C122_ratio [0:NR-1];
wire      [63:0] C122_ratio_Tx;
wire      [23:0] rx_I [0:NR-1];
wire      [23:0] rx_Q [0:NR-1];
wire             strobe [0:NR-1];
wire              IF_IQ_Data_rdy;
wire         [47:0] IF_IQ_Data;
wire             test_strobe3;

// Pipeline for adc fanout
reg [11:0] adcpipe [0:3];
always @ (posedge clock_76p8_mhz) begin
    adcpipe[0] <= temp_ADC;
    adcpipe[1] <= temp_ADC;
    adcpipe[2] <= temp_ADC;
    adcpipe[3] <= temp_ADC;
end


// set the decimation rate 40 = 48k.....2 = 960k

    reg [5:0] rate;

    always @ ({C122_DFS1, C122_DFS0})
    begin
        case ({C122_DFS1, C122_DFS0})

        0: rate <= RATE48;     //  48ksps
        1: rate <= RATE96;     //  96ksps
        2: rate <= RATE192;     //  192ksps
        3: rate <= RATE384;      //  384ksps
        default: rate <= RATE48;

        endcase
    end

genvar c;
generate
  for (c = 0; c < NR; c = c + 1) // calc freq phase word for 4 freqs (Rx1, Rx2, Rx3, Rx4)
   begin: MDC
    //  assign C122_ratio[c] = C122_frequency_HZ[c] * M2; // B0 * B57 number = B57 number

   // Note: We add 1/2 M2 (M3) so that we end up with a rounded 32 bit integer below.
    //assign C122_ratio[c] = C122_frequency_HZ[c] * M2 + M3; // B0 * B57 number = B57 number

    //always @ (posedge clock_76p8_mhz)
    //begin
    //  if (C122_cbrise) // time between C122_cbrise is enough for ratio calculation to settle
    //  begin
    //    C122_last_freq[c] <= C122_frequency_HZ[c];
    //    if (C122_last_freq[c] != C122_frequency_HZ[c]) // frequency changed)
    //      C122_sync_phase_word[c] <= C122_ratio[c][56:25]; // B57 -> B32 number since R is always >= 0
    //  end
    //end

    assign C122_sync_phase_word[c] = C122_frequency_HZ[c];

    cdc_mcp #(48)           // Transfer the receiver data and strobe from clock_76p8_mhz to IF_clk
        IQ_sync (.a_data ({rx_I[c], rx_Q[c]}), .a_clk(clock_76p8_mhz),.b_clk(IF_clk), .a_data_rdy(strobe[c]),
                .a_rst(C122_rst), .b_rst(rst), .b_data(IF_M_IQ_Data[c]), .b_data_ack(IF_M_IQ_Data_rdy[c]));


if((c==3 && NR>3))// || (c==1 && NR<=3))
begin
//    wire signed [23:0] psout_data_I2;
//   wire signed [23:0] psout_data_Q2;
//   assign rx_I[c] = psout_data_I2 <<< (FPGA_PTT? 2:0);
//   assign rx_Q[c] = psout_data_Q2 <<< (FPGA_PTT? 2:0);

     receiver #(.CICRATE(CICRATE)) receiver_inst (
    //control
    .clock(clock_76p8_mhz),
    .rate(rate),
    .frequency(C122_sync_phase_word[c]),
    .out_strobe(strobe[c]),
    //input
     .in_data(FPGA_PTT ? DACD : adcpipe[c/8]),
//    .in_data((FPGA_PTT & IF_Pure_signal) ? DACD : adcpipe[c/8]),
   //output
  //  .out_data_I(psout_data_I2),
  //  .out_data_Q(psout_data_Q2)
    .out_data_I(rx_I[c]),
    .out_data_Q(rx_Q[c])
    );

    end
else

    receiver #(.CICRATE(CICRATE)) receiver_inst (
    //control
    .clock(clock_76p8_mhz),
    .rate(rate),
    .frequency(C122_sync_phase_word[c]),
    .out_strobe(strobe[c]),
    //input
    .in_data(adcpipe[c/8]),
    //output
    .out_data_I(rx_I[c]),
    .out_data_Q(rx_Q[c])
    );

    cdc_sync #(32)
        freq (.siga(IF_frequency[c+1]), .rstb(C122_rst), .clkb(clock_76p8_mhz), .sigb(C122_frequency_HZ[c])); // transfer Rx1 frequency
end
endgenerate


// calc frequency phase word for Tx
//assign C122_ratio_Tx = C122_frequency_HZ_Tx * M2;
// Note: We add 1/2 M2 (M3) so that we end up with a rounded 32 bit integer below.
//assign C122_ratio_Tx = C122_frequency_HZ_Tx * M2 + M3;

//always @ (posedge clock_76p8_mhz)
//begin
//  if (C122_cbrise)
//  begin
//    C122_last_freq_Tx <= C122_frequency_HZ_Tx;
//   if (C122_last_freq_Tx != C122_frequency_HZ_Tx)
//    C122_sync_phase_word_Tx <= C122_ratio_Tx[56:25];
//  end
//end

assign C122_sync_phase_word_Tx = C122_frequency_HZ_Tx;



//---------------------------------------------------------
//    ADC SPI interface
//---------------------------------------------------------

wire [11:0] AIN1;
wire [11:0] AIN2;
wire [11:0] AIN3;
wire [11:0] AIN4;
wire [11:0] AIN5;  // holds 12 bit ADC value of Forward Power detector.
wire [11:0] AIN6;  // holds 12 bit ADC of 13.8v measurement

//Hermes_ADC ADC_SPI(.clock(C122_cbclk), .SCLK(ADCCLK), .nCS(nADCCS), .MISO(ADCMISO), .MOSI(ADCMOSI),
//                   .AIN1(AIN1), .AIN2(AIN2), .AIN3(AIN3), .AIN4(AIN4), .AIN5(AIN5), .AIN6(AIN6));

assign AIN1 = 0;
assign AIN2 = 0;
assign AIN3 = 0;
assign AIN4 = 0;
assign AIN5 =  200;
assign AIN6 = 1000;



//reg IF_Filter;
//reg IF_Tuner;
//reg IF_autoTune;

//---------------------------------------------------------
//                 Transmitter code
//---------------------------------------------------------

/*
    The gain distribution of the transmitter code is as follows.
    Since the CIC interpolating filters do not interpolate by 2^n they have an overall loss.

    The overall gain in the interpolating filter is ((RM)^N)/R.  So in this case its 2560^4.
    This is normalised by dividing by ceil(log2(2560^4)).

    In which case the normalized gain would be (2560^4)/(2^46) = .6103515625

    The CORDIC has an overall gain of 1.647.

    Since the CORDIC takes 16 bit I & Q inputs but output needs to be truncated to 14 bits, in order to
    interface to the DAC, the gain is reduced by 1/4 to 0.41175

    We need to be able to drive to DAC to its full range in order to maximise the S/N ratio and
    minimise the amount of PA gain.  We can increase the output of the CORDIC by multiplying it by 4.
    This is simply achieved by setting the CORDIC output width to 16 bits and assigning bits [13:0] to the DAC.

    The gain distripution is now:

    0.61 * 0.41174 * 4 = 1.00467

    This means that the DAC output will wrap if a full range 16 bit I/Q signal is received.
    This can be prevented by reducing the output of the CIC filter.

    If we subtract 1/128 of the CIC output from itself the level becomes

    1 - 1/128 = 0.9921875

    Hence the overall gain is now

    0.61 * 0.9921875 * 0.41174 * 4 = 0.996798


*/

reg signed [15:0]C122_fir_i;
reg signed [15:0]C122_fir_q;

// latch I&Q data on strobe from FIR
always @ (posedge clock_76p8_mhz)
begin
    if (req1) begin
        C122_fir_i = C122_I_PWM;
        C122_fir_q = C122_Q_PWM;
    end
end


// Interpolate I/Q samples from 48 kHz to the clock frequency

wire req1, req2;
wire [19:0] y1_r, y1_i;
wire [15:0] y2_r, y2_i;

FirInterp8_1024 fi (clock_76p8_mhz, req2, req1, C122_fir_i, C122_fir_q, y1_r, y1_i);  // req2 enables an output sample, req1 requests next input sample.

// GBITS reduced to 30
CicInterpM5 #(.RRRR(RRRR), .IBITS(20), .OBITS(16), .GBITS(GBITS)) in2 ( clock_76p8_mhz, 1'd1, req2, y1_r, y1_i, y2_r, y2_i);



//---------------------------------------------------------
//    CORDIC NCO
//---------------------------------------------------------

// Code rotates input at set frequency and produces I & Q

wire signed [14:0] C122_cordic_i_out;
wire signed [14:0] C122_cordic_q_out;
wire signed [31:0] C122_phase_word_Tx;

wire signed [15:0] I;
wire signed [15:0] Q;

// if in VNA mode use the Rx[0] phase word for the Tx
assign C122_phase_word_Tx = VNA ? C122_sync_phase_word[0] : C122_sync_phase_word_Tx;
assign                  I = VNA ? 16'd19274 : (cwkey ? {1'b0, C122_cwlevel} : y2_i);    // select VNA mode if active. Set CORDIC for max DAC output
assign                  Q = (VNA | cwkey) ? 0 : y2_r;                   // taking into account CORDICs gain i.e. 0x7FFF/1.7


// NOTE:  I and Q inputs reversed to give correct sideband out

cpl_cordic #(.OUT_WIDTH(16))
        cordic_inst (.clock(clock_76p8_mhz), .frequency(C122_phase_word_Tx), .in_data_I(I),
        .in_data_Q(Q), .out_data_I(C122_cordic_i_out), .out_data_Q(C122_cordic_q_out));

/*
  We can use either the I or Q output from the CORDIC directly to drive the DAC.

    exp(jw) = cos(w) + j sin(w)

  When multplying two complex sinusoids f1 and f2, you get only f1 + f2, no
  difference frequency.

      Z = exp(j*f1) * exp(j*f2) = exp(j*(f1+f2))
        = cos(f1 + f2) + j sin(f1 + f2)
*/

// the CORDIC output is stable on the negative edge of the clock

reg [11:0] DACD;



wire signed [15:0] txsum;
wire signed [15:0] txsumq;

generate
    if (NT == 1) begin: SINGLETX

        //gain of 4
        assign txsum = (C122_cordic_i_out  >>> 2); // + {15'h0000, C122_cordic_i_out[1]};
          assign txsumq = (C122_cordic_q_out  >>> 2);

    end else begin: DUALTX
        wire signed [15:0] C122_cordic_tx2_i_out;
        wire signed [15:0] C122_cordic_tx2_q_out;

        // Hardwire second TX frequency to second RX
        cpl_cordic #(.OUT_WIDTH(16))
            cordic_tx2_inst (.clock(clock_76p8_mhz), .frequency(C122_sync_phase_word[1]), .in_data_I(I),
            .in_data_Q(Q), .out_data_I(C122_cordic_tx2_i_out), .out_data_Q(C122_cordic_tx2_q_out));

        assign txsum = (C122_cordic_i_out + C122_cordic_tx2_i_out) >>> 3;
        assign txsumq = (C122_cordic_q_out + C122_cordic_tx2_q_out) >>> 3;

    end
endgenerate



// LFSR for dither
//reg [15:0] lfsr = 16'h0001;
//always @ (negedge clock_76p8_mhz or negedge extreset)
//    if (~extreset) lfsr <= 16'h0001;
//    else lfsr <= {lfsr[0],lfsr[15],lfsr[14] ^ lfsr[0], lfsr[13] ^ lfsr[0], lfsr[12], lfsr[11] ^ lfsr[0], lfsr[10:1]};



// apply amplitude & phase linearity correction

/*
Lookup tables
These are sent continuously in the unused audio out packets sent to the radio.
The left channel is an index into the table and the right channel has the value.
Indexes 0-4097 go into DACLUTI and 4096-8191 go to DACLUTQ.
The values are sent as signed 16bit numbers but the value is never bigger than 13 bits.

DACLUTI has the out of phase distortion and DACLUTQ has the in phase distortion.

The tables can represent arbitary functions, for now my console software just uses a power series

DACLUTI[x] = 0x + gain2*sin(phase2)*x^2 +  gain3*sin(phase3)*x^3 + gain4*sin(phase4)*x^4 + gain5*sin(phase5)*x^5
DACLUTQ[x] = 1x + gain2*cos(phase2)*x^2 +  gain3*cos(phase3)*x^3 + gain4*cos(phase4)*x^4 + gain5*cos(phase5)*x^5

The table indexes are signed so the tables are in 2's complement order ie. 0,1,2...2047,-2048,-2047...-1.

The table values are scaled to keep the output of DACLUTI[I]-DACLUTI[Q]+DACLUTQ[(I+Q)/root2] to fit in 12 bits,
the intermediate values and table values can be larger.
Zero input produces centre of the dac range output(signed 0) so with some settings one end or the other of the dac range is not used.

The predistortion is turned on and off by a new command and control packet this follows the last of the 32 receiver frequencies.
There is a sub index so this can be used for many other things.
control cc packet

c0 101011x
c1 sub index 0 for predistortion control-
c2 mode 0 off 1 on, (higher numbers can be used to experiment without so much fpga recompilation).

*/

generate
if (PREDISTORT == 1) begin: PD1

// lookup tables for dac phase and amplitude linearity correction
reg signed [12:0] DACLUTI[4096];
reg signed [12:0] DACLUTQ[4096];

wire signed [15:0] distorted_dac;

wire signed [15:0] iplusq;
wire signed [15:0] iplusq_over_root2;

reg signed [15:0] txsumr;
reg signed [15:0] txsumqr;
reg signed [15:0] iplusqr;

assign iplusq = txsum+txsumq;

always @ (posedge clock_76p8_mhz)
begin
    txsumr<=txsum;
    txsumqr<=txsumq;
    iplusqr<=iplusq;
end
//approximation to dividing by root 2 to reduce lut size, the error can be corrected in the lut data
assign iplusq_over_root2 = iplusqr+(iplusqr>>>2)+(iplusqr>>>3)+(iplusqr>>>5);

reg signed [15:0] txsumr2;
reg signed [15:0] txsumqr2;
reg signed [15:0] iplusq_over_root2r;


always @ (posedge clock_76p8_mhz)
begin
    txsumr2<=txsumr;
    txsumqr2<=txsumqr;
    iplusq_over_root2r<=iplusq_over_root2;
end
    assign distorted_dac = DACLUTI[txsumr2[11:0]]-DACLUTI[txsumqr2[11:0]]+DACLUTQ[iplusq_over_root2r[12:1]];

always @ (posedge clock_76p8_mhz)
case( IF_Predistortion[1:0] )
    0: DACD <= txsum[11:0];
    1: DACD <= distorted_dac[11:0];
    //other modes
    default: DACD <= txsum[11:0];
endcase

end else

always @ (posedge clock_76p8_mhz)
    DACD <= txsum[11:0]; // + {10'h0,lfsr[2:1]};

endgenerate



wire txclipp = (C122_cordic_i_out[13:2] == 12'b011111111111);
wire txclipn = (C122_cordic_i_out[13:2] == 12'b100000000000);

wire txgoodlvlp = (C122_cordic_i_out[13:11] == 3'b011);
wire txgoodlvln = (C122_cordic_i_out[13:11] == 3'b100);


//------------------------------------------------------------
//  Set Power Output
//------------------------------------------------------------

// PWM DAC to set drive current to DAC. PWM_count increments
// using IF_clk. If the count is less than the drive
// level set by the PC then DAC_ALC will be high, otherwise low.

//reg [7:0] PWM_count;
//always @ (posedge clock_76p8_mhz)
//begin
//  PWM_count <= PWM_count + 1'b1;
//  if (IF_Drive_Level >= PWM_count)
//      DAC_ALC <= 1'b1;
//  else
//      DAC_ALC <= 1'b0;
//end


//---------------------------------------------------------
//  Receive DOUT and CDOUT data to put in TX FIFO
//---------------------------------------------------------

wire   [15:0] IF_P_mic_Data;
wire          IF_P_mic_Data_rdy;
wire   [47:0] IF_M_IQ_Data [0:NR-1];
wire [NR-1:0] IF_M_IQ_Data_rdy;
wire   [63:0] IF_tx_IQ_mic_data;
reg           IF_tx_IQ_mic_rdy;
wire   [15:0] IF_mic_Data;
wire    [4:0] IF_chan;
wire    [4:0] IF_last_chan;
wire     [47:0] IF_chan_test;

always @*
begin
  if (rst)
    IF_tx_IQ_mic_rdy = 1'b0;
  else
      IF_tx_IQ_mic_rdy = IF_M_IQ_Data_rdy[0];   // this the strobe signal from the ADC now in IF clock domain
end

assign IF_IQ_Data = IF_M_IQ_Data[IF_chan];

// concatenate the IQ and Mic data to form a 64 bit data word
assign IF_tx_IQ_mic_data = {IF_IQ_Data, IF_mic_Data};

//----------------------------------------------------------------------------
//     Tx_fifo Control - creates IF_tx_fifo_wdata and IF_tx_fifo_wreq signals
//----------------------------------------------------------------------------

localparam RFSZ = clogb2(RX_FIFO_SZ-1);  // number of bits needed to hold 0 - (RX_FIFO_SZ-1)
localparam TFSZ = clogb2(TX_FIFO_SZ-1);  // number of bits needed to hold 0 - (TX_FIFO_SZ-1)
localparam SFSZ = clogb2(SP_FIFO_SZ-1);  // number of bits needed to hold 0 - (SP_FIFO_SZ-1)

wire     [15:0] IF_tx_fifo_wdata;           // LTC2208 ADC uses this to send its data to Tx FIFO
wire            IF_tx_fifo_wreq;            // set when we want to send data to the Tx FIFO
wire            IF_tx_fifo_full;
wire [TFSZ-1:0] IF_tx_fifo_used;
wire            IF_tx_fifo_rreq;
wire            IF_tx_fifo_empty;

wire [RFSZ-1:0] IF_Rx_fifo_used;            // read side count
wire            IF_Rx_fifo_full;

wire            clean_dash;                 // debounced dash key
wire            clean_dot;                  // debounced dot key

wire     [11:0] Penny_ALC;

wire   [RFSZ:0] RX_USED;
wire            IF_tx_fifo_clr;

assign RX_USED = {IF_Rx_fifo_full,IF_Rx_fifo_used};


assign Penny_ALC = AIN5;

wire VNA_start = VNA && IF_Rx_save && (IF_Rx_ctrl_0[7:1] == 7'b0000_001);  // indicates a frequency change for the VNA.


wire IO4;
wire IO5;
wire IO6;
wire IO8;
wire OVERFLOW;
assign IO4 = 1'b1;
assign IO5 = 1'b1;
assign IO6 = 1'b1;
assign IO8 = 1'b1;

//allow overflow message during tx to set pure signal feedback level
assign OVERFLOW = (~leds[0] | ~leds[3]) ;


Hermes_Tx_fifo_ctrl #(RX_FIFO_SZ, TX_FIFO_SZ) TXFC
           (rst, IF_clk, IF_tx_fifo_wdata, IF_tx_fifo_wreq, IF_tx_fifo_full,
            IF_tx_fifo_used, IF_tx_fifo_clr, IF_tx_IQ_mic_rdy,
            IF_tx_IQ_mic_data, IF_chan, IF_last_chan, clean_dash, clean_dot, (cwkey | clean_ptt), OVERFLOW,
            Penny_serialno, Merc_serialno, Hermes_serialno, Penny_ALC, AIN1, AIN2,
            AIN3, AIN4, AIN6, IO4, IO5, IO6, IO8, VNA_start, VNA);

//------------------------------------------------------------------------
//   Tx_fifo  (1024 words) Dual clock FIFO - Altera Megafunction (dcfifo)
//------------------------------------------------------------------------

/*
        Data from the Tx FIFO Controller  is written to the FIFO using IF_tx_fifo_wreq.
        FIFO is 1024 WORDS long.
        NB: The output flags are only valid after a read/write clock has taken place


                            --------------------
    IF_tx_fifo_wdata    |data[15:0]      wrful| IF_tx_fifo_full
                           |                         |
    IF_tx_fifo_wreq |wreq            wrempty| IF_tx_fifo_empty
                           |                       |
        IF_clk          |>wrclk  wrused[9:0]| IF_tx_fifo_used
                           ---------------------
    Tx_fifo_rdreq       |rdreq         q[7:0]| PHY_Tx_data
                           |                          |
       clock_125_mhz_0_deg       |>rdclk       rdempty|
                           |          rdusedw[10:0]| PHY_Tx_rdused  (0 to 2047 bytes)
                           ---------------------
                           |                    |
 IF_tx_fifo_clr OR      |aclr                |
    rst              ---------------------



*/

Tx_fifo Tx_fifo_inst(.wrclk (IF_clk),.rdreq (Tx_fifo_rdreq),.rdclk (clock_125_mhz_0_deg),.wrreq (IF_tx_fifo_wreq),
                .data ({IF_tx_fifo_wdata[7:0], IF_tx_fifo_wdata[15:8]}),.q (PHY_Tx_data),.wrusedw(IF_tx_fifo_used), .wrfull(IF_tx_fifo_full),
                .rdempty(),.rdusedw(PHY_Tx_rdused),.wrempty(IF_tx_fifo_empty),.aclr(rst || IF_tx_fifo_clr ));

wire [7:0] PHY_Tx_data;
reg [3:0]sync_TD;
wire PHY_Tx_rdempty;



//---------------------------------------------------------
//   Rx_fifo  (2048 words) single clock FIFO
//---------------------------------------------------------

wire [15:0] IF_Rx_fifo_rdata;
reg         IF_Rx_fifo_rreq;    // controls reading of fifo
wire [15:0] IF_PHY_data;

wire [15:0] IF_Rx_fifo_wdata;
reg         IF_Rx_fifo_wreq;

FIFO #(RX_FIFO_SZ) RXF (.rst(rst), .clk (IF_clk), .full(IF_Rx_fifo_full), .usedw(IF_Rx_fifo_used),
          .wrreq (IF_Rx_fifo_wreq), .data (IF_PHY_data),
          .rdreq (IF_Rx_fifo_rreq), .q (IF_Rx_fifo_rdata) );


//------------------------------------------------------------
//   Sync and  C&C  Detector
//------------------------------------------------------------

/*

  Read the value of IF_PHY_data whenever IF_PHY_drdy is set.
  Look for sync and if found decode the C&C data.
  Then send subsequent data to Rx FIF0 until end of frame.

*/

reg   [2:0] IF_SYNC_state;
reg   [2:0] IF_SYNC_state_next;
reg   [7:0] IF_SYNC_frame_cnt;  // 256-4 words = 252 words
reg   [7:0] IF_Rx_ctrl_0;           // control C0 from PC
reg   [7:0] IF_Rx_ctrl_1;           // control C1 from PC
reg   [7:0] IF_Rx_ctrl_2;           // control C2 from PC
reg   [7:0] IF_Rx_ctrl_3;           // control C3 from PC
reg   [7:0] IF_Rx_ctrl_4;           // control C4 from PC
reg         IF_Rx_save;


localparam SYNC_IDLE   = 1'd0,
           SYNC_START  = 1'd1,
           SYNC_RX_1_2 = 2'd2,
           SYNC_RX_3_4 = 2'd3,
           SYNC_FINISH = 3'd4;

always @ (posedge IF_clk)
begin
  if (rst)
    IF_SYNC_state <= #IF_TPD SYNC_IDLE;
  else
    IF_SYNC_state <= #IF_TPD IF_SYNC_state_next;

  if (rst)
    IF_Rx_save <= #IF_TPD 1'b0;
  else
    IF_Rx_save <= #IF_TPD IF_PHY_drdy && (IF_SYNC_state == SYNC_RX_3_4);

  if (IF_PHY_drdy && (IF_SYNC_state == SYNC_START) && (IF_PHY_data[15:8] == 8'h7F))
    IF_Rx_ctrl_0  <= #IF_TPD IF_PHY_data[7:0];

  if (IF_PHY_drdy && (IF_SYNC_state == SYNC_RX_1_2))
  begin
    IF_Rx_ctrl_1  <= #IF_TPD IF_PHY_data[15:8];
    IF_Rx_ctrl_2  <= #IF_TPD IF_PHY_data[7:0];
  end

  if (IF_PHY_drdy && (IF_SYNC_state == SYNC_RX_3_4))
  begin
    IF_Rx_ctrl_3  <= #IF_TPD IF_PHY_data[15:8];
    IF_Rx_ctrl_4  <= #IF_TPD IF_PHY_data[7:0];
  end

  if (IF_SYNC_state == SYNC_START)
    IF_SYNC_frame_cnt <= 0;                                         // reset sync counter
  else if (IF_PHY_drdy && (IF_SYNC_state == SYNC_FINISH))
    IF_SYNC_frame_cnt <= IF_SYNC_frame_cnt + 1'b1;          // increment if we have data to store
end

always @*
begin
  case (IF_SYNC_state)
    // state SYNC_IDLE  - loop until we find start of sync sequence
    SYNC_IDLE:
    begin
      IF_Rx_fifo_wreq  = 1'b0;             // Note: Sync bytes not saved in Rx_fifo

      if (rst || !IF_PHY_drdy)
        IF_SYNC_state_next = SYNC_IDLE;    // wait till we get data from PC
      else if (IF_PHY_data == 16'h7F7F)
        IF_SYNC_state_next = SYNC_START;   // possible start of sync
      else
        IF_SYNC_state_next = SYNC_IDLE;
    end

    // check for 0x7F  sync character & get Rx control_0
    SYNC_START:
    begin
      IF_Rx_fifo_wreq  = 1'b0;             // Note: Sync bytes not saved in Rx_fifo

      if (!IF_PHY_drdy)
        IF_SYNC_state_next = SYNC_START;   // wait till we get data from PC
      else if (IF_PHY_data[15:8] == 8'h7F)
        IF_SYNC_state_next = SYNC_RX_1_2;  // have sync so continue
      else
        IF_SYNC_state_next = SYNC_IDLE;    // start searching for sync sequence again
    end


    SYNC_RX_1_2:                             // save Rx control 1 & 2
    begin
      IF_Rx_fifo_wreq  = 1'b0;             // Note: Rx control 1 & 2 not saved in Rx_fifo

      if (!IF_PHY_drdy)
        IF_SYNC_state_next = SYNC_RX_1_2;  // wait till we get data from PC
      else
        IF_SYNC_state_next = SYNC_RX_3_4;
    end

    SYNC_RX_3_4:                             // save Rx control 3 & 4
    begin
      IF_Rx_fifo_wreq  = 1'b0;             // Note: Rx control 3 & 4 not saved in Rx_fifo

      if (!IF_PHY_drdy)
        IF_SYNC_state_next = SYNC_RX_3_4;  // wait till we get data from PC
      else
        IF_SYNC_state_next = SYNC_FINISH;
    end

    // Remainder of data goes to Rx_fifo, re-start looking
    // for a new SYNC at end of this frame.
    // Note: due to the use of IF_PHY_drdy data will only be written to the
    // Rx fifo if there is room. Also the frame_count will only be incremented if IF_PHY_drdy is true.
    SYNC_FINISH:
    begin
      IF_Rx_fifo_wreq  = IF_PHY_drdy;
      if (IF_PHY_drdy & (IF_SYNC_frame_cnt == ((512-8)/2)-1)) begin  // frame ended, go get sync again
        IF_SYNC_state_next = SYNC_IDLE;
      end
      else IF_SYNC_state_next = SYNC_FINISH;
    end

    default:
    begin
      IF_Rx_fifo_wreq  = 1'b0;
      IF_SYNC_state_next = SYNC_IDLE;
    end
    endcase
end

wire have_room;
assign have_room = (IF_Rx_fifo_used < RX_FIFO_SZ - ((512-8)/2)) ? 1'b1 : 1'b0;  // the /2 is because we send 16 bit values

// prevent read from PHY fifo if empty and writing to Rx fifo if not enough room
assign  IF_PHY_drdy = have_room & ~IF_PHY_rdempty;



//---------------------------------------------------------
//              Decode Command & Control data
//---------------------------------------------------------

/*
    Decode IF_Rx_ctrl_0....IF_Rx_ctrl_4.

    Decode frequency (both Tx and Rx if full duplex selected), PTT, Speed etc

    The current frequency is set by the PC by decoding
    IF_Rx_ctrl_1... IF_Rx_ctrl_4 when IF_Rx_ctrl_0[7:1] = 7'b0000_001

      The Rx Sampling Rate, either 192k, 96k or 48k is set by
      the PC by decoding IF_Rx_ctrl_1 when IF_Rx_ctrl_0[7:1] are all zero. IF_Rx_ctrl_1
      decodes as follows:

      IF_Rx_ctrl_1 = 8'bxxxx_xx00  - 48kHz
      IF_Rx_ctrl_1 = 8'bxxxx_xx01  - 96kHz
      IF_Rx_ctrl_1 = 8'bxxxx_xx10  - 192kHz

    Decode PTT from PC. Held in IF_Rx_ctrl_0[0] as follows

    0 = PTT inactive
    1 = PTT active

    Decode Attenuator settings on Alex, when IF_Rx_ctrl_0[7:1] = 0, IF_Rx_ctrl_3[1:0] indicates the following

    00 = 0dB
    01 = 10dB
    10 = 20dB
    11 = 30dB

    Decode ADC & Attenuator settings on Hermes, when IF_Rx_ctrl_0[7:1] = 0, IF_Rx_ctrl_3[4:2] indicates the following

    000 = Random, Dither, Preamp OFF
    1xx = Random ON
    x1x = Dither ON
    xx1 = Preamp ON **** replace with attenuator

    Decode Rx relay settings on Alex, when IF_Rx_ctrl_0[7:1] = 0, IF_Rx_ctrl_3[6:5] indicates the following

    00 = None
    01 = Rx 1
    10 = Rx 2
    11 = Transverter

    Decode Tx relay settigs on Alex, when IF_Rx_ctrl_0[7:1] = 0, IF_Rx_ctrl_4[1:0] indicates the following

    00 = Tx 1
    01 = Tx 2
    10 = Tx 3

    Decode Rx_1_out relay settigs on Alex, when IF_Rx_ctrl_0[7:1] = 0, IF_Rx_ctrl_3[7] indicates the following

    1 = Rx_1_out on

    When IF_Rx_ctrl_0[7:1] == 7'b0001_010 decodes as follows:

    IF_Line_In_Gain     <= IF_Rx_ctrl2[4:0] // decode 5-bit line gain setting

*/

reg   [6:0] IF_OC;                  // open collectors on Hermes
reg         IF_RAND;                // when set randomizer in ADCon
reg         IF_DITHER;              // when set dither in ADC on
reg         Preamp;                 // selects input attenuator setting, 0 = 20dB, 1 = 0dB (preamp ON)
reg  [31:0] IF_frequency[0:NR];     // Tx, Rx1, Rx2, Rx3
reg         IF_duplex;
reg         IF_DFS1;
reg         IF_DFS0;
reg   [7:0] IF_Drive_Level;         // Tx drive level
reg         VNA;                    // Selects VNA mode when set.
reg   [4:0] Hermes_atten;           // 0-31 dB Heremes attenuator value
reg         IF_Pure_signal;              
reg   [3:0] IF_Predistortion;             
reg         IF_PA_enable;
reg         IF_TR_disable;
reg   [7:0] bias0;
reg   [7:0] bias1;

always @ (posedge IF_clk)
begin
  if (rst)
  begin // set up default values - 0 for now
    // RX_CONTROL_1
    IF_DFS1 <= 1'b0; // decode speed
    IF_DFS0 <= 1'b0;
    // RX_CONTROL_2
    IF_OC              <= 7'b0;     // decode open collectors on Hermes
    // RX_CONTROL_3
    Preamp             <= 1'b1;     // decode Preamp (Attenuator), default on
    IF_DITHER          <= 1'b1;     // decode dither on or off
    IF_RAND            <= 1'b0;     // decode randomizer on or off
    // RX_CONTROL_4
    IF_duplex          <= 1'b0;     // not in duplex mode
    IF_last_chan       <= 5'b00000;    // default single receiver
    IF_Drive_Level     <= 8'b0;    // drive at minimum
    VNA                <= 1'b0;      // VNA disabled
    Hermes_atten       <= 5'b0;     // default zero input attenuation
    IF_Pure_signal     <= 1'b0;      // default disable pure signal
    IF_Predistortion   <= 4'b0000;   // default disable predistortion
    IF_PA_enable       <= 1'b0;
    IF_TR_disable      <= 1'b0;
    bias0              <= 8'hff;
    bias1              <= 8'hff;
  end
  else if (IF_Rx_save)                  // all Rx_control bytes are ready to be saved
  begin                                         // Need to ensure that C&C data is stable
    if (IF_Rx_ctrl_0[7:1] == 7'b0000_000)
    begin
      // RX_CONTROL_1
      IF_DFS1  <= IF_Rx_ctrl_1[1]; // decode speed
      IF_DFS0  <= IF_Rx_ctrl_1[0]; // decode speed
      // RX_CONTROL_2
      IF_OC               <= IF_Rx_ctrl_2[7:1]; // decode open collectors on Penelope
      // RX_CONTROL_3
      Preamp              <= IF_Rx_ctrl_3[2];  // decode Preamp (Attenuator)  1 = On (0dB atten), 0 = Off (20dB atten)
      IF_DITHER           <= IF_Rx_ctrl_3[3];   // decode dither on or off
      IF_RAND             <= IF_Rx_ctrl_3[4];   // decode randomizer on or off
      // RX_CONTROL_4
      IF_duplex           <= IF_Rx_ctrl_4[2];   // save duplex mode
      IF_last_chan        <= IF_Rx_ctrl_4[7:3]; // number of IQ streams to send to PC
    end
    if (IF_Rx_ctrl_0[7:1] == 7'b0001_001)
    begin
      IF_Drive_Level      <= IF_Rx_ctrl_1;         // decode drive level
      VNA                 <= IF_Rx_ctrl_2[7];      // 1 = enable VNA mode
    end
    if (IF_Rx_ctrl_0[7:1] == 7'b0001_010)
    begin
      IF_Pure_signal    <= IF_Rx_ctrl_2[6];       // decode pure signal setting
      Hermes_atten      <= IF_Rx_ctrl_4[4:0];    // decode input attenuation setting
    end
    if (IF_Rx_ctrl_0[7:1] == 7'b0001_100)
    begin
      IF_PA_enable <= IF_Rx_ctrl_4[7];
      IF_TR_disable <= IF_Rx_ctrl_4[6];
      bias0 <= IF_Rx_ctrl_1;
      bias1 <= IF_Rx_ctrl_2;
    end
    if (IF_Rx_ctrl_0[7:1] == 7'b0101_011)
    begin
     // DACLUT[{IF_Rx_ctrl_1[3:0], IF_Rx_ctrl_2[7:0]}]<= {IF_Rx_ctrl_3[3:0], IF_Rx_ctrl_4[7:0]};
      if(IF_Rx_ctrl_1==8'b0000_0000)//predistortion control sub index
      begin
      IF_Predistortion <= IF_Rx_ctrl_2[3:0];
      end
     end
  end
end

// Always compute frequency
// This really should be done on the PC....
wire [63:0] freqcomp;
assign freqcomp = {IF_Rx_ctrl_1, IF_Rx_ctrl_2, IF_Rx_ctrl_3, IF_Rx_ctrl_4} * M2 + M3;

// Pipeline freqcomp
reg [31:0] freqcompp [0:3];
reg IF_Rx_savep;
reg [6:0] chanp [0:3];

always @ (posedge IF_clk) begin
    if (IF_Rx_save) begin
        freqcompp[0] <= freqcomp[56:25];
        freqcompp[1] <= freqcomp[56:25];
        freqcompp[2] <= freqcomp[56:25];
        freqcompp[3] <= freqcomp[56:25];
        chanp[0] <= IF_Rx_ctrl_0[7:1];
        chanp[1] <= IF_Rx_ctrl_0[7:1];
        chanp[2] <= IF_Rx_ctrl_0[7:1];
        chanp[3] <= IF_Rx_ctrl_0[7:1];
    end
end

always @ (posedge IF_clk) begin
    if (rst)
        IF_Rx_savep <= 1'b0;
    else
        IF_Rx_savep <= IF_Rx_save;
end


always @ (posedge IF_clk)
begin
  if (rst)
  begin // set up default values - 0 for now
    IF_frequency[0] <= 32'd0;
    IF_frequency[1] <= 32'd0;
  end
  else if (IF_Rx_savep)
  begin
    if (chanp[0] == 7'b0000_001) begin // decode IF_frequency[0]
        IF_frequency[0]   <= freqcompp[0]; //freqcomp[56:25];
        if (!IF_duplex && (IF_last_chan == 5'b00000)) IF_frequency[1] <= IF_frequency[0];
    end

    if (chanp[0] == 7'b0000_010) begin // decode Rx1 frequency
        if (!IF_duplex && (IF_last_chan == 5'b00000)) IF_frequency[1] <= IF_frequency[0];
        else IF_frequency[1] <= freqcompp[0]; //freqcomp[56:25];
    end
  end
end


generate
  for (c = 1; c < NR; c = c + 1) begin: RXIFFREQ
    always @ (posedge IF_clk) begin
        if (rst) IF_frequency[c+1] <= 32'd0;
        else if (IF_Rx_savep) begin
            if (chanp[c/8] == ((c < 7) ? c+2 : c+11)) begin
              //if (IF_last_chan >= c)
                IF_frequency[c+1] <= freqcompp[c/8]; //freqcomp[56:25];
              //else IF_frequency[c+1] <= IF_frequency[0];
            end
        end
    end
  end
endgenerate


assign FPGA_PTT = IF_Rx_ctrl_0[0] | cwkey | clean_ptt; // IF_Rx_ctrl_0 only updated when we get correct sync sequence


//------------------------------------------------------------
//  Attenuator
//------------------------------------------------------------

// set the attenuator according to whether Hermes_atten_enable and Preamp bits are set
//wire [4:0] atten_data;


// Hack to use IF_DITHER to switch highest bit of attenuation
wire [5:0] gain_value;
reg [5:0] ad9866_pga_d;

assign gain_value = {~IF_DITHER, ~Hermes_atten};

wire [5:0] igain_value;
assign igain_value = IF_RAND ? agc_value : gain_value;


always @(posedge clock_76p8_mhz) begin
//assign ad9866_pga = (FPGA_PTT | VNA) ? ((VNA & Preamp) ? DUPRXMAXGAIN : DUPRXMINGAIN) : (IF_RAND ? agc_value : gain_value);
//allow gain changes during tx
//AD9866 appears to diminish TX if RX gain is more than 1f, ceiling of 1f for receiver if in TX
  ad9866_pga_d <= VNA ? (Preamp ? DUPRXMAXGAIN : DUPRXMINGAIN) : ((FPGA_PTT & igain_value[5]) ? 6'h1f : igain_value);


end

assign rffe_ad9866_pga = ad9866_pga_d;


//---------------------------------------------------------
//   State Machine to manage PWM interface
//---------------------------------------------------------
/*

    The code loops until there are at least 4 words in the Rx_FIFO.

    The first word is the Left audio followed by the Right audio
    which is followed by I data and finally the Q data.

    The words sent to the D/A converters must be sent at the sample rate
    of the A/D converters (48kHz) so is synced to the negative edge of the CLRCLK (via IF_get_rx_data).
*/

reg   [2:0] IF_PWM_state;      // state for PWM
reg   [2:0] IF_PWM_state_next; // next state for PWM
reg  [15:0] IF_Left_Data;      // Left 16 bit PWM data for D/A converter
//reg  [15:0] IF_Right_Data;     // Right 16 bit PWM data for D/A converter
reg  [15:0] IF_I_PWM;          // I 16 bit PWM data for D/A conveter
reg  [15:0] IF_Q_PWM;          // Q 16 bit PWM data for D/A conveter
wire        IF_get_samples;
wire        IF_get_rx_data;

assign IF_get_rx_data = IF_get_samples;

localparam PWM_IDLE     = 0,
           PWM_START    = 1,
           PWM_LEFT     = 2,
           PWM_RIGHT    = 3,
           PWM_I_AUDIO  = 4,
           PWM_Q_AUDIO  = 5;


generate

if(PREDISTORT==1) begin: PD2

always @ (posedge IF_clk)
begin
  if (rst)
    IF_PWM_state   <= #IF_TPD PWM_IDLE;
  else
    IF_PWM_state   <= #IF_TPD IF_PWM_state_next;

  // get Left audio
  if (IF_PWM_state == PWM_LEFT)
    IF_Left_Data   <= #IF_TPD IF_Rx_fifo_rdata;

  // get Right audio
  if (IF_PWM_state == PWM_RIGHT)
  begin
    //IF_Right_Data  <= #IF_TPD IF_Rx_fifo_rdata;

     if(IF_Left_Data[12] )
        PD1.DACLUTQ[IF_Left_Data[11:0]]<= IF_Rx_fifo_rdata[12:0];
    else
        PD1.DACLUTI[IF_Left_Data[11:0]]<= IF_Rx_fifo_rdata[12:0];

    end

  // get I audio
  if (IF_PWM_state == PWM_I_AUDIO)
    IF_I_PWM       <= #IF_TPD IF_Rx_fifo_rdata;

  // get Q audio
  if (IF_PWM_state == PWM_Q_AUDIO)
    IF_Q_PWM       <= #IF_TPD IF_Rx_fifo_rdata;

end


end else begin


always @ (posedge IF_clk)
begin
  if (rst)
    IF_PWM_state   <= #IF_TPD PWM_IDLE;
  else
    IF_PWM_state   <= #IF_TPD IF_PWM_state_next;

  // get I audio
  if (IF_PWM_state == PWM_I_AUDIO)
    IF_I_PWM       <= #IF_TPD IF_Rx_fifo_rdata;

  // get Q audio
  if (IF_PWM_state == PWM_Q_AUDIO)
    IF_Q_PWM       <= #IF_TPD IF_Rx_fifo_rdata;

end

end

endgenerate




always @*
begin
  case (IF_PWM_state)
    PWM_IDLE:
    begin
      IF_Rx_fifo_rreq = 1'b0;

      if (!IF_get_rx_data  || RX_USED[RFSZ:2] == 1'b0 ) // RX_USED < 4
        IF_PWM_state_next = PWM_IDLE;    // wait until time to get the donuts every 48kHz from oven (RX_FIFO)
      else
        IF_PWM_state_next = PWM_START;   // ah! now it's time to get the donuts
    end

    // Start packaging the donuts
    PWM_START:
    begin
      IF_Rx_fifo_rreq    = 1'b1;
      IF_PWM_state_next  = PWM_LEFT;
    end

    // get Left audio
    PWM_LEFT:
    begin
      IF_Rx_fifo_rreq    = 1'b1;
      IF_PWM_state_next  = PWM_RIGHT;
    end

    // get Right audio
    PWM_RIGHT:
    begin
      IF_Rx_fifo_rreq    = 1'b1;
      IF_PWM_state_next  = PWM_I_AUDIO;
    end

    // get I audio
   PWM_I_AUDIO:
    begin
      IF_Rx_fifo_rreq    = 1'b1;
      IF_PWM_state_next  = PWM_Q_AUDIO;
    end

    // get Q audio
    PWM_Q_AUDIO:
    begin
      IF_Rx_fifo_rreq    = 1'b0;
      IF_PWM_state_next  = PWM_IDLE; // truck has left the shipping dock
    end

   default:
    begin
      IF_Rx_fifo_rreq    = 1'b0;
      IF_PWM_state_next  = PWM_IDLE;
    end
  endcase
end

//---------------------------------------------------------
//  Debounce CWKEY input - active low
//---------------------------------------------------------

// 3 ms rise and fall, not shaped, but like HiQSDR
// MAX CWLEVEL is picked to be 8*max cordic level for transmit
// ADJUST if cordic max changes...
localparam MAX_CWLEVEL = 18'h25a50;
wire clean_cwkey;
wire cwkey;
reg [17:0] cwlevel;
reg [1:0] cwstate;
localparam  cwrx = 2'b00, cwkeydown = 2'b01, cwkeyup = 2'b11;

// 5 ms debounce with 48 MHz clock
debounce de_cwkey(.clean_pb(clean_cwkey), .pb(~cwkey_i), .clk(IF_clk));

// CW state machine
always @(posedge IF_clk)
    begin case (cwstate)
        cwrx:
            begin
                cwlevel <= 18'h00;
                if (clean_cwkey) cwstate <= cwkeydown;
                else cwstate <= cwrx;
            end

        cwkeydown:
            begin
                if (cwlevel != MAX_CWLEVEL) cwlevel <= cwlevel + 18'h01;
                if (clean_cwkey) cwstate <= cwkeydown;
                else cwstate <= cwkeyup;
            end

        cwkeyup:
            begin
                if (cwlevel == 18'h00) cwstate <= cwrx;
                else begin
                    cwstate <= cwkeyup;
                    cwlevel <= cwlevel - 18'h01;
                end
            end
    endcase
    end

assign cwkey = cwstate != cwrx;

wire [14:0] C122_cwlevel;
cdc_sync #(15)
    CWLVL  (.siga(cwlevel[17:3]), .rstb(C122_rst), .clkb(clock_76p8_mhz), .sigb(C122_cwlevel)); // To Tx domain


//---------------------------------------------------------
//  Debounce dot key - active low
//---------------------------------------------------------

//debounce de_dot(.clean_pb(clean_dot), .pb(~KEY_DOT), .clk(IF_clk));
assign clean_dot = 0;

//---------------------------------------------------------
//  Debounce dash key - active low
//---------------------------------------------------------

//debounce de_dash(.clean_pb(clean_dash), .pb(~KEY_DASH), .clk(IF_clk));
assign clean_dash = 0;



// 5 ms debounce with 48 MHz clock
wire clean_ptt;
debounce de_ptt(.clean_pb(clean_ptt), .pb(~ptt_i), .clk(IF_clk));



// AD9866 Instance
wire ad9866rqst;
wire [5:0] dd;

// Linear mapping from 0to255 to 0to39
generate
  if (disable_IAMP == 1) assign dd = VNA ? VNATXGAIN : {2'b00,IF_Drive_Level[7:4]};
  else assign dd = VNA ? VNATXGAIN : ((IF_Drive_Level+4) >> 3) + (IF_Drive_Level >> 5);
endgenerate


reg [5:0] lastdd;
always @ (posedge ad9866spiclk)
    lastdd <= dd;

assign ad9866rqst = dd != lastdd;

ad9866 #(.initarray0(initarray0), .initarray1(initarray1)) ad9866_inst(.reset(~ad9866_rst_n),
  .clk(ad9866spiclk),.initarray_sel(1'b0),
  .sclk(rffe_ad9866_sclk),.sdio(rffe_ad9866_sdio),.sdo(1'b0),.sen_n(rffe_ad9866_sen_n),.dataout(),.extrqst(ad9866rqst),.gain(dd));


// Really 0.16 seconds at Hermes-Lite 61.44 MHz clock
localparam half_second = 10000000; // at 48MHz clock rate

Led_flash Flash_LED0(.clock(clock_76p8_mhz), .signal(rxclipp), .LED(leds[0]), .period(half_second));
Led_flash Flash_LED1(.clock(clock_76p8_mhz), .signal(rxgoodlvlp), .LED(leds[1]), .period(half_second));
Led_flash Flash_LED2(.clock(clock_76p8_mhz), .signal(rxgoodlvln), .LED(leds[2]), .period(half_second));
Led_flash Flash_LED3(.clock(clock_76p8_mhz), .signal(rxclipn), .LED(leds[3]), .period(half_second));

Led_flash Flash_LED4(.clock(IF_clk), .signal(this_MAC), .LED(leds[4]), .period(half_second));
Led_flash Flash_LED5(.clock(IF_clk), .signal(run), .LED(leds[5]), .period(half_second));
Led_flash Flash_LED6(.clock(IF_clk), .signal(IF_SYNC_state == SYNC_RX_1_2), .LED(leds[6]), .period(half_second));

assign leds[7] = agc_delaycnt[25];


assign io_led_d2 = leds[4];
assign io_led_d3 = leds[5];
assign io_led_d4 = leds[0];
assign io_led_d5 = leds[3];




// FIXME: Sequence power
// FIXME: External TR won't work in low power mode
assign pa_tr = FPGA_PTT & (IF_PA_enable | ~IF_TR_disable);
assign pa_en = FPGA_PTT & IF_PA_enable;
assign rffe_rfsw_sel = IF_PA_enable;




// I2C for Versa Clock
wire [6:0]  cmd_address;
wire        cmd_start, cmd_read, cmd_write, cmd_write_multiple, cmd_stop, cmd_valid, cmd_ready;
wire [7:0]  data;
wire        data_valid, data_ready, data_last;
wire        scl_i, scl_o, scl_t, sda_i, sda_o, sda_t;

assign scl_i = clk_scl1;
assign clk_scl1 = scl_t ? 1'bz : scl_o;
assign sda_i = clk_sda1;
assign clk_sda1 = sda_t ? 1'bz : sda_o;

i2c_init i2c_init_i (
    .clk(clock_2_5MHz),
    .rst(clk_i2c_rst),
    /*
     * I2C master interface
     */
    .cmd_address(cmd_address),
    .cmd_start(cmd_start),
    .cmd_read(cmd_read),
    .cmd_write(cmd_write),
    .cmd_write_multiple(cmd_write_multiple),
    .cmd_stop(cmd_stop),
    .cmd_valid(cmd_valid),
    .cmd_ready(cmd_ready),

    .data_out(data),
    .data_out_valid(data_valid),
    .data_out_ready(data_ready),
    .data_out_last(data_last),
    /*
     * Status
     */
    .busy(),
    /*
     * Configuration
     */
    .start(clk_i2c_start)
);

i2c_master i2c_master_i (
    .clk(clock_2_5MHz),
    .rst(clk_i2c_rst),
    /*
     * Host interface
     */
    .cmd_address(cmd_address),
    .cmd_start(cmd_start),
    .cmd_read(cmd_read),
    .cmd_write(cmd_write),
    .cmd_write_multiple(cmd_write_multiple),
    .cmd_stop(cmd_stop),
    .cmd_valid(cmd_valid),
    .cmd_ready(cmd_ready),

    .data_in(data),
    .data_in_valid(data_valid),
    .data_in_ready(data_ready),
    .data_in_last(data_last),

    .data_out(),
    .data_out_valid(),
    .data_out_ready(1'b1),
    .data_out_last(),

    /*
     * I2C interface
     */
    .scl_i(scl_i),
    .scl_o(scl_o),
    .scl_t(scl_t),
    .sda_i(sda_i),
    .sda_o(sda_o),
    .sda_t(sda_t),

    /*
     * Status
     */
    .busy(),
    .bus_control(),
    .bus_active(),
    .missed_ack(),

    /*
     * Configuration
     */
    .prescale(16'h0002),
    .stop_on_idle(1'b0)
);




// I2C for  bias

wire [6:0]  i2c2_cmd_address;
wire        i2c2_cmd_start, i2c2_cmd_read, i2c2_cmd_write, i2c2_cmd_write_multiple, i2c2_cmd_stop, i2c2_cmd_valid, i2c2_cmd_ready;
wire [7:0]  i2c2_data;
wire        i2c2_data_valid, i2c2_data_ready, i2c2_data_last;
wire        i2c2_scl_i, i2c2_scl_o, i2c2_scl_t, i2c2_sda_i, i2c2_sda_o, i2c2_sda_t;

assign i2c2_scl_i = io_scl2;
assign io_scl2 = i2c2_scl_t ? 1'bz : i2c2_scl_o;
assign i2c2_sda_i = io_sda2;
assign io_sda2 = i2c2_sda_t ? 1'bz : i2c2_sda_o;

i2c2_init i2c2_init_i (
    .clk(clock_2_5MHz),
    .rst(clk_i2c_rst),
    /*
     * I2C master interface
     */
    .cmd_address(i2c2_cmd_address),
    .cmd_start(i2c2_cmd_start),
    .cmd_read(i2c2_cmd_read),
    .cmd_write(i2c2_cmd_write),
    .cmd_write_multiple(i2c2_cmd_write_multiple),
    .cmd_stop(i2c2_cmd_stop),
    .cmd_valid(i2c2_cmd_valid),
    .cmd_ready(i2c2_cmd_ready),

    .data_out(i2c2_data),
    .data_out_valid(i2c2_data_valid),
    .data_out_ready(i2c2_data_ready),
    .data_out_last(i2c2_data_last),
    /*
     * Status
     */
    .busy(),
    /*
     * Configuration
     */
    .bias0(bias0),
    .bias1(bias1)
);

i2c_master i2c2_master_i (
    .clk(clock_2_5MHz),
    .rst(clk_i2c_rst),
    /*
     * Host interface
     */
    .cmd_address(i2c2_cmd_address),
    .cmd_start(i2c2_cmd_start),
    .cmd_read(i2c2_cmd_read),
    .cmd_write(i2c2_cmd_write),
    .cmd_write_multiple(i2c2_cmd_write_multiple),
    .cmd_stop(i2c2_cmd_stop),
    .cmd_valid(i2c2_cmd_valid),
    .cmd_ready(i2c2_cmd_ready),

    .data_in(i2c2_data),
    .data_in_valid(i2c2_data_valid),
    .data_in_ready(i2c2_data_ready),
    .data_in_last(i2c2_data_last),

    .data_out(),
    .data_out_valid(),
    .data_out_ready(1'b1),
    .data_out_last(),

    /*
     * I2C interface
     */
    .scl_i(i2c2_scl_i),
    .scl_o(i2c2_scl_o),
    .scl_t(i2c2_scl_t),
    .sda_i(i2c2_sda_i),
    .sda_o(i2c2_sda_o),
    .sda_t(i2c2_sda_t),

    /*
     * Status
     */
    .busy(),
    .bus_control(),
    .bus_active(),
    .missed_ack(),

    /*
     * Configuration
     */
    .prescale(16'h0002),
    .stop_on_idle(1'b0)
);






function integer clogb2;
input [31:0] depth;
begin
  for(clogb2=0; depth>0; clogb2=clogb2+1)
  depth = depth >> 1;
end
endfunction


endmodule
