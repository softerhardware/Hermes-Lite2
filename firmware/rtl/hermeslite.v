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
  output          clk_recovered,
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
  output          io_led_d2,
  output          io_led_d3,
  output          io_led_d4,
  output          io_led_d5,
  input           io_lvds_rxn,
  input           io_lvds_rxp,
  input           io_lvds_txn,
  input           io_lvds_txp,
  input           io_cn8,
  input           io_cn9,
  input           io_cn10,
  inout           io_adc_scl,
  inout           io_adc_sda,
  inout           io_scl2,
  inout           io_sda2,
  input           io_db1_2,       // BETA2,BETA3: io_db24
  input           io_db1_3,       // BETA2,BETA3: io_db22_3
  input           io_db1_4,       // BETA2,BETA3: io_db22_2
  output          io_db1_5,       // BETA2,BETA3: io_cn4_6
  input           io_db1_6,       // BETA2,BETA3: io_cn4_7    
  input           io_phone_tip,   // BETA2,BETA3: io_cn4_2
  input           io_phone_ring,  // BETA2,BETA3: io_cn4_3
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
localparam IP = {8'd0,8'd0,8'd0,8'd0};

// ADC Oscillator
localparam CLK_FREQ = 76800000;




// Experimental Predistort On=1 Off=0
localparam PREDISTORT = 0;

`ifdef BETA2
  localparam  Hermes_serialno = 8'd40;     // Serial number of this version
`else
  localparam  Hermes_serialno = 8'd60;     // Serial number of this version
`endif

localparam Penny_serialno = 8'd00;      // Use same value as equ1valent Penny code
localparam Merc_serialno = 8'd00;       // Use same value as equivalent Mercury code

localparam RX_FIFO_SZ  = 512;          // 16 by 4096 deep RX FIFO
localparam TX_FIFO_SZ  = 1024;          // 16 by 1024 deep TX FIFO
localparam SP_FIFO_SZ = 2048;           // 16 by 8192 deep SP FIFO, was 16384 but wouldn't fit

localparam RFSZ = clogb2(RX_FIFO_SZ-1);  // number of bits needed to hold 0 - (RX_FIFO_SZ-1)
localparam TFSZ = clogb2(TX_FIFO_SZ-1);  // number of bits needed to hold 0 - (TX_FIFO_SZ-1)
localparam SFSZ = clogb2(SP_FIFO_SZ-1);  // number of bits needed to hold 0 - (SP_FIFO_SZ-1)

localparam NR = 3; // Recievers
localparam NT = 1; // Transmitters


logic   [5:0]   cmd_addr;
logic  [31:0]   cmd_data;
logic           cmd_rqst;
logic           cmd_ack;


// Individual acknowledges
logic           cmd_ack_i2c, cmd_ack_radio, cmd_ack_ad9866;

logic FPGA_PTT;
logic [7:0] AssignNR;         // IP address read from EEPROM


logic           mox = 1'b0;
logic           mox_next;

logic           resp_rqst = 1'b0;
logic           resp_rqst_next;

logic   [5:0]   addr = 6'h0;
logic   [5:0]   addr_next;

logic   [31:0]  data = 32'h00;
logic   [31:0]  data_next;

logic   [2:0]   IF_SYNC_state;
logic   [2:0]   IF_SYNC_state_next;

logic   [7:0]   IF_SYNC_frame_cnt;  // 256-4 words = 252 words
logic   [7:0]   IF_SYNC_frame_cnt_next;

logic   [2:0]   basewrite = 3'b000; // Shift register to delay write 
logic           basewrite_next;


logic   [35:0]  dsiq_rdata;
logic           dsiq_rreq;    // controls reading of fifo
logic           dsiq_rempty;
logic   [15:0]  IF_PHY_data;
logic           dsiq_wreq;
logic   [1:0]   dsiq_tlasttid;

logic   [35:0]  dslr_rdata;
logic           dslr_rreq;    // controls reading of fifo
logic           dslr_rempty;
logic           dslr_wreq;

logic  [29:0]   rx_tdata;
logic  [ 4:0]   rx_tid;
logic           rx_tlast;
logic           rx_treadyn;
logic           rx_tvalid;

logic  [35:0]   usiq_q;
logic  [29:0]   usiq_tdata;
logic  [ 4:0]   usiq_tid;
logic           usiq_tlast;
logic           usiq_tready;
logic           usiq_tvalidn;

logic    [4:0]  IF_last_chan;

logic           PHY_wrfull;
logic           IF_PHY_rdempty;
logic           IF_PHY_drdy;

logic           response_inp_tready;
logic   [37:0]  response_out_tdata;
logic           response_out_tvalid;
logic           resposne_out_tready;


localparam SYNC_IDLE    = 3'h0,
           SYNC_START   = 3'h1,
           SYNC_RX_1_2  = 3'h2,
           SYNC_RX_3_4  = 3'h3,
           SYNC_FINISH1 = 3'h4,
           SYNC_FINISH2 = 3'h5,
           SYNC_FINISH3 = 3'h6,
           SYNC_FINISH4 = 3'h7;




assign AssignNR = NR[7:0];

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


assign clk_recovered = 1'b0;


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




assign cwkey_i = io_phone_tip;
assign ptt_i = io_phone_ring;



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

dcfifo_mixed_widths #(
  .intended_device_family("Cyclone IV E"),
  .lpm_numwords(16384),
  .lpm_showahead ("OFF"),
  .lpm_type("dcfifo_mixed_widths"),
  .lpm_width(8),
  .lpm_widthu(14), 
  .lpm_widthu_r(13), 
  .lpm_width_r(16),
  .overflow_checking("ON"),
  .rdsync_delaypipe(4),
  .read_aclr_synch("OFF"),
  .underflow_checking("ON"),
  .use_eab("ON"),
  .write_aclr_synch("OFF"),
  .wrsync_delaypipe(4)
) dseth_fifo_i (
  .wrclk (clock_ethrxint),
  .wrreq (Rx_enable),  
  .wrfull (PHY_wrfull),
  .wrempty (),
  .wrusedw (),
  .data (Rx_fifo_data),

  .rdclk (clk_ad9866),
  .rdreq (IF_PHY_drdy),
  .rdfull (),
  .rdempty (IF_PHY_rdempty),
  .rdusedw (),
  .q ({IF_PHY_data[7:0],IF_PHY_data[15:8]}),

  .aclr (rst | PHY_wrfull),
  .eccstatus ()
);


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
cdc_sync #(1) reset_C122 (.siga(rst), .rstb(rst), .clkb(clk_ad9866), .sigb(C122_rst));

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


// AD9866 Interface
logic [11:0]    rx_data;
logic [11:0]    tx_data;

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

  .cmd_addr(cmd_addr),
  .cmd_data(cmd_data),
  .cmd_rqst(cmd_rqst),
  .cmd_ack(cmd_ack_ad9866)
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


wire   [23:0]     rx_I [0:NR-1];
wire   [23:0]     rx_Q [0:NR-1];
wire              strobe [0:NR-1];

wire   [47:0]     IF_IQ_Data;



radio #(
  .NR(NR), 
  .NT(NT),
  .PREDISTORT(PREDISTORT),
  .CLK_FREQ(CLK_FREQ)
) 
radio_i 
(
  .clk_ad9866(clk_ad9866),

  .ptt(FPGA_PTT),

  // Transmit
  .tx_tdata({dsiq_rdata[15:0],dsiq_rdata[33:18]}),
  .tx_tid({dsiq_rdata[34],dsiq_rdata[17:16]}),
  .tx_tlast(dsiq_rdata[35]),
  .tx_tready(dsiq_rreq),
  .tx_tvalid(~dsiq_rempty),

  .tx_cw_key(cwkey),
  .tx_cw_level(cwlevel),
  .tx_data_dac(tx_data),

  // Optional Audio Stream
  .lr_tdata({dslr_rdata[15:0],dslr_rdata[33:18]}),
  .lr_tid({dslr_rdata[34],dslr_rdata[17:16]}),
  .lr_tlast(dslr_rdata[35]),
  .lr_tready(dslr_rreq),
  .lr_tvalid(~dslr_rempty),

  // Receive
  .rx_data_adc(rx_data),

  .rx_tdata(rx_tdata),
  .rx_tid(rx_tid),
  .rx_tlast(rx_tlast),
  .rx_tready(~rx_treadyn),
  .rx_tvalid(rx_tvalid),

  // Command Slave
  .cmd_addr(cmd_addr),
  .cmd_data(cmd_data),
  .cmd_rqst(cmd_rqst),
  .cmd_ack(cmd_ack_radio)
);

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

//----------------------------------------------------------------------------
//     Tx_fifo Control - creates IF_tx_fifo_wdata and IF_tx_fifo_wreq signals
//----------------------------------------------------------------------------

wire     [15:0] IF_tx_fifo_wdata;           // LTC2208 ADC uses this to send its data to Tx FIFO
wire            IF_tx_fifo_wreq;            // set when we want to send data to the Tx FIFO
wire            IF_tx_fifo_full;
wire [TFSZ-1:0] IF_tx_fifo_used;
wire            IF_tx_fifo_rreq;
wire            IF_tx_fifo_empty;

wire [RFSZ-1:0] dsiq_used;            // read side count
wire            dsiq_full;

wire            clean_dash;                 // debounced dash key
wire            clean_dot;                  // debounced dot key

wire     [11:0] Penny_ALC;
wire            IF_tx_fifo_clr;

assign Penny_ALC = AIN5;

wire VNA_start = VNA && basewrite[0] && (addr == 6'h01);  // indicates a frequency change for the VNA.


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


Hermes_Tx_fifo_ctrl #(.TX_FIFO_SZ(TX_FIFO_SZ)) TXFC (
  .IF_reset(rst), 
  .IF_clk(clk_ad9866), 

  .Tx_fifo_wdata(IF_tx_fifo_wdata), 
  .Tx_fifo_wreq(IF_tx_fifo_wreq), 
  .Tx_fifo_full(IF_tx_fifo_full),
  .Tx_fifo_used(IF_tx_fifo_used), 
  .Tx_fifo_clr(IF_tx_fifo_clr), 

  // Receiver data to transmit to host PC via ethernet
  .usiq_tdata_iqflag(usiq_tdata[29]),
  .usiq_tdata_chan(usiq_tdata[28:24]),
  .usiq_tdata_iq(usiq_tdata[23:0]),
  .usiq_tlast(usiq_tlast),
  .usiq_tready(usiq_tready),
  .usiq_tvalid(~usiq_tvalidn),

  // Channel select
  .IF_last_chan(IF_last_chan), 

  .clean_dash(clean_dash), 
  .clean_dot(clean_dot), 
  .clean_PTT_in(cwkey | clean_ptt), 
  .ADC_OVERLOAD(OVERFLOW),
  .Penny_serialno(Penny_serialno), 
  .Merc_serialno(Merc_serialno), 
  .Hermes_serialno(Hermes_serialno), 
  .Penny_ALC(Penny_ALC), 
  .AIN1(AIN1), 
  .AIN2(AIN2),
  .AIN3(AIN3), 
  .AIN4(AIN4),
  .AIN6(AIN6), 
  .IO4(IO4),
  .IO5(IO5),
  .IO6(IO6),
  .IO8(IO8),
  .VNA_start(VNA_start),
  .VNA(VNA),

  // Protocol extension response
  .response_out_tdata(response_out_tdata),
  .response_out_tvalid(response_out_tvalid),
  .response_out_tready(response_out_tready) 
);


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
//   
//---------------------------------------------------------

generate 

if(PREDISTORT==1) begin: PD2

  dcfifo_mixed_widths #(
    .intended_device_family("Cyclone IV E"),
    .lpm_numwords(512), // 256
    .lpm_showahead ("ON"),
    .lpm_type("dcfifo_mixed_widths"),
    .lpm_width(18),
    .lpm_widthu(9), // 8
    .lpm_widthu_r(8), // 7
    .lpm_width_r(36),
    .overflow_checking("ON"),
    .rdsync_delaypipe(4),
    .underflow_checking("ON"),
    .use_eab("ON"),
    .wrsync_delaypipe(4)
  ) dslr_fifo_i (
    .wrclk (clk_ad9866),
    .wrreq (dslr_wreq),  
    .wrfull (),
    .wrempty (),
    .wrusedw (),
    // Use iq here to save wires
    .data ({dsiq_tlasttid,IF_PHY_data}),
  
    .rdclk (clk_ad9866),
    .rdreq (dslr_rreq),
    .rdfull (),
    .rdempty (dslr_rempty),
    .rdusedw (),
    .q (dslr_rdata),
  
    .aclr (1'b0),
    .eccstatus ()
  );

end else begin
  assign dslr_rempty = 1'b1;
  assign dslr_rdata = 36'h0;

end
endgenerate


dcfifo_mixed_widths #(
  .intended_device_family("Cyclone IV E"),
  .lpm_numwords(512), // 256
  .lpm_showahead ("ON"),
  .lpm_type("dcfifo_mixed_widths"),
  .lpm_width(18),
  .lpm_widthu(9), // 8
  .lpm_widthu_r(8), // 7
  .lpm_width_r(36),
  .overflow_checking("ON"),
  .rdsync_delaypipe(4),
  .underflow_checking("ON"),
  .use_eab("ON"),
  .wrsync_delaypipe(4)
) dsiq_fifo_i (
  .wrclk (clk_ad9866),
  .wrreq (dsiq_wreq),  
  .wrfull (dsiq_full),
  .wrempty (),
  .wrusedw (dsiq_used),
  .data ({dsiq_tlasttid,IF_PHY_data}),

  .rdclk (clk_ad9866),
  .rdreq (dsiq_rreq),
  .rdfull (),
  .rdempty (dsiq_rempty),
  .rdusedw (),
  .q (dsiq_rdata),

  .aclr (1'b0),
  .eccstatus ()
);


dcfifo #(
  .intended_device_family("Cyclone IV E"),
  .lpm_numwords(256), 
  .lpm_showahead ("ON"),
  .lpm_type("dcfifo"),
  .lpm_width(36),
  .lpm_widthu(8), 
  .overflow_checking("ON"),
  .rdsync_delaypipe(4),
  .underflow_checking("ON"),
  .use_eab("ON"),
  .wrsync_delaypipe(4)
) usiq_fifo_i (
  .wrclk (clk_ad9866),
  .wrreq (rx_tvalid),
  .wrfull (rx_treadyn),
  .wrempty (),
  .wrusedw (),
  // synchronous rx_tid tied to 0 for now
  .data ({rx_tlast,rx_tid,rx_tdata}),

  .rdclk (clk_ad9866),
  .rdreq (usiq_tready),
  .rdfull (),
  .rdempty (usiq_tvalidn),
  .rdusedw (),
  .q (usiq_q),

  .aclr (1'b0),
  .eccstatus ()  
);

assign usiq_tlast = usiq_q[35];
assign usiq_tid = usiq_q[34:30];
assign usiq_tdata = usiq_q[29:0];


//------------------------------------------------------------
//   Sync and  C&C  Detector
//------------------------------------------------------------

/*
  Read the value of IF_PHY_data whenever IF_PHY_drdy is set.
  Look for sync and if found decode the C&C data.
  Then send subsequent data to Rx FIF0 until end of frame.

*/

// State
always @ (posedge clk_ad9866) begin
  if (rst) begin
    IF_SYNC_state <=  SYNC_IDLE;
  end else begin
    IF_SYNC_state <=  IF_SYNC_state_next;
  end

  resp_rqst <= resp_rqst_next;
  addr <= addr_next;
  mox <= mox_next;
  data <= data_next;
  basewrite <= {basewrite[1:0],basewrite_next};
  IF_SYNC_frame_cnt <= IF_SYNC_frame_cnt_next;

end

// FSM Combinational
always @* begin

  // Next State
  resp_rqst_next = resp_rqst;
  addr_next = addr;
  mox_next = mox;
  data_next = data;
  IF_SYNC_frame_cnt_next = IF_SYNC_frame_cnt;
  IF_SYNC_state_next = IF_SYNC_state;
  basewrite_next = 1'b0;

  // Combinational output
  dsiq_wreq = 1'b0; // Note: Sync bytes not saved in Rx_fifo
  dsiq_tlasttid = 2'b00;

  dslr_wreq = 1'b0;


  case (IF_SYNC_state)
    // state SYNC_IDLE  - loop until we find start of sync sequence
    SYNC_IDLE: begin
      if (IF_PHY_drdy & (IF_PHY_data == 16'h7F7F)) begin
        IF_SYNC_state_next = SYNC_START;   // possible start of sync
      end
    end

    // check for 0x7F  sync character & get Rx control_0
    SYNC_START: begin
      if (IF_PHY_drdy) begin
        if (IF_PHY_data[15:8] == 8'h7F) begin
          resp_rqst_next = IF_PHY_data[7];
          addr_next = IF_PHY_data[6:1];
          mox_next = IF_PHY_data[0];
          IF_SYNC_state_next = SYNC_RX_1_2;  // have sync so continue
        end else begin
          IF_SYNC_state_next = SYNC_IDLE;    // start searching for sync sequence again
        end
      end
      IF_SYNC_frame_cnt_next = 0;
    end

    SYNC_RX_1_2: begin
      if (IF_PHY_drdy) begin
        data_next = {IF_PHY_data,data[15:0]};
        IF_SYNC_state_next = SYNC_RX_3_4;
      end
    end

    SYNC_RX_3_4: begin
      if (IF_PHY_drdy) begin
        data_next = {data[31:16],IF_PHY_data};
        basewrite_next = 1'b1;
        IF_SYNC_state_next = SYNC_FINISH1;
      end
    end

    // Remainder of data goes to Rx_fifo, re-start looking
    // for a new SYNC at end of this frame.
    // Note: due to the use of IF_PHY_drdy data will only be written to the
    // Rx fifo if there is room. Also the frame_count will only be incremented if IF_PHY_drdy is true.
    SYNC_FINISH1: begin
      dslr_wreq  = IF_PHY_drdy;
      dsiq_tlasttid = addr[1:0];
      if (IF_PHY_drdy) begin
        if (IF_SYNC_frame_cnt == ((512-8)/2)-1) begin  // frame ended, go get sync again
          IF_SYNC_state_next = SYNC_IDLE;
        end else begin
          IF_SYNC_frame_cnt_next = IF_SYNC_frame_cnt + 1'b1;
          IF_SYNC_state_next = SYNC_FINISH2;
        end
      end
    end

    SYNC_FINISH2: begin
      dslr_wreq  = IF_PHY_drdy;
      dsiq_tlasttid = {1'b1,addr[2]};
      if (IF_PHY_drdy) begin
        if (IF_SYNC_frame_cnt == ((512-8)/2)-1) begin  // frame ended, go get sync again
          IF_SYNC_state_next = SYNC_IDLE;
        end else begin
          IF_SYNC_frame_cnt_next = IF_SYNC_frame_cnt + 1'b1;
          IF_SYNC_state_next = SYNC_FINISH3;
        end
      end
    end

    SYNC_FINISH3: begin
      dsiq_wreq  = IF_PHY_drdy;
      dsiq_tlasttid = addr[1:0];
      if (IF_PHY_drdy) begin
        if (IF_SYNC_frame_cnt == ((512-8)/2)-1) begin  // frame ended, go get sync again
          IF_SYNC_state_next = SYNC_IDLE;
        end else begin
          IF_SYNC_frame_cnt_next = IF_SYNC_frame_cnt + 1'b1;
          IF_SYNC_state_next = SYNC_FINISH4;
        end
      end
    end

    SYNC_FINISH4: begin
      dsiq_wreq  = IF_PHY_drdy;
      dsiq_tlasttid = {1'b1,addr[2]};
      if (IF_PHY_drdy) begin
        if (IF_SYNC_frame_cnt == ((512-8)/2)-1) begin  // frame ended, go get sync again
          IF_SYNC_state_next = SYNC_IDLE;
        end else begin
          IF_SYNC_frame_cnt_next = IF_SYNC_frame_cnt + 1'b1;
          IF_SYNC_state_next = SYNC_FINISH1;
        end
      end
    end

  endcase
end

wire have_room;
assign have_room = (dsiq_used < RX_FIFO_SZ - ((512-8)/2)) ? 1'b1 : 1'b0;  // the /2 is because we send 16 bit values

// prevent read from PHY fifo if empty and writing to Rx fifo if not enough room
assign  IF_PHY_drdy = have_room & ~IF_PHY_rdempty;


reg         VNA;                    // Selects VNA mode when set.
reg         IF_PA_enable;
reg         IF_TR_disable;


always 
@ (posedge clk_ad9866)
begin   
  if (rst)
  begin // set up default values - 0 for now
    // RX_CONTROL_1
    IF_last_chan       <= 5'b00000;    // default single receiver
    VNA                <= 1'b0;      // VNA disabled
    IF_PA_enable       <= 1'b0;
    IF_TR_disable      <= 1'b0;

  end
  else if (basewrite[0])                  // all Rx_control bytes are ready to be saved
  begin                                         // Need to ensure that C&C data is stable
    if (addr == 6'h00)
    begin
      // RX_CONTROL_1
      IF_last_chan        <= data[7:3]; // number of IQ streams to send to PC
    end
    if (addr == 6'h09)
    begin
      VNA                 <= data[23];      // 1 = enable VNA mode
      IF_PA_enable      <= data[19];
      IF_TR_disable       <= data[18];
    end
  end
end



wire clean_txinhibit;
debounce de_txinhibit(.clean_pb(clean_txinhibit), .pb(~io_cn8), .clk(clk_ad9866));

assign FPGA_PTT = (mox | cwkey | clean_ptt) & ~clean_txinhibit; // mox only updated when we get correct sync sequence


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
debounce de_cwkey(.clean_pb(clean_cwkey), .pb(~cwkey_i), .clk(clk_ad9866));

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

assign io_db1_5 = cwkey;

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


assign io_led_d2 = leds[4];
assign io_led_d3 = leds[5];
assign io_led_d4 = leds[0];
assign io_led_d5 = leds[3];




// FIXME: Sequence power
// FIXME: External TR won't work in low power mode
`ifdef BETA2
assign pa_tr = FPGA_PTT & (IF_PA_enable | ~IF_TR_disable);
assign pa_en = FPGA_PTT & IF_PA_enable;
assign pwr_envpa = FPGA_PTT;
`else
assign pwr_envbias = FPGA_PTT & IF_PA_enable;
assign pwr_envop = FPGA_PTT;
assign pa_exttr = FPGA_PTT;
assign pa_inttr = FPGA_PTT & (IF_PA_enable | ~IF_TR_disable);
assign pwr_envpa = FPGA_PTT & IF_PA_enable;
`endif

assign rffe_rfsw_sel = IF_PA_enable;

wire scl1_i, scl1_t, scl1_o, sda1_i, sda1_t, sda1_o;
wire scl2_i, scl2_t, scl2_o, sda2_i, sda2_t, sda2_o;
wire scl3_i, scl3_t, scl3_o, sda3_i, sda3_t, sda3_o;

i2c i2c_i (
  .clk(clock_2_5MHz),
  .clock_76p8_mhz(clk_ad9866),
  .rst(clk_i2c_rst),
  .init_start(clk_i2c_start),

  .cmd_addr(cmd_addr),
  .cmd_data(cmd_data),
  .cmd_rqst(cmd_rqst),
  .cmd_ack(cmd_ack_i2c),

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

assign cmd_addr = addr;
assign cmd_data = data;
assign cmd_rqst = basewrite[1];

assign cmd_ack = response_inp_tready & resp_rqst & (cmd_ack_i2c | cmd_ack_radio | cmd_ack_ad9866);

axis_fifo #(.ADDR_WIDTH(1), .DATA_WIDTH(38)) response_fifo (
  .clk(clk_ad9866),
  .rst(rst),
  .input_axis_tdata({cmd_addr,cmd_data}),
  .input_axis_tvalid(cmd_ack),
  .input_axis_tready(response_inp_tready),
  .input_axis_tlast(1'b0),
  .input_axis_tuser(1'b0),

  .output_axis_tdata(response_out_tdata),
  .output_axis_tvalid(response_out_tvalid),
  .output_axis_tready(response_out_tready),
  .output_axis_tlast(),
  .output_axis_tuser()
);

function integer clogb2;
input [31:0] depth;
begin
  for(clogb2=0; depth>0; clogb2=clogb2+1)
  depth = depth >> 1;
end
endfunction


endmodule
