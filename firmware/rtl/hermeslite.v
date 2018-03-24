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
// (C) Steve Haynal KF7O 2014-2018


// This RTL originated from www.openhpsdr.org and has been modified to support
// the Hermes-Lite hardware described at http://github.com/softerhardware/Hermes-Lite2.

module hermeslite(

  // Power
  output          pwr_clk3p3,
  output          pwr_clk1p2,
  output          pwr_envpa, 

`ifdef BETA2
  output          pwr_clkvpa,
`else
  output          pwr_envop,
  output          pwr_envbias,
`endif

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
  output          clk_recovered,    // io_db1_1 ; Cooling fan enable
  inout           clk_sda1,
  inout           clk_scl1,

  // RF Frontend
  output          rffe_ad9866_rst_n,

`ifdef HALFDUPLEX
  inout   [5:0]   rffe_ad9866_tx,
  inout   [5:0]   rffe_ad9866_rx,
  output          rffe_ad9866_rxsync,
  output          rffe_ad9866_rxclk,  
`else
  output  [5:0]   rffe_ad9866_tx,
  input   [5:0]   rffe_ad9866_rx,
  input           rffe_ad9866_rxsync,
  input           rffe_ad9866_rxclk,  
`endif

  output          rffe_ad9866_txquiet_n,
  output          rffe_ad9866_txsync,
  output          rffe_ad9866_sdio,
  output          rffe_ad9866_sclk,
  output          rffe_ad9866_sen_n,
  input           rffe_ad9866_clk76p8,
  output          rffe_rfsw_sel,

`ifdef BETA2
  output  [5:0]   rffe_ad9866_pga,
`else
  output          rffe_ad9866_mode,
  output          rffe_ad9866_pga5,
`endif

  // IO
  output          io_led_d2,      // LED or ExtAMP TxD  (BAND)
  inout           io_led_d3,      // LED or ExtAMP RxD  (Pull up)
  output          io_led_d4,      // LED or ATU Start
  inout           io_led_d5,      // LED or ATU Status  (Pull Up)
  input           io_lvds_rxn,
  input           io_lvds_rxp,    // BETA2,BETA3: io_cn5_6 : (88) <- AK4951 SDTO
  output          io_lvds_txn,    // BETA2,BETA3: io_cn5_2 : (86) -> AK4951 BCK
  output          io_lvds_txp,    // BETA2,BETA3: io_cn5_3 : (87) -> AK4951 LRCK
  input           io_cn8,
  input           io_cn9,
  input           io_cn10,
  inout           io_adc_scl,
  inout           io_adc_sda,
  inout           io_scl2,
  inout           io_sda2,
  output          io_db1_2,       // BETA2,BETA3: io_db24  : (76) -> AK4951 SDTI
  input           io_db1_3,       // BETA2,BETA3: io_db22_3: (77) <- CW Paddle DOT  (Pull Up)
  input           io_db1_4,       // BETA2,BETA3: io_db22_2: (80) <- PTT in         (Pull Up)
  input           io_db1_5,       // BETA2,BETA3: io_cn4_6 : (83) <- CW paddle DASH (Pull Up)
  output          io_db1_6,       // BETA2,BETA3: io_cn4_7 : (85) -> AK4951 PDN
  input           io_phone_tip,   // BETA2,BETA3: io_cn4_2 : (91)
  input           io_phone_ring,  // BETA2,BETA3: io_cn4_3 : (90)
  input           io_tp2,
  
`ifndef BETA2
  input           io_tp7,
  input           io_tp8,  
  input           io_tp9,
`endif

  // PA
`ifdef BETA2
  output          pa_tr,
  output          pa_en
`else
  output          pa_inttr,
  output          pa_exttr
`endif
);


// PARAMETERS

// Ethernet Interface
`ifdef BETA2
localparam MAC = {8'h00,8'h1c,8'hc0,8'ha2,8'h12,8'hdd};
`else 
localparam MAC = {8'h00,8'h1c,8'hc0,8'ha2,8'h13,8'hdd};
`endif
//localparam IP = {8'd0,8'd0,8'd0,8'd0};
localparam IP = {8'd192,8'd168,8'd0,8'd100};

// ADC Oscillator
localparam CLK_FREQ = 76800000;
//parameter CLK_FREQ = 73728000;

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


// Number of Receivers
localparam NR = 2;     // number of receivers to implement


// Number of transmitters Be very careful when using more than 1 transmitter!
localparam NT = 1;

// Experimental Predistort On=1 Off=0
localparam PREDISTORT = 0;

`ifdef BETA2
  localparam  Hermes_serialno = 8'd40;     // Serial number of this version
`else
  localparam  Hermes_serialno = 8'd60;     // Serial number of this version
`endif

localparam Penny_serialno = 8'd00;      // Use same value as equ1valent Penny code
localparam Merc_serialno = 8'd00;       // Use same value as equivalent Mercury code

localparam RX_FIFO_SZ  = 4096;          // 16 by 4096 deep RX FIFO
localparam TX_FIFO_SZ  = 1024;          // 16 by 1024 deep TX FIFO
localparam SP_FIFO_SZ = 2048;           // 16 by 8192 deep SP FIFO, was 16384 but wouldn't fit

// Wishbone interconnect
localparam WB_DATA_WIDTH = 32;
localparam WB_ADDR_WIDTH = 6;


logic [WB_ADDR_WIDTH-1:0]   wb_adr;
logic [WB_DATA_WIDTH-1:0]   wb_dat;
logic                       wb_we;
logic                       wb_stb;
logic                       wb_ack;
logic                       wb_cyc;
logic                       wb_tga;

// Individual acknowledges
logic                       wb_ack_i2c;



wire FPGA_PTT;
wire [7:0] AssignNR;         // IP address read from EEPROM


reg mox = 1'b0;
reg resp_rqst = 1'b0;
reg [5:0] addr = 6'h0;
reg [31:0] data = 32'h00;

assign AssignNR = NR;

// Based on dip switch
// SDK has just two dip switches, dipsw[2]==dipsw[1] in SDK, dipsw[1]
// CV has three dip switches
// CVA9 has four dip switches but only three are currently connected
// dipsw[2:1] select alternate MAC addresses
// dipsw[0] selects to identify as hermes or hermes-lite


assign pwr_clk3p3 = 1'b0;
assign pwr_clk1p2 = 1'b0;

`ifdef BETA2
assign pwr_clkvpa = 1'b0;
`endif

//assign io_adc_scl = 1'b0;
//assign io_adc_sda = 1'b0;


//assign clk_recovered = 1'b0;



wire response_inp_tvalid, response_inp_tready, response_out_tready;

// Reset and Clock Control

wire clock_125_mhz_0_deg;
wire clock_125_mhz_90_deg;
wire clock_2_5MHz;
wire clock_25_mhz;
wire clock_12p5_mhz;
wire ethpll_locked;
wire clock_ethtxint;
wire clock_ethtxext;
wire clock_ethrxint;
wire speed_1gb;
reg  speed_1gb_clksel = 1'b0;

ethpll ethpll_inst (
    .inclk0   (phy_clk125),   //  refclk.clk
    .c0 (clock_125_mhz_0_deg), // outclk0.clk
    .c1 (clock_125_mhz_90_deg), // outclk1.clk
    .c2 (clock_2_5MHz), // outclk2.clk
    .c3 (clock_25_mhz),
    .c4 (clock_12p5_mhz),
    .locked (ethpll_locked)
);

always @(posedge clock_2_5MHz)
  speed_1gb_clksel <= speed_1gb;

altclkctrl #(
    .clock_type("AUTO"),
    //.intended_device_family("Cyclone IV E"),
    //.ena_register_mode("none"),
    //.implement_in_les("OFF"),
    .number_of_clocks(2),
    //.use_glitch_free_switch_over_implementation("OFF"),
    .width_clkselect(1)
    //.lpm_type("altclkctrl"),
    //.lpm_hint("unused")
    ) ethtxint_clkmux_i 
(
    .clkselect(speed_1gb_clksel),
    .ena(1'b1),
    .inclk({clock_125_mhz_0_deg,clock_12p5_mhz}),
    .outclk(clock_ethtxint)
);



//assign clock_ethtxint = speed_1gb_clksel ? clock_125_mhz_0_deg : clock_12p5_mhz;

altclkctrl #(
    .clock_type("AUTO"),
    //.intended_device_family("Cyclone IV E"),
    //.ena_register_mode("none"),
    //.implement_in_les("OFF"),
    .number_of_clocks(2),
    //.use_glitch_free_switch_over_implementation("OFF"),
    .width_clkselect(1)
    //.lpm_type("altclkctrl"),
    //.lpm_hint("unused")
    ) ethtxext_clkmux_i 
(
    .clkselect(speed_1gb_clksel),
    .ena(1'b1),
    .inclk({clock_125_mhz_90_deg,clock_25_mhz}),
    .outclk(clock_ethtxext)
);

//assign clock_ethtxext = speed_1gb_clksel ? clock_125_mhz_90_deg : clock_25_mhz;

reg phy_rx_clk_div2;

always @(posedge phy_rx_clk) begin
  phy_rx_clk_div2 <= ~phy_rx_clk_div2;
end

 
//always @(posedge phy_rx_clk)
//  begin
//    phy_rx_clk_div2 <= ~phy_rx_clk_div2 | (phy_rx_dv & ~phy_rx_dv_last);
//    phy_rx_dv_last <= phy_rx_dv;
//  end
 
 
assign clock_ethrxint = speed_1gb_clksel ? phy_rx_clk : phy_rx_clk_div2; // 1000T speed only...speed_1Gbit? PHY_RX_CLOCK : slow_rx_clock; 

//altclkctrl #(
//    .clock_type("AUTO"),
//    //.intended_device_family("Cyclone IV E"),
//    //.ena_register_mode("none"),
//    //.implement_in_les("OFF"),
//    .number_of_clocks(2),
//    //.use_glitch_free_switch_over_implementation("OFF"),
//    .width_clkselect(1)
//    //.lpm_type("altclkctrl"),
//    //.lpm_hint("unused")
//    ) ethrxint_clkmux_i 
//(
//    .clkselect(speed_1gb_clksel),
//    .ena(1'b1),
//    .inclk({phy_rx_clk,phy_rx_clk_div2}),
//    .outclk(clock_ethrxint)
//);


wire ethup;

// phy_rst_n will go high after ~50ms due to RC
// ethpll_locked will go high once pll is locked
assign ethup = ethpll_locked & phy_rst_n;

// ethup starts I2C configuration of the Versa
// the PLL may lock twice the frequency changes

wire clk_ad9866;
wire clk_ad9866_2x;
wire ad9866pll_locked;

ad9866pll ad9866pll_inst (
  .inclk0   (rffe_ad9866_clk76p8),   //  refclk.clk
  .areset   (~ethup),      //   reset.reset
  .c0 (clk_ad9866), // outclk0.clk
  .c1 (clk_ad9866_2x), // outclk1.clk
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

//---------------------------------------------------------
//      CLOCKS
//---------------------------------------------------------

wire CLRCLK;

wire C122_cbclk, C122_cbrise, C122_cbfall, C122_LRfall, MCLKrise;
//Hermes_clk_lrclk_gen #(.CLK_FREQ(CLK_FREQ)) clrgen (
//.reset(rst), .CLK_IN(clk_ad9866), .BCLK(C122_cbclk),
//.Brise(C122_cbrise), .Bfall(C122_cbfall), .LRCLK(CLRCLK) );

Hermes_clk_lrclk_gen #(.CLK_FREQ(CLK_FREQ)) clrgen (
  .reset(rst), .CLK_IN(clk_ad9866), .BCLK(C122_cbclk),
  .Brise(C122_cbrise), .Bfall(C122_cbfall), .LRCLK(CLRCLK),
  .LRfall(C122_LRfall), .MCLK(), .MCLKrise(MCLKrise) );

wire Tx_fifo_rdreq;
wire [10:0] PHY_Tx_rdused;
wire Rx_enable;
wire [7:0] Rx_fifo_data;

wire this_MAC;
wire run;

assign phy_tx_clk = clock_ethtxext;

wire cwkey_i;
wire ptt_i;
wire [7:0] leds;




//assign cwkey_i = io_phone_tip;
//assign ptt_i = io_phone_ring;
assign ptt_i = io_db1_4;



wire [7:0] network_status;

wire dst_unreachable;
wire udp_tx_request;
wire wide_spectrum;
wire discovery_reply;
wire [15:0] to_port;
wire broadcast;
wire udp_rx_active;
wire [7:0] udp_rx_data;
wire rx_fifo_enable;
wire [7:0] rx_fifo_data;

wire [7:0] udp_tx_data;
wire [10:0] udp_tx_length;
wire udp_tx_enable;
wire udp_tx_active;

wire network_state;
wire [47:0] local_mac;

wire discovery_reply_sync;
wire run_sync;
wire wide_spectrum_sync;

wire [31:0] static_ip;

assign static_ip = IP;
assign local_mac =  {MAC[47:2],~io_cn10,MAC[0]};

network network_inst(

  .clock_2_5MHz(clock_2_5MHz),

  .tx_clock(clock_ethtxint),
  .udp_tx_request(udp_tx_request),
  .udp_tx_length({5'h00,udp_tx_length}),
  .udp_tx_data(udp_tx_data),
  .udp_tx_enable(udp_tx_enable),
  .udp_tx_active(udp_tx_active),
  .run(run_sync),
  .port_id(8'h00),

  .rx_clock(clock_ethrxint),
  .to_port(to_port),
  .udp_rx_data(udp_rx_data),
  .udp_rx_active(udp_rx_active),
  .broadcast(broadcast),
  .dst_unreachable(dst_unreachable),

  .static_ip(static_ip),
  .local_mac(local_mac),
  .speed_1gb(speed_1gb),
  .network_state(network_state),
  .network_status(network_status),

  .PHY_TX(phy_tx),
  .PHY_TX_EN(phy_tx_en),
  .PHY_RX(phy_rx),
  .PHY_DV(phy_rx_dv),
    
  .PHY_MDIO(phy_mdio),
  .PHY_MDC(phy_mdc)
);

Rx_recv rx_recv_inst(
    .rx_clk(clock_ethrxint),
    .run(run),
    .wide_spectrum(wide_spectrum),
    .dst_unreachable(dst_unreachable),
    .discovery_reply(discovery_reply),
    .to_port(to_port),
    .broadcast(broadcast),
    .rx_valid(udp_rx_active),
    .rx_data(udp_rx_data),
    .rx_fifo_data(Rx_fifo_data),
    .rx_fifo_enable(Rx_enable)
);

// Only synchronizing one signal as run and wide_spectrum can take time to resolve meta stable state

sync sync_inst1(.clock(clock_ethtxint), .sig_in(discovery_reply), .sig_out(discovery_reply_sync));

sync sync_inst2(.clock(clock_ethtxint), .sig_in(run), .sig_out(run_sync));
//assign run_sync = run;

sync sync_inst3(.clock(clock_ethtxint), .sig_in(wide_spectrum), .sig_out(wide_spectrum_sync));
//assign wide_spectrum_sync = wide_spectrum;

wire Tx_reset;

Tx_send tx_send_inst(
    .tx_clock(clock_ethtxint),
    .Tx_reset(Tx_reset),
    .run(run_sync),
    .wide_spectrum(wide_spectrum_sync),
    .IP_valid(1'b1),
    .Hermes_serialno(Hermes_serialno),
    .IDHermesLite(io_cn9),
    .AssignNR(AssignNR),
    .PHY_Tx_data(PHY_Tx_data),
    .PHY_Tx_rdused(PHY_Tx_rdused),
    .Tx_fifo_rdreq(Tx_fifo_rdreq),
    .This_MAC(local_mac),
    .discovery(discovery_reply_sync),
    .sp_fifo_rddata(sp_fifo_rddata),
    .have_sp_data(sp_data_ready),
    .sp_fifo_rdreq(sp_fifo_rdreq),
    .udp_tx_enable(udp_tx_enable),
    .udp_tx_active(udp_tx_active),
    .udp_tx_request(udp_tx_request),
    .udp_tx_data(udp_tx_data),
    .udp_tx_length(udp_tx_length)
);

//assign This_MAC_o = local_mac;
assign this_MAC = network_status[0];

// FIXME: run_sync is in eth tx clock domain but used in 76 domain outside
//assign run = run_sync;

// Set Tx_reset (no sdr send) if not in RUNNING or DHCP RENEW state
assign Tx_reset = network_state;




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
    clock_ethrxint  |>wrclk                |
                        ---------------------
  IF_PHY_drdy     |rdreq          q[15:0]| IF_PHY_data [swap Endian]
                       |                          |
                    |                rdempty| IF_PHY_rdempty
                     |                    |
             clk_ad9866 |>rdclk rdusedw[12:0]|
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


PHY_Rx_fifo PHY_Rx_fifo_inst(.wrclk (clock_ethrxint),.rdreq (IF_PHY_drdy),.rdclk (clk_ad9866),.wrreq(Rx_enable),
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
          rx_data |data[15:0]     wrfull| sp_fifo_wrfull
                        |                        |
    sp_fifo_wrreq   |wrreq       wrempty| sp_fifo_wrempty
                        |                        |
            C122_clk    |>wrclk              |
                        ---------------------
    sp_fifo_rdreq   |rdreq         q[7:0]| sp_fifo_rddata
                        |                    |
                        |                        |
        clock_ethtxint  |>rdclk              |
                        |                      |
                        ---------------------
                        |                    |
     rst OR   |aclr                |
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

wire C122_rst;
//cdc_sync #(1) reset_C122 (.siga(rst), .rstb(rst), .clkb(clk_ad9866), .sigb(C122_rst));
cdc_sync_rst reset_C122 (.rsta(rst), .clkb(clk_ad9866), .rstb(C122_rst));

SP_fifo  SPF (.aclr(C122_rst | !run_sync), .wrclk (clk_ad9866), .rdclk(clock_ethtxint),
             .wrreq (sp_fifo_wrreq), .data ({{4{rx_data[11]}},rx_data}), .rdreq (sp_fifo_rdreq),
             .q(sp_fifo_rddata), .wrfull(sp_fifo_wrfull), .wrempty(sp_fifo_wrempty));


sp_rcv_ctrl SPC (.clk(clk_ad9866), .reset(C122_rst), .sp_fifo_wrempty(sp_fifo_wrempty),
                 .sp_fifo_wrfull(sp_fifo_wrfull), .write(sp_fifo_wrreq), .have_sp_data(have_sp_data));

// the wideband data is presented too fast for the PC to swallow so slow down

wire sp_data_ready;



// rate is 125e6/2**19
reg [18:0]sp_delay;
always @ (posedge clock_ethtxint)
    sp_delay <= sp_delay + 15'd1;

assign sp_data_ready = ( (speed_1gb ? sp_delay == 0 : sp_delay[15:0] == 0) && have_sp_data);


//assign IF_mic_Data = 0;


// AD9866 Interface
logic 			wb_ack_ad9866;
logic [11:0]  	rx_data;
logic [11:0]  	tx_data;

ad9866 ad9866_i (
  .clk_ad9866(clk_ad9866),
  .clk_ad9866_2x(clk_ad9866_2x),
  .rst_n(ad9866_rst_n),

  .tx_data(tx_data),
  .rx_data(rx_data),
  .tx_en(FPGA_PTT | VNA),

  .rffe_ad9866_rst_n(rffe_ad9866_rst_n),
  .rffe_ad9866_tx(rffe_ad9866_tx),
  .rffe_ad9866_rx(rffe_ad9866_rx),
  .rffe_ad9866_rxsync(rffe_ad9866_rxsync),
  .rffe_ad9866_rxclk(rffe_ad9866_rxclk),  
  .rffe_ad9866_txquiet_n(rffe_ad9866_txquiet_n),
  .rffe_ad9866_txsync(rffe_ad9866_txsync),
  .rffe_ad9866_sdio(rffe_ad9866_sdio),
  .rffe_ad9866_sclk(rffe_ad9866_sclk),
  .rffe_ad9866_sen_n(rffe_ad9866_sen_n),

`ifdef BETA2
  .rffe_ad9866_mode(),
  .rffe_ad9866_pga(rffe_ad9866_pga),
`else
  .rffe_ad9866_mode(rffe_ad9866_mode),
  .rffe_ad9866_pga5(rffe_ad9866_pga5),
`endif

  .wbs_adr_i(wb_adr),
  .wbs_dat_i(wb_dat),
  .wbs_we_i(wb_we),
  .wbs_stb_i(wb_stb),
  .wbs_ack_o(wb_ack_ad9866),
  .wbs_cyc_i(wb_cyc)
);


wire rxclipp = (rx_data == 12'b011111111111);
wire rxclipn = (rx_data == 12'b100000000000);

// Like above but 2**11.585 = (4096-1024) = 3072
wire rxgoodlvlp = (rx_data[11:9] == 3'b011);
wire rxgoodlvln = (rx_data[11:9] == 3'b100);



wire  [31:0] C122_LR_data;

reg signed [15:0]C122_cic_i;
reg signed [15:0]C122_cic_q;
wire C122_ce_out_i;
wire C122_ce_out_q;

//------------------------------------------------------------------------------
//                 Pulse generators
//------------------------------------------------------------------------------


//  Create short pulse from posedge of CLRCLK synced to clk_ad9866 for RXF read timing

pulsegen cdc_m   (.sig(CLRCLK), .rst(rst), .clk(clk_ad9866), .pulse(IF_get_samples));


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
always @ (posedge clk_ad9866) begin
    adcpipe[0] <= rx_data;
    adcpipe[1] <= rx_data;
    adcpipe[2] <= rx_data;
    adcpipe[3] <= rx_data;
end


// set the decimation rate 40 = 48k.....2 = 960k

    reg [5:0] rate;

    always @ ({IF_DFS1, IF_DFS0})
    begin
        case ({IF_DFS1, IF_DFS0})

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

    //always @ (posedge clk_ad9866)
    //begin
    //  if (C122_cbrise) // time between C122_cbrise is enough for ratio calculation to settle
    //  begin
    //    C122_last_freq[c] <= C122_frequency_HZ[c];
    //    if (C122_last_freq[c] != C122_frequency_HZ[c]) // frequency changed)
    //      C122_sync_phase_word[c] <= C122_ratio[c][56:25]; // B57 -> B32 number since R is always >= 0
    //  end
    //end

  assign C122_frequency_HZ[c] = IF_frequency[c+1];
    assign C122_sync_phase_word[c] = C122_frequency_HZ[c];

    assign IF_M_IQ_Data[c] = {rx_I[c], rx_Q[c]};
    assign IF_M_IQ_Data_rdy[c] = strobe[c];



if((c==3 && NR>3) || (c==1 && NR<=3))
  begin
  //    wire signed [23:0] psout_data_I2;
  //   wire signed [23:0] psout_data_Q2;
  //   assign rx_I[c] = psout_data_I2 <<< (FPGA_PTT? 2:0);
  //   assign rx_Q[c] = psout_data_Q2 <<< (FPGA_PTT? 2:0);

       receiver #(.CICRATE(CICRATE)) receiver_inst (
      //control
      .clock(clk_ad9866),
      .rate(rate),
      .frequency(C122_sync_phase_word[c]),
      .out_strobe(strobe[c]),
      //input
      //.in_data(FPGA_PTT ? DACD : adcpipe[c/8]),
    .in_data((FPGA_PTT & IF_Pure_signal) ? tx_data : adcpipe[c/8]), //tx_data was pipelined here once
     //output
    //  .out_data_I(psout_data_I2),
    //  .out_data_Q(psout_data_Q2)
      .out_data_I(rx_I[c]),
      .out_data_Q(rx_Q[c])
      );


    end
else
  begin

      receiver #(.CICRATE(CICRATE)) receiver_inst (
      //control
      .clock(clk_ad9866),
      .rate(rate),
      .frequency(C122_sync_phase_word[c]),
      .out_strobe(strobe[c]),
      //input
      .in_data(adcpipe[c/8]),
      //output
      .out_data_I(rx_I[c]),
      .out_data_Q(rx_Q[c])
      );
  end
end
endgenerate


// calc frequency phase word for Tx
//assign C122_ratio_Tx = IF_frequency[0] * M2;
// Note: We add 1/2 M2 (M3) so that we end up with a rounded 32 bit integer below.
//assign C122_ratio_Tx = IF_frequency[0] * M2 + M3;

//always @ (posedge clk_ad9866)
//begin
//  if (C122_cbrise)
//  begin
//    C122_last_freq_Tx <= IF_frequency[0];
//   if (C122_last_freq_Tx != IF_frequency[0])
//    C122_sync_phase_word_Tx <= C122_ratio_Tx[56:25];
//  end
//end

assign C122_sync_phase_word_Tx = IF_frequency[0];



//---------------------------------------------------------
//    ADC SPI interface
//---------------------------------------------------------

wire [11:0] AIN1;
wire [11:0] AIN2;
wire [11:0] AIN3;
wire [11:0] AIN4;
wire [11:0] AIN5;  // holds 12 bit ADC value of Forward Power detector.
wire [11:0] AIN6;  // holds 12 bit ADC of 13.8v measurement

assign AIN4 = 0;
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
always @ (posedge clk_ad9866)
begin
    if (req1) begin
        C122_fir_i = IF_I_PWM;
        C122_fir_q = IF_Q_PWM;
    end
end


// Interpolate I/Q samples from 48 kHz to the clock frequency

wire req1, req2;
wire [19:0] y1_r, y1_i;
wire [15:0] y2_r, y2_i;

FirInterp8_1024 fi (clk_ad9866, req2, req1, C122_fir_i, C122_fir_q, y1_r, y1_i);  // req2 enables an output sample, req1 requests next input sample.

// GBITS reduced to 30
CicInterpM5 #(.RRRR(RRRR), .IBITS(20), .OBITS(16), .GBITS(GBITS)) in2 ( clk_ad9866, 1'd1, req2, y1_r, y1_i, y2_r, y2_i);



//---------------------------------------------------------
//    CORDIC NCO
//---------------------------------------------------------

// Code rotates input at set frequency and produces I & Q

wire signed [15:0] C122_cordic_i_out;
wire signed [15:0] C122_cordic_q_out;
wire signed [31:0] C122_phase_word_Tx;

wire signed [15:0] I;
wire signed [15:0] Q;

// if in VNA mode use the Rx[0] phase word for the Tx
assign C122_phase_word_Tx = VNA ? C122_sync_phase_word[0] : C122_sync_phase_word_Tx;
assign                  I = VNA ? 16'h4d80 : (cwkey ? {1'b0, cwlevel[17:3]} : y2_i);    // select VNA mode if active. Set CORDIC for max DAC output
assign                  Q = (VNA | cwkey) ? 0 : y2_r;                   // taking into account CORDICs gain i.e. 0x7FFF/1.7


// NOTE:  I and Q inputs reversed to give correct sideband out

cpl_cordic #(.OUT_WIDTH(16))
        cordic_inst (.clock(clk_ad9866), .frequency(C122_phase_word_Tx), .in_data_I(I),
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
            cordic_tx2_inst (.clock(clk_ad9866), .frequency(C122_sync_phase_word[1]), .in_data_I(I),
            .in_data_Q(Q), .out_data_I(C122_cordic_tx2_i_out), .out_data_Q(C122_cordic_tx2_q_out));

        assign txsum = (C122_cordic_i_out + C122_cordic_tx2_i_out) >>> 3;
        assign txsumq = (C122_cordic_q_out + C122_cordic_tx2_q_out) >>> 3;

    end
endgenerate



// LFSR for dither
//reg [15:0] lfsr = 16'h0001;
//always @ (negedge clk_ad9866 or negedge extreset)
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

always @ (posedge clk_ad9866)
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


always @ (posedge clk_ad9866)
begin
    txsumr2<=txsumr;
    txsumqr2<=txsumqr;
    iplusq_over_root2r<=iplusq_over_root2;
end
    assign distorted_dac = DACLUTI[txsumr2[11:0]]-DACLUTI[txsumqr2[11:0]]+DACLUTQ[iplusq_over_root2r[12:1]];

always @ (posedge clk_ad9866)
case( IF_Predistortion[1:0] )
    0: tx_data <= txsum[11:0];
    1: tx_data <= distorted_dac[11:0];
    //other modes
    default: tx_data <= txsum[11:0];
endcase

end else

always @ (posedge clk_ad9866)
    tx_data <= txsum[11:0]; // + {10'h0,lfsr[2:1]};

endgenerate



//------------------------------------------------------------
//  Set Power Output
//------------------------------------------------------------

// PWM DAC to set drive current to DAC. PWM_count increments
// using clk_ad9866. If the count is less than the drive
// level set by the PC then DAC_ALC will be high, otherwise low.

//reg [7:0] PWM_count;
//always @ (posedge clk_ad9866)
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
//wire    [4:0] IF_last_chan;
//wire     [47:0] IF_chan_test;

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

wire VNA_start = VNA && basewrite[0] && (addr == 6'h01);  // indicates a frequency change for the VNA.

wire [37:0] response_out_tdata;
wire response_out_tvalid;
wire resposne_out_tready;
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
           (rst, clk_ad9866, IF_tx_fifo_wdata, IF_tx_fifo_wreq, IF_tx_fifo_full,
            IF_tx_fifo_used, IF_tx_fifo_clr, IF_tx_IQ_mic_rdy,
            IF_tx_IQ_mic_data, IF_chan, IF_last_chan, clean_dash, clean_dot, (cwkey | clean_ptt), OVERFLOW,
            Penny_serialno, Merc_serialno, Hermes_serialno, Penny_ALC, AIN1, AIN2,
            AIN3, AIN4, AIN6, IO4, IO5, IO6, IO8, VNA_start, VNA,
            response_out_tdata, response_out_tvalid, response_out_tready );


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
        clk_ad9866          |>wrclk  wrused[9:0]| IF_tx_fifo_used
                           ---------------------
    Tx_fifo_rdreq       |rdreq         q[7:0]| PHY_Tx_data
                           |                          |
       clock_ethtxint       |>rdclk       rdempty|
                           |          rdusedw[10:0]| PHY_Tx_rdused  (0 to 2047 bytes)
                           ---------------------
                           |                    |
 IF_tx_fifo_clr OR      |aclr                |
    rst              ---------------------



*/

Tx_fifo Tx_fifo_inst(.wrclk (clk_ad9866),.rdreq (Tx_fifo_rdreq),.rdclk (clock_ethtxint),.wrreq (IF_tx_fifo_wreq),
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

FIFO #(RX_FIFO_SZ) RXF (.rst(rst), .clk (clk_ad9866), .full(IF_Rx_fifo_full), .usedw(IF_Rx_fifo_used),
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

reg   [2:0] basewrite; // Shift register to delay write 


localparam SYNC_IDLE   = 1'd0,
           SYNC_START  = 1'd1,
           SYNC_RX_1_2 = 2'd2,
           SYNC_RX_3_4 = 2'd3,
           SYNC_FINISH = 3'd4;

always @ (posedge clk_ad9866)
begin
  if (rst)
    IF_SYNC_state <=  SYNC_IDLE;
  else
    IF_SYNC_state <=  IF_SYNC_state_next;

  if (rst)
    basewrite <= 3'b000;
  else
    basewrite <= {basewrite[1:0],IF_PHY_drdy && (IF_SYNC_state == SYNC_RX_3_4)};

  if (IF_PHY_drdy && (IF_SYNC_state == SYNC_START) && (IF_PHY_data[15:8] == 8'h7F))
  begin
    resp_rqst <= IF_PHY_data[7];
    addr <= IF_PHY_data[6:1];
    mox <= IF_PHY_data[0];
  end
  if (IF_PHY_drdy && (IF_SYNC_state == SYNC_RX_1_2))
  begin
    data[31:16] <= IF_PHY_data;
  end

  if (IF_PHY_drdy && (IF_SYNC_state == SYNC_RX_3_4))
  begin
    data[15:0] <= IF_PHY_data;
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




reg   [6:0] IF_OC;                  // open collectors on Hermes
reg   [2:0] IF_Cooling;             // Cooling fan 0:off
reg         IF_SPK_enable;          // Speaker 1:enable
reg         Preamp;                 // selects input attenuator setting, 0 = 20dB, 1 = 0dB (preamp ON)
reg  [31:0] IF_frequency[0:NR];     // Tx, Rx1, Rx2, Rx3
reg         IF_duplex;
reg   [4:0] IF_last_chan;
reg         IF_DFS1;
reg         IF_DFS0;
reg         IF_autoTune;            // Apollo auto-tune
reg         VNA;                    // Selects VNA mode when set.
reg         IF_Pure_signal;              
reg   [3:0] IF_Predistortion;             
//reg         IF_PA_enable;
//reg         IF_TR_disable;
wire        IF_PA_enable  = 1'b1 ;  // always PA enable
wire        IF_TR_disable = 1'b0 ;  // always TR enable
reg         IF_Mic_boost;           // Mic boost 0 = 0dB, 1 = 20dB
reg         IF_CW_keys_reversed ;   // 0:disable, 1:enable
reg   [5:0] IF_Keyer_speed ;        // 1 - 60 WPM
reg   [1:0] IF_Keyer_Mode ;         // 00:straight, 01:Mode A, 10:Mode B
reg   [6:0] IF_Keyer_Weight ;       // 0 - 100
reg   [7:0] IF_CW_Sidetone_Vol ;    // 0 - 127
reg   [7:0] IF_CW_PTT_delay ;       // 0 - 255  ms
reg   [9:0] IF_CW_Hang_Time ;       // 0 - 1023 ms
reg  [11:0] IF_CW_Tone_Freq ;       // 200 - 2250Hz
reg         IF_CW_internal ;        // 0:External, 1:Internal
reg         Alex_manual;            // set if manual selection of Alex relays active
reg   [5:0] Alex_manual_HPF;        // Alex HPF relay selection in manual mode
reg   [6:0] Alex_manual_LPF;        // Alex LPF relay selection in manual mode

always @ (posedge clk_ad9866)
begin
  if (rst)
  begin // set up default values - 0 for now
    // RX_CONTROL_1
    IF_DFS1 <= 1'b0; // decode speed
    IF_DFS0 <= 1'b0;
    IF_OC              <= 7'b0;     // decode open collectors on Hermes
    IF_Cooling         <= 3'b0;     // default off
    IF_SPK_enable      <= 1'b1;     // default enable Speaker
    Preamp             <= 1'b1;     // decode Preamp (Attenuator), default on
    IF_duplex          <= 1'b0;     // not in duplex mode
    IF_last_chan       <= 5'b00000;    // default single receiver
    IF_autoTune        <= 1'b0;      // Apollo auto-tune disabled
    VNA                <= 1'b0;      // VNA disabled
    IF_Pure_signal     <= 1'b0;      // default disable pure signal
    IF_Predistortion   <= 4'b0000;   // default disable predistortion
//    IF_PA_enable       <= 1'b0;
//    IF_TR_disable      <= 1'b0;
    IF_Mic_boost       <= 1'b0;     // mic boost off
    IF_CW_keys_reversed <= 1'b0 ;   // default disable keys reverse
    IF_Keyer_speed     <= 6'd25 ;   // default 25WPM
    IF_Keyer_Mode      <= 2'd0 ;    // default Keyer disable
    IF_Keyer_Weight    <= 7'd50 ;   // default 50
    IF_CW_Sidetone_Vol <= 8'd60 ;   // default 60
    IF_CW_PTT_delay    <= 8'd10 ;   // default 10ms
    IF_CW_Hang_Time    <= 10'd200 ; // default 200ms
    IF_CW_Tone_Freq    <= 12'd600 ; // default 600Hz 
    IF_CW_internal     <= 1'b0 ;    // default exnternal
    Alex_manual        <= 1'b0;     // default auto Alex filter
    Alex_manual_HPF    <= 6'h20 ;   // default Bypass
    Alex_manual_LPF    <= 7'h40 ;   // default 12/10M

  end
  else if (basewrite[0])                  // all Rx_control bytes are ready to be saved
  begin                                         // Need to ensure that C&C data is stable
    if (addr == 6'h00)
    begin
      // RX_CONTROL_1
      IF_DFS1  <= data[25]; // decode speed
      IF_DFS0  <= data[24]; // decode speed
      IF_OC               <= data[23:17]; // decode open collectors on Penelope
      IF_Cooling          <= data[15:13]; // reuse Alex Rx out/Antenna
      IF_SPK_enable       <= data[12];  // reuse IF_RAND
      Preamp              <= data[10];  // decode Preamp (Attenuator)  1 = On (0dB atten), 0 = Off (20dB atten)
      IF_duplex           <= data[2];   // save duplex mode
      IF_last_chan        <= data[7:3]; // number of IQ streams to send to PC
    end
    if (addr == 6'h09)
    begin
      VNA                 <= data[23];      // 1 = enable VNA mode
      Alex_manual         <= data[22];     // manual Alex filter selection (0 = disable, 1 = enable)
      IF_autoTune         <= data[20];     // 1 = begin Apollo auto-tune
//      IF_PA_enable      <= data[19];
//      IF_TR_disable       <= data[18];
      IF_Mic_boost        <= data[16];      // decode mic boost 0 = 0dB, 1 = 20dB
      Alex_manual_HPF     <= data[13:8];
      Alex_manual_LPF     <= data[6:0];
    end
    if (addr == 6'h0a)
    begin
      IF_Pure_signal    <= data[22];       // decode pure signal setting
    end
    if (addr == 6'h0b)
    begin
      IF_CW_keys_reversed <= data[22];     // decode CW keys reversed setting
      IF_Keyer_speed   <= data[13:8];      // decode Keyer speed setting
      IF_Keyer_Mode    <= data[15:14];     // decode Keyer Mode setting
      IF_Keyer_Weight  <= data[6:0];       // decode Keyer Weight setting
    end
    if (addr == 6'h0f)
    begin
      IF_CW_internal     <= data[24];      // decode CW internal generation
      IF_CW_Sidetone_Vol <= data[23:16];   // decode CW Sidetone Vol setting
      IF_CW_PTT_delay  <= data[15:8];      // decode CW PTT delay setting
    end
    if (addr == 6'h10)
    begin
      IF_CW_Hang_Time <= {data[31:24], data[17:16]} ; // decode CW Hang Time setting
      IF_CW_Tone_Freq <= {data[15:8], data[3:0]} ;    // decode CW Sidetone frequency setting
    end
    if (addr == 6'h2b)
    begin
      if(data[31:24]==8'h00)//predistortion control sub index
      begin
      IF_Predistortion <= data[19:16];
      end
     end
  end
end

// Always compute frequency
// This really should be done on the PC....
wire [63:0] freqcomp;
assign freqcomp = data * M2 + M3;

// Pipeline freqcomp
reg [31:0] freqcompp [0:3];
reg [5:0] chanp [0:3];

always @ (posedge clk_ad9866) begin
  // Pipeline to allow 2 cycles for multiply
    if (basewrite[1]) begin
        freqcompp[0] <= freqcomp[56:25];
        freqcompp[1] <= freqcomp[56:25];
        freqcompp[2] <= freqcomp[56:25];
        freqcompp[3] <= freqcomp[56:25];
        chanp[0] <= addr;
        chanp[1] <= addr;
        chanp[2] <= addr;
        chanp[3] <= addr;
    end
end


always @ (posedge clk_ad9866)
begin
  if (rst)
  begin // set up default values - 0 for now
    IF_frequency[0] <= 32'd0;
    IF_frequency[1] <= 32'd0;
  end
  else if (basewrite[2])
  begin
    if (chanp[0] == 6'h01) begin // decode IF_frequency[0]
        IF_frequency[0]   <= freqcompp[0]; //freqcomp[56:25];
        if (!IF_duplex && (IF_last_chan == 5'b00000)) IF_frequency[1] <= IF_frequency[0];
    end

    if (chanp[0] == 6'h02) begin // decode Rx1 frequency
        if (!IF_duplex && (IF_last_chan == 5'b00000)) IF_frequency[1] <= IF_frequency[0];
        else IF_frequency[1] <= freqcompp[0]; //freqcomp[56:25];
    end
  end
end


generate
  for (c = 1; c < NR; c = c + 1) begin: RXIFFREQ
    always @ (posedge clk_ad9866) begin
        if (rst) IF_frequency[c+1] <= 32'd0;
        else if (basewrite[2]) begin
            if (chanp[c/8] == ((c < 7) ? c+2 : c+11)) begin
              //if (IF_last_chan >= c)
                IF_frequency[c+1] <= freqcompp[c/8]; //freqcomp[56:25];
              //else IF_frequency[c+1] <= IF_frequency[0];
            end
        end
    end
  end
endgenerate


wire clean_txinhibit;
debounce de_txinhibit(.clean_pb(clean_txinhibit), .pb(~io_cn8), .clk(clk_ad9866));

wire mox_out;
assign FPGA_PTT = (mox_out | cwkey | clean_ptt) & ~clean_txinhibit; // mox only updated when we get correct sync sequence

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
reg  [15:0] IF_Right_Data;     // Right 16 bit PWM data for D/A converter
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

always @ (posedge clk_ad9866)
begin
  if (rst)
    IF_PWM_state   <=  PWM_IDLE;
  else
    IF_PWM_state   <=  IF_PWM_state_next;

  // get Left audio
  if (IF_PWM_state == PWM_LEFT)
    IF_Left_Data   <=  IF_Rx_fifo_rdata;

  // get Right audio
  if (IF_PWM_state == PWM_RIGHT)
  begin
    //IF_Right_Data  <=  IF_Rx_fifo_rdata;

     if(IF_Left_Data[12] )
        PD1.DACLUTQ[IF_Left_Data[11:0]]<= IF_Rx_fifo_rdata[12:0];
    else
        PD1.DACLUTI[IF_Left_Data[11:0]]<= IF_Rx_fifo_rdata[12:0];

    end

  // get I audio
  if (IF_PWM_state == PWM_I_AUDIO)
    IF_I_PWM       <=  IF_Rx_fifo_rdata;

  // get Q audio
  if (IF_PWM_state == PWM_Q_AUDIO)
    IF_Q_PWM       <=  IF_Rx_fifo_rdata;

end


end else begin


always @ (posedge clk_ad9866)
begin
  if (rst)
    IF_PWM_state   <=  PWM_IDLE;
  else
    IF_PWM_state   <=  IF_PWM_state_next;

  // get Left audio
  if (IF_PWM_state == PWM_LEFT)
    IF_Left_Data   <=  IF_Rx_fifo_rdata;

  // get Right audio
  if (IF_PWM_state == PWM_RIGHT)
    IF_Right_Data  <=  IF_Rx_fifo_rdata;

  // get I audio
  if (IF_PWM_state == PWM_I_AUDIO)
    IF_I_PWM       <=  IF_Rx_fifo_rdata;

  // get Q audio
  if (IF_PWM_state == PWM_Q_AUDIO)
    IF_Q_PWM       <=  IF_Rx_fifo_rdata;

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

// 2 ms rise and fall, not shaped, but like HiQSDR
// MAX CWLEVEL is picked to be 8*max cordic level for transmit
// ADJUST if cordic max changes...
localparam MAX_CWLEVEL = 18'h26c00; //(16'h4d80 << 3);
wire clean_cwkey;
wire cwkey;
reg [17:0] cwlevel;
reg [1:0] cwstate;
localparam  cwrx = 2'b00, cwkeydown = 2'b01, cwkeyup = 2'b11;

// 5 ms debounce with 48 MHz clock
//debounce de_cwkey(.clean_pb(clean_cwkey), .pb(~cwkey_i), .clk(clk_ad9866));

// CW state machine
always @(posedge clk_ad9866)
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

//assign io_db1_5 = cwkey;

//---------------------------------------------------------
//  Debounce dot key - active low
//---------------------------------------------------------

//debounce de_dot(.clean_pb(clean_dot), .pb(~KEY_DOT), .clk(clk_ad9866));
assign clean_dot = 0;

//---------------------------------------------------------
//  Debounce dash key - active low
//---------------------------------------------------------

//debounce de_dash(.clean_pb(clean_dash), .pb(~KEY_DASH), .clk(clk_ad9866));
assign clean_dash = 0;



// 5 ms debounce with 48 MHz clock
wire clean_ptt;
debounce de_ptt(.clean_pb(clean_ptt), .pb(~ptt_i), .clk(clk_ad9866));


// Really 0.16 seconds at Hermes-Lite 61.44 MHz clock
localparam half_second = 24'd10000000; // at 48MHz clock rate

Led_flash Flash_LED0(.clock(clk_ad9866), .signal(rxclipp), .LED(leds[0]), .period(half_second));
Led_flash Flash_LED1(.clock(clk_ad9866), .signal(rxgoodlvlp), .LED(leds[1]), .period(half_second));
Led_flash Flash_LED2(.clock(clk_ad9866), .signal(rxgoodlvln), .LED(leds[2]), .period(half_second));
Led_flash Flash_LED3(.clock(clk_ad9866), .signal(rxclipn), .LED(leds[3]), .period(half_second));

Led_flash Flash_LED4(.clock(clk_ad9866), .signal(this_MAC), .LED(leds[4]), .period(half_second));
Led_flash Flash_LED5(.clock(clk_ad9866), .signal(run_sync), .LED(leds[5]), .period(half_second));
Led_flash Flash_LED6(.clock(clk_ad9866), .signal(IF_SYNC_state == SYNC_RX_1_2), .LED(leds[6]), .period(half_second));


//assign io_led_d2 = leds[4];
//assign io_led_d3 = leds[5];
//assign io_led_d4 = leds[0];
//assign io_led_d5 = leds[3];




// FIXME: Sequence power
// FIXME: External TR won't work in low power mode
wire FPGA_PTT_keyer;

`ifdef BETA2
assign pa_tr = FPGA_PTT_keyer & (IF_PA_enable | ~IF_TR_disable);
assign pa_en = FPGA_PTT_keyer & IF_PA_enable;
assign pwr_envpa = FPGA_PTT_keyer;
`else
assign pwr_envbias = FPGA_PTT_keyer & IF_PA_enable;
assign pwr_envop = FPGA_PTT_keyer;
assign pa_exttr = FPGA_PTT_keyer;
assign pa_inttr = FPGA_PTT_keyer & (IF_PA_enable | ~IF_TR_disable);
assign pwr_envpa = FPGA_PTT_keyer & IF_PA_enable;
`endif

assign rffe_rfsw_sel = IF_PA_enable;

wire scl1_i, scl1_t, scl1_o, sda1_i, sda1_t, sda1_o;
wire scl2_i, scl2_t, scl2_o, sda2_i, sda2_t, sda2_o;
wire scl3_i, scl3_t, scl3_o, sda3_i, sda3_t, sda3_o;

wire [6:0] select_HPF_LPF;

i2c #(.WB_DATA_WIDTH(WB_DATA_WIDTH), .WB_ADDR_WIDTH(WB_ADDR_WIDTH)) i2c_i
(
  .clk(clock_2_5MHz),
  .clock_76p8_mhz(clk_ad9866),
  .rst(clk_i2c_rst),
  .init_start(clk_i2c_start),
  .IF_SPK_enable(IF_SPK_enable),
  .IF_Mic_boost(IF_Mic_boost),
  .select_HPF_LPF(select_HPF_LPF),

  .wbs_adr_i(wb_adr),
  .wbs_dat_i(wb_dat),
  .wbs_we_i(wb_we),
  .wbs_stb_i(wb_stb),
  .wbs_ack_o(wb_ack_i2c),
  .wbs_cyc_i(wb_cyc),

  .scl1_i(scl1_i),
  .scl1_o(scl1_o),
  .scl1_t(scl1_t),
  .sda1_i(sda1_i),
  .sda1_o(sda1_o),
  .sda1_t(sda1_t),
  .scl2_i(scl2_i),
  .scl2_o(scl2_o),
  .scl2_t(scl2_t),
  .sda2_i(sda2_i),
  .sda2_o(sda2_o),
  .sda2_t(sda2_t)
);



assign scl1_i = clk_scl1;
assign clk_scl1 = scl1_t ? 1'bz : scl1_o;
assign sda1_i = clk_sda1;
assign clk_sda1 = sda1_t ? 1'bz : sda1_o;

assign scl2_i = io_scl2;
assign io_scl2 = scl2_t ? 1'bz : scl2_o;
assign sda2_i = io_sda2;
assign io_sda2 = sda2_t ? 1'bz : sda2_o;


slow_adc slow_adc_i (
  .clk(clk_ad9866),
  .rst(rst),
  .ain0(AIN1),
  .ain1(AIN5),
  .ain2(AIN3),
  .ain3(AIN2),
  .scl_i(scl3_i),
  .scl_o(scl3_o),
  .scl_t(scl3_t),
  .sda_i(sda3_i),
  .sda_o(sda3_o),
  .sda_t(sda3_t)
);

assign scl3_i = io_adc_scl;
assign io_adc_scl = scl3_t ? 1'bz : scl3_o;
assign sda3_i = io_adc_sda;
assign io_adc_sda = sda3_t ? 1'bz : sda3_o;

assign response_inp_tvalid = response_inp_tready & wb_tga & wb_stb & wb_ack & wb_we;

axis_fifo #(.ADDR_WIDTH(1), .DATA_WIDTH(38)) response_fifo (
  .clk(clk_ad9866),
  .rst(rst),
  .input_axis_tdata({wb_adr,wb_dat}),
  .input_axis_tvalid(response_inp_tvalid),
  .input_axis_tready(response_inp_tready),
  .input_axis_tlast(1'b0),
  .input_axis_tuser(1'b0),

  .output_axis_tdata(response_out_tdata),
  .output_axis_tvalid(response_out_tvalid),
  .output_axis_tready(response_out_tready),
  .output_axis_tlast(),
  .output_axis_tuser()
);


cmd_wbm #(.WB_DATA_WIDTH(WB_DATA_WIDTH), .WB_ADDR_WIDTH(WB_ADDR_WIDTH)) cmd_wbm_i (
  .clk(clk_ad9866),
  .rst(rst),

  .wbm_adr_o(wb_adr), 
  .wbm_dat_o(wb_dat),
  .wbm_we_o(wb_we), 
  .wbm_stb_o(wb_stb),
  .wbm_ack_i(wb_ack),
  .wbm_cyc_o(wb_cyc),
  .wbm_tga_o(wb_tga),

  .cmd_resp_rqst(resp_rqst),
  .cmd_write(basewrite[1]),
  .cmd_addr(addr),
  .cmd_data(data)
);

// OR acknowledge from all slaves
assign wb_ack = wb_ack_i2c | wb_ack_ad9866;


function integer clogb2;
input [31:0] depth;
begin
  for(clogb2=0; depth>0; clogb2=clogb2+1)
  depth = depth >> 1;
end
endfunction

// ============================================================================== //
//		External Audio Codec
// ============================================================================== //

wire CPDN     = ~clk_i2c_rst;     // Reset ; active "L"
wire CBCLK    = C122_cbclk;       // I2S BCLK
wire CDIN;                        // I2S Data Out
wire CDOUT;                       // I2S Data In

assign io_db1_6    = CPDN;        // -> AK4951 PDN
assign io_lvds_txn = CBCLK;       // -> AK4951 BICK  ; 3072kHz
assign io_lvds_txp = CLRCLK;      // -> AK4951 LRCLK ; 48kHz
assign io_db1_2    = CDIN;        // -> AK4951 SDTI
assign CDOUT       = io_lvds_rxp; // <- AK4951 SDTO

//---------------------------------------------------------
//		Send L/R audio to AK4951 in I2S format
//---------------------------------------------------------

assign C122_LR_data = {IF_Left_Data,IF_Right_Data};

wire [31:0] i2s_tx_data ;
I2S_xmit #(.DATA_BITS(32))  // CLRCLK running at 48KHz
  LR (.rst(rst), .lrclk(CLRCLK), .clk(clk_ad9866), .CBrise(C122_cbrise),
      .CBfall(C122_cbfall), .sample(i2s_tx_data), .outbit(CDIN));

//---------------------------------------------------------
//		Get mic data from AK4951 in I2S format
//--------------------------------------------------------- 

wire [31:0] C122_mic_LR;
wire        C122_mic_rdy;
reg  [15:0] C122_mic_data;
      
// Get I2S CDOUT mic data from TLV320.  NOTE: only 16 bits used
I2S_rcv_24b #(32,2,1) // WARNING: values 2,1 may need adjusting for best capture of data
    MIC (.xrst(rst), .xclk(clk_ad9866), .BCLK(CBCLK), .LRCLK(CLRCLK), .din(CDOUT),.xData(C122_mic_LR),.xData_rdy(C122_mic_rdy));
    
always @(posedge clk_ad9866)
begin
  if (C122_mic_rdy) // this happens before LRfall
    C122_mic_data <= C122_mic_LR[31:16]; // we're only using the Left data
end

assign IF_mic_Data = C122_mic_data;

// ============================================================================== //
//	Iambic Keyer
//      IF_Keyer_Mode: 00=Straight, 10=Iambic, 01=PracticeMode, 11=Not defined
// ============================================================================== //

wire   paddle_dot_n  = io_db1_3; // active "L"
wire   paddle_dash_n = io_db1_5; // active "L"  

wire   host_dot_n  = ~(IF_I_PWM[2] & IF_CW_internal) ; // Active "L"
wire   host_dash_n = ~(IF_I_PWM[1] & IF_CW_internal) ; // Active "L"
wire   keyer_cwkey ;
assign clean_cwkey = (IF_I_PWM[0] | keyer_cwkey) & IF_CW_internal & run ;

KeyerWrapper keyerwapper(
	.IF_clk(clk_ad9866),         // 48MHz for I/F -> 76.8MHz
	.IF_rst(rst),
	.AD9866clkX1(clk_ad9866),	   // 76.8MHz for audio
	.C122_rst(rst),
	.C122_LRfall(C122_LRfall),
	.paddle_dot_n(paddle_dot_n & host_dot_n),    // Dot  Key (Active "L")
	.paddle_dash_n(paddle_dash_n & host_dash_n), // Dash Key (Active "L")
	.IF_Keyer_Mode(IF_Keyer_Mode),
	.IF_CW_keys_reversed(IF_CW_keys_reversed),
	.IF_Keyer_speed(IF_Keyer_speed),
	.IF_Keyer_Weight(IF_Keyer_Weight),
	.IF_CW_Hang_Time(IF_CW_Hang_Time),
	.IF_CW_Tone_Freq(IF_CW_Tone_Freq),
	.IF_CW_Sidetone_Vol(IF_CW_Sidetone_Vol),
	.IF_CW_PTT_delay(IF_CW_PTT_delay),
	.C122_LR_data(C122_LR_data),     // AudioCodec hook in
	.i2s_tx_data(i2s_tx_data),	      // AudioCodec hook out
	.FPGA_PTT(FPGA_PTT),	            // PTT hook in
	.exp_ptt_n(FPGA_PTT_keyer),      // PTT hook out (Active "H")
	.clean_cwkey(keyer_cwkey),       // CW lamp up/down control (Active "H")
	.sidetone()                      // Squarewave ("L" when no sound)
) ;

// ============================================================================== //
//		Alex Auto/Manual Fliter control (NR=2)
// ============================================================================== //

reg [31:0] freq_max; // max operation freq. 
reg [31:0] freq_min; // min operation freq.
always @ (posedge clk_ad9866) begin
  if (FPGA_PTT_keyer)
    freq_max <= C122_phase_word_Tx ;
  else if ((IF_last_chan==5'b0) || (C122_sync_phase_word[0] >= C122_sync_phase_word[1]))
    freq_max <= C122_sync_phase_word[0];
  else
    freq_max <= C122_sync_phase_word[1];

  if ((IF_last_chan==5'b0) || (C122_sync_phase_word[1]==32'b0) || (C122_sync_phase_word[0] <= C122_sync_phase_word[1]))
    freq_min <= C122_sync_phase_word[0];
  else
    freq_min <= C122_sync_phase_word[1];
end

reg [6:0] Alex_auto_LPF ;
always @(posedge clk_ad9866) begin 
  if      (freq_max > 32'h64000000) Alex_auto_LPF <= 7'b0010000;  // >30.0MHz, 6m LPF
  else if (freq_max > 32'h4C000000) Alex_auto_LPF <= 7'b0100000;  // >22.8MHz, 12/10m LPF
  else if (freq_max > 32'h34000000) Alex_auto_LPF <= 7'b1000000;  // >15.6MHz, 17/15m LPF
  else if (freq_max > 32'h1C000000) Alex_auto_LPF <= 7'b0000001;  // > 8.4MHz, 30/20m LPF 
  else if (freq_max > 32'h10000000) Alex_auto_LPF <= 7'b0000010;  // > 4.8MHz, 60/40m LPF
  else if (freq_max > 32'h08000000) Alex_auto_LPF <= 7'b0000100;  // > 2.4MHz, 80m LPF
  else                              Alex_auto_LPF <= 7'b0001000;  // others  ,160m LPF
end 

reg [5:0] Alex_auto_HPF ;
always @(posedge clk_ad9866) begin
  if      (freq_min < 32'h08000000) Alex_auto_HPF <= 6'b000000; // < 2.4MHz, bypass
  else                              Alex_auto_HPF <= 6'b100000; // others, 3.5MHz HPF
end

wire [6:0] select_LPF = Alex_manual ? Alex_manual_LPF : Alex_auto_LPF;  // to i2c
wire [5:0] select_HPF = Alex_manual ? Alex_manual_HPF : Alex_auto_HPF;  // to i2c

reg [1:0] FPGA_PTT_keyer_d ;
always @(posedge clk_ad9866)
  FPGA_PTT_keyer_d <= {FPGA_PTT_keyer_d[0], FPGA_PTT_keyer}; // adjust timing

assign select_HPF_LPF ={select_HPF[5] & ~FPGA_PTT_keyer_d[1], // HPF 3.5MHz (Only Receiving)
                        select_LPF[5], // LPF 12/10m
                        select_LPF[6], // LPF 17/15m
                        select_LPF[0], // LPF 30/20m
                        select_LPF[1], // LPF 60/40m
                        select_LPF[2], // LPF 80m
                        select_LPF[3], // LPF 160m
                      } ;

// ============================================================================== //
//		Cooling Fan control
// ============================================================================== //

reg cooling_enb ;
always @(posedge clk_ad9866)
  case (IF_Cooling) 
    6: begin
        cooling_enb <= (AIN5 <= 12'd942 )? 1'b0: // <25C,OFF
                       (AIN5 >= 12'd1005)? 1'b1: // >30C,ON
                       cooling_enb ;
	    end
    5: begin
        cooling_enb <= (AIN5 <= 12'd1005)? 1'b0: // <30C,OFF
                       (AIN5 >= 12'd1068)? 1'b1: // >35C,ON
                       cooling_enb ;
		 end
	 7:
        cooling_enb <= 1'b1 ; // always ON
   default:
        cooling_enb <= 1'b0 ;	// always OFF
  endcase

assign clk_recovered = cooling_enb ;

// ============================================================================== //
//     External Amplifier Band Control 
// ============================================================================== //
reg [31:0] TxFreq ;
always @ (posedge clk_ad9866) begin
  if (basewrite[0] && (addr==6'h01))
    TxFreq <= data;
end

wire ExtAMP_txd;
ExtAmp ExtAmp(
  .clk(clk_ad9866),
  .freq(TxFreq),
  .uart_txd(ExtAMP_txd)  // BAND (TxD)
) ;

// ============================================================================== //
//     External ATU Control 
// ============================================================================== //
wire ATU_Start;
ExtTuner ExtTuner(
  .clk(clk_ad9866),
  .auto_tune(~ExtTUNER_disable & IF_autoTune),
  .ATU_Status(io_led_d5), // ATU Status
  .ATU_Start(ATU_Start),  // ATU Start
  .mox_in(mox),           // mox from PC
  .mox_out(mox_out)
);

// ============================================================================== //
//     LED PORT function
// ============================================================================== //
reg [2:0] io_check;
reg ExtAMP_disable;
reg ExtTUNER_disable;

always @(posedge clk_ad9866 or negedge resetcounter[15]) begin
  if (!resetcounter[15]) begin
    io_check         <= 3'b0;
    ExtAMP_disable   <= 1'b0;
    ExtTUNER_disable <= 1'b0;
  end else begin
    io_check <= {io_check[1:0],1'b1};
    if (io_check[2:1]==2'b01) begin      // LED Port D3/D5 check
      ExtAMP_disable   <= io_led_d3;     // if "H", ExtAMP circuit is not installed
      ExtTUNER_disable <= io_led_d5;     // if "H", ExtTUNER circuit is not installed
    end
  end
end

reg  io_led_d2_o;
reg  io_led_d3_o;
reg  io_led_d4_o;
reg  io_led_d5_o;

always @(posedge clk_ad9866)
  case({ExtAMP_disable,ExtTUNER_disable})
    2'b00: begin
             io_led_d2_o <= ExtAMP_txd;
             io_led_d4_o <= ATU_Start;
           end
    2'b01: begin
             io_led_d2_o <= ExtAMP_txd;
             io_led_d4_o <= leds[4] & leds[5];  // this_MAC + run_sync
             io_led_d5_o <= leds[0] & leds[3];  // rxclipp  + rxclipn
           end
    2'b10: begin
             io_led_d2_o <= leds[4] & leds[5];  // this_MAC + run_sync
             io_led_d3_o <= leds[0] & leds[3];  // rxclipp  + rxclipn
             io_led_d4_o <= ATU_Start;
           end
    default: begin
             io_led_d2_o <= leds[4];            // this_MAC
             io_led_d3_o <= leds[5];            // run_sync
             io_led_d4_o <= leds[0];            // rxclipp
             io_led_d5_o <= leds[3];            // rxclipn
           end
  endcase

assign io_led_d2 = io_led_d2_o;
assign io_led_d3 = ExtAMP_disable   ? io_led_d3_o : 1'bz;
assign io_led_d4 = io_led_d4_o;
assign io_led_d5 = ExtTUNER_disable ? io_led_d5_o : 1'bz;

// ============================================================================== //

endmodule
