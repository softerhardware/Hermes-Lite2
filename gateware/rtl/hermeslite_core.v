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

// (C) Steve Haynal KF7O 2014-2019
// This RTL originated from www.openhpsdr.org and has been modified to support
// the Hermes-Lite hardware described at http://github.com/softerhardware/Hermes-Lite2.

module hermeslite_core (
  // Power
  output       pwr_clk3p3                ,
  output       pwr_clk1p2                ,
  output       pwr_envpa                 ,
  output       pwr_envop                 ,
  output       pwr_envbias               ,
  // Ethernet PHY
  input        phy_clk125                ,
  output [3:0] phy_tx                    ,
  output       phy_tx_en                 ,
  output       phy_tx_clk                ,
  input  [3:0] phy_rx                    ,
  input        phy_rx_dv                 ,
  input        phy_rx_clk                ,
  input        phy_rst_n                 ,
  inout        phy_mdio                  ,
  output       phy_mdc                   ,
  // Clock
  inout        clk_sda1                  ,
  inout        clk_scl1                  ,
  // RF Frontend
  output       rffe_ad9866_rst_n         ,
  output [5:0] rffe_ad9866_tx            ,
  input  [5:0] rffe_ad9866_rx            ,
  input        rffe_ad9866_rxsync        ,
  input        rffe_ad9866_rxclk         ,
  output       rffe_ad9866_txquiet_n     ,
  output       rffe_ad9866_txsync        ,
  output       rffe_ad9866_sdio          ,
  output       rffe_ad9866_sclk          ,
  output       rffe_ad9866_sen_n         ,
  input        rffe_ad9866_clk76p8       ,
  output       rffe_rfsw_sel             ,
  output       rffe_ad9866_mode          ,
  output       rffe_ad9866_pga5          ,
  // IO
  output       io_led_run                ,
  output       io_led_tx                 ,
  output       io_led_adc75              ,
  output       io_led_adc100             ,
  //
  output       io_tx_envelope_pwm_out    ,
  output       io_tx_envelope_pwm_out_inv,
  //
  input        io_tx_inhibit             ,
  input        io_id_hermeslite          ,
  input        io_alternate_mac          ,
  //
  inout        io_adc_scl                ,
  inout        io_adc_sda                ,
  inout        io_scl2                   ,
  inout        io_sda2                   ,
  output       io_uart_txd               ,
  input        io_uart_rxd               ,
  output       io_cw_keydown             ,
  input        io_phone_tip              ,
  input        io_phone_ring             ,
  input        io_atu_ack                ,
  output       io_atu_req                ,
  output       pa_inttr                  ,
  output       pa_exttr                  ,
  // AK4951
  output       pa_exttr_clone            , // AK4951 Companion Board V3
  input        io_ptt_in                 , // AK4951 Companion Board V3
  output       i2s_pdn                   ,
  output       i2s_bck                   ,
  output       i2s_lrck                  ,
  input        i2s_miso                  ,
  output       i2s_mosi                  ,
  //
  output       fan_pwm                   ,
  input  [1:0] linkrx                    ,
  output [1:0] linktx                    ,
  output [3:0] debug_out
);


// PARAMETERS
parameter       BOARD = 5;
parameter       IP = {8'd0,8'd0,8'd0,8'd0};
parameter       MAC = {8'h00,8'h1c,8'hc0,8'ha2,8'h13,8'hdd};
parameter       NR = 4; // Recievers
parameter       NT = 1; // Transmitters
parameter       CLK_FREQ = 76800000;

// UART Type 0 is none, 1 is JI1UDD HR50
parameter       UART = 0;

// ATU Type 0 is none, 1 is JI1UDD ATU
parameter       ATU = 0;

parameter       FAN = 0;    // Generate fan support
parameter       PSSYNC = 0; // Generate power supply sync frequency

parameter       CW = 0; // CW Support

// Downstream audio channel usage:
//   0=not used, 1=predistortion, 2=TX envelope PWM
//   when using the TX envelope PWM reduce the number of receivers (NR) above by 1
parameter       LRDATA = 0;

// Use ASMII for EEPROM configuration
parameter       ASMII = 0;

parameter       HL2LINK = 0;

parameter       FAST_LNA = 0; // Support for fast LNA setting, TX/RX values

parameter       AK4951 = 0;
parameter       EXTENDED_RESP = 1;
parameter       EXTENDED_DEBUG_RESP = 0;

parameter       DSIQ_FIFO_DEPTH = 16384;

parameter       BYPASS_VERSA = 0;

localparam      TUSERWIDTH = (AK4951 == 1) ? 16 : 2;

localparam      VERSION_MAJOR = (BOARD==2) ? 8'd54 : 8'd74;
localparam      VERSION_MINOR = 8'd100;

logic   [5:0]   cmd_addr;
logic   [31:0]  cmd_data;
logic           cmd_cnt;
logic           cmd_is_alt;
logic           cmd_resprqst;

logic   [5:0]   ds_cmd_addr;
logic   [31:0]  ds_cmd_data;
logic           ds_cmd_cnt;
logic           ds_cmd_is_alt;
logic   [1:0]   ds_cmd_mask;
logic           ds_cmd_resprqst;
logic           ds_cmd_ptt, ds_cmd_ptt_ad9866sync;

logic           tx_on, tx_on_iosync;
logic           cw_on, cw_on_iosync;
logic           cw_keydown, cw_keydown_ad9866sync;
logic           ext_ptt, ext_ptt_ad9866sync;
logic   [18:0]  cw_profile;

logic   [7:0]   dseth_tdata;

logic   [35:0]  dsiq_tdata;
logic           dsiq_tready;    // controls reading of fifo
logic           dsiq_tvalid;
logic           dsiq_sample, dsiq_sample_ad9866sync;
logic   [7:0]   dsiq_status;
logic           dsiq_twait;

logic           dsethiq_tvalid;
logic           dsethiq_tlast;
logic           dsethiq_tuser;

logic   [35:0]  dslr_tdata;
logic           dslr_tready;    // controls reading of fifo
logic           dslr_tvalid;
logic           dsethlr_tvalid;
logic           dsethlr_tlast;
logic           dsethlr_tuser;

logic  [23:0]   rx_tdata;
logic           rx_tlast;
logic           rx_tready;
logic           rx_tvalid;
logic  [ 1:0]   rx_tuser;

logic  [23:0]   usiq_tdata;
logic           usiq_tlast;
logic           usiq_tready;
logic           usiq_tvalid;

logic  [TUSERWIDTH-1:0]   usiq_tuser;

logic  [10:0]   usiq_tlength;

logic           bs_tvalid;
logic           bs_tready;
logic [11:0]    bs_tdata;

logic           cmd_rqst_usopenhpsdr1;
logic           cmd_rqst_dsopenhpsdr1;

logic           clock_125_mhz_0_deg;
logic           clock_125_mhz_90_deg;
logic           clock_25_mhz;
logic           clock_12p5_mhz;
logic           ethpll_locked;
logic           clock_ethtxint;
logic           clock_ethtxext;
logic           clock_ethrxint;
logic           speed_1gb;
logic           speed_1gb_clksel = 1'b0;

logic           phy_rx_clk_div2 = 1'b0;
logic           ethup;

logic           clk_ad9866;
logic           clk_ad9866_2x;
logic           clk_envelope;
logic           clk_ad9866_slow;
logic           ad9866up;
logic           ad9866_rst;

logic           run, run_sync, run_iosync, run_ad9866sync;
logic           wide_spectrum, wide_spectrum_sync;
logic           discover_port;
logic           discover_cnt;
logic           discover_rqst_usopenhpsdr1;

logic           dst_unreachable;

logic [ 1:0]    udp_tx_request;
logic [ 7:0]    udp_tx_data;
logic [10:0]    udp_tx_length;
logic           udp_tx_enable;

logic [15:0]    to_port;
logic           broadcast;
logic           udp_rx_active;
logic [ 7:0]    udp_rx_data;

logic           network_state_dhcp, network_state_fixedip;
logic [ 1:0]    network_speed;
logic           phy_connected;
logic           is_ksz9021;

logic [47:0]    local_mac;

logic           cmd_rqst_ad9866;
logic [11:0]    rx_data;
logic [11:0]    tx_data;

logic           sda1_i;
logic           sda1_o;
logic           sda1_t;
logic           scl1_i;
logic           scl1_o;
logic           scl1_t;

logic           sda2_i;
logic           sda2_o;
logic           sda2_t;
logic           scl2_i;
logic           scl2_o;
logic           scl2_t;

logic           sda3_i;
logic           sda3_o;
logic           sda3_t;
logic           scl3_i;
logic           scl3_o;
logic           scl3_t;

logic           cmd_rqst_io;
logic           clk_ctrl;

logic           rxclip, rxclip_iosync;
logic           rxgoodlvl, rxgoodlvl_iosync;
logic           rxclrstatus, rxclrstatus_ad9866sync;

logic [39:0]    resp;
logic           resp_rqst, resp_rqst_iosync;

logic           watchdog_up, watchdog_up_sync;

logic           dsethasmi_erase, dsethasmi_erase_ack;
logic           usethasmi_send_more, usethasmi_erase_done, usethasmi_ack;
logic [13:0]    asmi_cnt = 14'h0000;
logic           dsethasmi_tvalid;

logic  [31:0]   static_ip;
logic  [15:0]   alt_mac;
logic  [ 7:0]   eeprom_config;

logic           hl2_reset;

logic           qmsec_pulse, qmsec_pulse_ad9866sync;
logic           msec_pulse, msec_pulse_ethsync;

logic           atu_txinhibit, atu_txinhibit_ad9866ync;

logic        stall_req, stall_req_sync;
logic        stall_ack, stall_ack_ad9866;
logic        rst_all, rst_nco;
logic        link_running;
logic        link_master ;
logic [23:0] lm_data     ;
logic        lm_valid    ;
logic        ls_valid    ;
logic        ls_done     ;


logic        clk_i2c_rst;
logic [15:0] au_rdata   ;

logic        alt_resp_cnt              ;
logic        alt_resp_rqst_usopenhpsdr1;
logic [31:0] resp_data                 ;
logic [ 7:0] resp_control              ;
logic [11:0] temperature               ;
logic [11:0] fwdpwr                    ;
logic [11:0] revpwr                    ;
logic [11:0] bias                      ;
logic [ 7:0] control_dsiq_status       ;
logic        ds_pkt_cnt                ;
logic        ds_pkt_usopenhpsdr1       ;

logic        hl2link_rst_req, hl2link_rst_ack;

logic [15:0] debug;
//assign debug_out = debug[3:0];
logic link_error;
assign debug_out = {cmd_rqst_ad9866,debug[2],link_error,debug[0]};


/////////////////////////////////////////////////////
// Clocks

ethpll ethpll_inst (
    .inclk0   (phy_clk125),   //  refclk.clk
    .c0 (clock_125_mhz_0_deg), // outclk0.clk
    .c1 (clock_125_mhz_90_deg), // outclk1.clk
    .c2 (clk_ctrl), // outclk2.clk
    .c3 (clock_25_mhz),
    .c4 (clock_12p5_mhz),
    .locked (ethpll_locked)
);

always @(posedge clk_ctrl)
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

assign phy_tx_clk = clock_ethtxext;

always @(posedge phy_rx_clk) begin
  phy_rx_clk_div2 <= ~phy_rx_clk_div2;
end

assign clock_ethrxint = speed_1gb_clksel ? phy_rx_clk : phy_rx_clk_div2;

// Infer above as altclkctrl does not map correctly in Quartus for this case
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


// phy_rst_n will go high after ~50ms due to RC
// ethpll_locked will go high once pll is locked
assign ethup = ethpll_locked & phy_rst_n;

// ethup starts I2C configuration of the Versa
// the PLL may lock twice the frequency changes


ad9866pll ad9866pll_inst (
  .inclk0   (rffe_ad9866_clk76p8),   //  refclk.clk
  .areset   (~ethup),      //   reset.reset
  .c0 (clk_ad9866), // outclk0.clk
  .c1 (clk_ad9866_2x), // outclk1.clk
  .c2 (clk_envelope),
  .c3 (clk_ad9866_slow),
  .locked (ad9866up)
);



/////////////////////////////////////////////////////
// Network

assign local_mac = eeprom_config[6] ? {MAC[47:16],alt_mac} : {MAC[47:2],~io_alternate_mac,MAC[0]};

network network_inst(

  .clock_2_5MHz(clk_ctrl),

  .tx_clock(clock_ethtxint),
  .udp_tx_request(udp_tx_request),
  .udp_tx_length({5'h00,udp_tx_length}),
  .udp_tx_data(udp_tx_data),
  .udp_tx_enable(udp_tx_enable),
  .run(run_sync),
  .port_id(8'h00),

  .rx_clock(clock_ethrxint),
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

  .PHY_TX(phy_tx),
  .PHY_TX_EN(phy_tx_en),
  .PHY_RX(phy_rx),
  .PHY_DV(phy_rx_dv),

  .PHY_MDIO(phy_mdio),
  .PHY_MDC(phy_mdc)
);



///////////////////////////////////////////////
// Downstream ethrxint clock domain

sync_pulse sync_pulse_watchdog (
  .clock(clock_ethrxint),
  .sig_in(watchdog_up),
  .sig_out(watchdog_up_sync)
);

// CDC okay as clock is >2x faster than sig_in domain
sync_one sync_msec_pulse_eth (
  .clock(clock_ethrxint),
  .sig_in(msec_pulse),
  .sig_out(msec_pulse_ethsync)
);

sync_pulse sync_pulse_dsopenhpsdr1 (
  .clock(clock_ethrxint),
  .sig_in(cmd_cnt),
  .sig_out(cmd_rqst_dsopenhpsdr1)
);

dsopenhpsdr1 dsopenhpsdr1_i (
  .clk(clock_ethrxint),
  .eth_port(to_port),
  .eth_broadcast(broadcast),
  .eth_valid(udp_rx_active),
  .eth_data(udp_rx_data),
  .eth_unreachable(dst_unreachable),

  .discover_port(discover_port),
  .discover_cnt(discover_cnt),

  .run(run),
  .wide_spectrum(wide_spectrum),

  .watchdog_up(watchdog_up_sync),

  .msec_pulse(msec_pulse_ethsync),

  .ds_cmd_addr(ds_cmd_addr),
  .ds_cmd_data(ds_cmd_data),
  .ds_cmd_cnt(ds_cmd_cnt),
  .ds_cmd_resprqst(ds_cmd_resprqst),
  .ds_cmd_is_alt(ds_cmd_is_alt),
  .ds_cmd_mask(ds_cmd_mask),
  .ds_cmd_ptt(ds_cmd_ptt),

  .dseth_tdata(dseth_tdata),
  .dsethiq_tvalid(dsethiq_tvalid),
  .dsethiq_tlast(dsethiq_tlast),
  .dsethiq_tuser(dsethiq_tuser),
  .dsethlr_tvalid(dsethlr_tvalid),
  .dsethlr_tlast(dsethlr_tlast),

  .dsethasmi_tvalid(dsethasmi_tvalid),
  .dsethasmi_tlast(),
  .asmi_cnt(asmi_cnt),
  .dsethasmi_erase(dsethasmi_erase),
  .dsethasmi_erase_ack(dsethasmi_erase_ack),

  .ds_pkt_cnt(ds_pkt_cnt),

  .cmd_addr(cmd_addr),
  .cmd_data(cmd_data),
  .cmd_rqst(cmd_rqst_dsopenhpsdr1)
);


generate

if (NT != 0) begin

dsiq_fifo #(.depth(DSIQ_FIFO_DEPTH)) dsiq_fifo_i (
  .wr_clk(clock_ethrxint),
  .wr_tdata({dsethiq_tuser,dseth_tdata}),
  .wr_tvalid(dsethiq_tvalid),
  .wr_tready(),
  .wr_tlast(dsethiq_tlast),

  .rd_clk(clk_ad9866),
  .rd_tdata(dsiq_tdata),
  .rd_tvalid(dsiq_tvalid),
  .rd_tready(dsiq_tready),
  .rd_sample(dsiq_sample_ad9866sync),
  .rd_status(dsiq_status)
);

sync_pulse sync_pulse_dsiq_sample (
  .clock(clk_ad9866),
  .sig_in(dsiq_sample),
  .sig_out(dsiq_sample_ad9866sync)
);

end else begin
  assign dsiq_tdata = 36'b0;
  assign dsiq_tvalid = 1'b0;
  assign dsiq_status = 8'b0;
end
endgenerate


generate if (AK4951 == 0) begin

case (LRDATA)
  0: begin // Left/Right downstream (PC->Card) audio data not used
    assign dslr_tvalid = 1'b0;
    assign dslr_tdata = 36'h0;
  end
  1: begin: PD2 // TX predistortion
    // simple fifo to get predistortion tables
    dslr_fifo dslr_fifo_i (
      .wr_clk(clock_ethrxint),
      .wr_tdata({1'b0,dseth_tdata}),
      .wr_tvalid(dsethlr_tvalid),
      .wr_tready(),

      .rd_clk(clk_ad9866),
      .rd_tdata(dslr_tdata),
      .rd_tvalid(dslr_tvalid),
      .rd_tready(dslr_tready)
    );
  end
  2: begin // TX envelope PWM generation for ET/EER
    // need to use same fifo as the TX I/Q data to keep the envelope in sync
    dsiq_fifo #(.depth(DSIQ_FIFO_DEPTH)) dslr_fifo_i (
      .wr_clk(clock_ethrxint),
      .wr_tdata({1'b0,dseth_tdata}),
      .wr_tvalid(dsethlr_tvalid),
      .wr_tready(),
      .wr_tlast(dsethlr_tlast),

      .rd_clk(clk_ad9866),
      .rd_tdata(dslr_tdata),
      .rd_tvalid(dslr_tvalid),
      .rd_tready(dslr_tready)
    );
  end
endcase
end
endgenerate


///////////////////////////////////////////////
// Upstream ethtxint clock domain

sync sync_inst2(.clock(clock_ethtxint), .sig_in(run), .sig_out(run_sync));
sync sync_inst3(.clock(clock_ethtxint), .sig_in(wide_spectrum), .sig_out(wide_spectrum_sync));

sync_pulse sync_pulse_usopenhpsdr1 (
  .clock(clock_ethtxint),
  .sig_in(cmd_cnt),
  .sig_out(cmd_rqst_usopenhpsdr1)
);

sync_pulse sync_discover_usopenhpsdr1 (
  .clock(clock_ethtxint),
  .sig_in(discover_cnt),
  .sig_out(discover_rqst_usopenhpsdr1)
);

sync_pulse sync_resp_usopenhpsdr1 (
  .clock(clock_ethtxint),
  .sig_in(alt_resp_cnt),
  .sig_out(alt_resp_rqst_usopenhpsdr1)
);

sync_pulse sync_pkt_cnt_usopenhpsdr1 (
  .clock(clock_ethtxint),
  .sig_in(ds_pkt_cnt),
  .sig_out(ds_pkt_usopenhpsdr1)
);

usopenhpsdr1 #(
  .NR(NR),
  .VERSION_MAJOR(VERSION_MAJOR),
  .VERSION_MINOR(VERSION_MINOR),
  .BOARD(BOARD),
  .AK4951(AK4951),
  .EXTENDED_DEBUG_RESP(EXTENDED_DEBUG_RESP)
) usopenhpsdr1_i (
  .clk(clock_ethtxint),
  .have_ip(~(network_state_dhcp & network_state_fixedip)), // network_state is on sync 2.5 MHz domain
  .run(run_sync),
  .wide_spectrum(wide_spectrum_sync),
  .idhermeslite(io_id_hermeslite),
  .mac(local_mac),

  .discover_port(discover_port),
  .discover_rqst(discover_rqst_usopenhpsdr1),

  .udp_tx_enable(udp_tx_enable),
  .udp_tx_request(udp_tx_request),
  .udp_tx_data(udp_tx_data),
  .udp_tx_length(udp_tx_length),

  .bs_tdata(bs_tdata),
  .bs_tready(bs_tready),
  .bs_tvalid(bs_tvalid),

  .us_tdata(usiq_tdata),
  .us_tlast(usiq_tlast),
  .us_tready(usiq_tready),
  .us_tvalid(usiq_tvalid),
  .us_tuser(usiq_tuser),
  .us_tlength(usiq_tlength),

  .cmd_addr(cmd_addr),
  .cmd_data(cmd_data),
  .cmd_rqst(cmd_rqst_usopenhpsdr1),

  .resp(resp),
  .resp_rqst(resp_rqst),

  .stall_req(stall_req_sync),
  .stall_ack(stall_ack),

  .static_ip(static_ip),
  .alt_mac(alt_mac),
  .eeprom_config(eeprom_config),

  .watchdog_up(watchdog_up),

  .usethasmi_send_more(usethasmi_send_more),
  .usethasmi_erase_done(usethasmi_erase_done),
  .usethasmi_ack(usethasmi_ack),

  .ds_cmd_ptt(ds_cmd_ptt),
  .ds_pkt(ds_pkt_usopenhpsdr1),
  .ds_wait(dsiq_twait),
  .alt_resp_rqst(alt_resp_rqst_usopenhpsdr1),
  .resp_data(resp_data),
  .resp_control(resp_control),
  .temperature(temperature),
  .fwdpwr(fwdpwr),
  .revpwr(revpwr),
  .bias(bias),
  .dsiq_status(control_dsiq_status),
  .master_link_running(link_running & link_master)
);

usiq_fifo #(.AK4951(AK4951))
  usiq_fifo_i
(
  .wr_clk(clk_ad9866),
  .wr_tdata(rx_tdata),
  .wr_tvalid(rx_tvalid),
  .wr_tready(rx_tready),
  .wr_tlast(rx_tlast),
  .wr_tuser( (AK4951 == 1) ? au_rdata : rx_tuser),
  //.wr_tuser( vna? {14'b0,rx_tuser} : au_rdata ),
  .wr_aclr(rst_all),

  .rd_clk(clock_ethtxint),
  .rd_tdata(usiq_tdata),
  .rd_tvalid(usiq_tvalid),
  .rd_tready(usiq_tready),
  .rd_tlast(usiq_tlast),
  .rd_tuser(usiq_tuser),
  .rd_tlength(usiq_tlength)
);


usbs_fifo usbs_fifo_i (
  .wr_clk(clk_ad9866),
  .wr_tdata(rx_data),
  .wr_tvalid(1'b1),
  .wr_tready(),

  .rd_clk(clock_ethtxint),
  .rd_tdata(bs_tdata),
  .rd_tvalid(bs_tvalid),
  .rd_tready(bs_tready)
);


///////////////////////////////////////////////
// AD9866 clock domain

sync_pulse sync_pulse_ad9866 (
  .clock(clk_ad9866),
  .sig_in(cmd_cnt),
  .sig_out(cmd_rqst_ad9866)
);

sync_pulse sync_rxclrstatus_ad9866 (
  .clock(clk_ad9866),
  .sig_in(rxclrstatus),
  .sig_out(rxclrstatus_ad9866sync)
);

// CDC okay as clock is >2x faster than sig_in domain
sync_one sync_qmsec_pulse_ad9866 (
  .clock(clk_ad9866),
  .sig_in(qmsec_pulse),
  .sig_out(qmsec_pulse_ad9866sync)
);

// Psuedostatic
sync sync_ds_cmd_ptt_ad9866 (
  .clock(clk_ad9866),
  .sig_in(ds_cmd_ptt),
  .sig_out(ds_cmd_ptt_ad9866sync)
);

sync sync_run_ad9866 (
  .clock(clk_ad9866),
  .sig_in(run),
  .sig_out(run_ad9866sync)
);

// CDC okay as clock is >2x faster than sig_in domain
sync sync_keydown_ad9866 (
  .clock(clk_ad9866),
  .sig_in(cw_keydown),
  .sig_out(cw_keydown_ad9866sync)
);

// CDC okay as clock is >2x faster than sig_in domain
sync sync_ptt_ad9866 (
  .clock(clk_ad9866),
  .sig_in(ext_ptt),
  .sig_out(ext_ptt_ad9866sync)
);

// CDC okay as clock is >2x faster than sig_in domain
sync sync_atutxinhibit_ad9866 (
  .clock(clk_ad9866),
  .sig_in(atu_txinhibit),
  .sig_out(atu_txinhibit_ad9866sync)
);

ad9866 #(.FAST_LNA(FAST_LNA)) ad9866_i (
  .clk(clk_ad9866),
  .clk_2x(clk_ad9866_2x),

  .rst(ad9866_rst),

  .tx_data(tx_data),
  .rx_data(rx_data),
  .tx_en(tx_on & ~atu_txinhibit_ad9866sync),
  .cw_on(cw_on & ~atu_txinhibit_ad9866sync),

  .rxclip(rxclip),
  .rxgoodlvl(rxgoodlvl),
  .rxclrstatus(rxclrstatus_ad9866sync),

  .rffe_ad9866_tx(rffe_ad9866_tx),
  .rffe_ad9866_rx(rffe_ad9866_rx),
  .rffe_ad9866_rxsync(rffe_ad9866_rxsync),
  .rffe_ad9866_rxclk(rffe_ad9866_rxclk),
  .rffe_ad9866_txquiet_n(rffe_ad9866_txquiet_n),
  .rffe_ad9866_txsync(rffe_ad9866_txsync),

  .rffe_ad9866_mode(rffe_ad9866_mode),
  .rffe_ad9866_pga5(rffe_ad9866_pga5),

  // Command Slave
  .cmd_addr(cmd_addr),
  .cmd_data(cmd_data),
  .cmd_rqst(cmd_rqst_ad9866),
  .cmd_ack() // No need for ack
);

radio #(
  .NR(NR),
  .NT(NT),
  .LRDATA(LRDATA),
  .CLK_FREQ(CLK_FREQ),
  .HL2LINK(HL2LINK)
)
radio_i
(
  .clk(clk_ad9866),
  .clk_2x(clk_ad9866_2x),

  .rst_all(rst_all),
  .rst_nco(rst_nco),

  .link_running(link_running),
  .link_master(link_master),
  .lm_data(lm_data),
  .lm_valid(lm_valid),
  .ls_valid(ls_valid),
  .ls_done(ls_done),

  .ds_cmd_ptt(ds_cmd_ptt_ad9866sync),
  .run(run_ad9866sync),
  .qmsec_pulse(qmsec_pulse_ad9866sync),
  .ext_keydown(cw_keydown_ad9866sync),
  .ext_ptt(ext_ptt_ad9866sync),

  .tx_on(tx_on),
  .cw_on(cw_on),
  .cw_profile(cw_profile),
  
  // Transmit
  .tx_tdata({dsiq_tdata[7:0],dsiq_tdata[16:9],dsiq_tdata[25:18],dsiq_tdata[34:27]}),
  .tx_tlast(1'b1),
  .tx_tready(dsiq_tready),
  .tx_tvalid(dsiq_tvalid),
  .tx_tuser({dsiq_tdata[8],dsiq_tdata[17],dsiq_tdata[26],dsiq_tdata[35]}),
  .tx_twait(dsiq_twait),

  .tx_data_dac(tx_data),

  .clk_envelope(clk_envelope),
  .tx_envelope_pwm_out(io_tx_envelope_pwm_out),
  .tx_envelope_pwm_out_inv(io_tx_envelope_pwm_out_inv),

  // Optional Audio Stream
  .lr_tdata({dslr_tdata[7:0],dslr_tdata[16:9],dslr_tdata[25:18],dslr_tdata[34:27]}),
  .lr_tid(3'h0),
  .lr_tlast(1'b1),
  .lr_tready(dslr_tready),
  .lr_tvalid(dslr_tvalid),

  // Receive
  .rx_data_adc(rx_data),

  .rx_tdata(rx_tdata),
  .rx_tlast(rx_tlast),
  .rx_tready(rx_tready),
  .rx_tvalid(rx_tvalid),
  .rx_tuser(rx_tuser),

  // Command Slave
  .cmd_addr(cmd_addr),
  .cmd_data(cmd_data),
  .cmd_rqst(cmd_rqst_ad9866),
  .cmd_ack(), // No need for ack from radio yet
  .debug_out(debug)
);




///////////////////////////////////////////////
// IO clock domain


// clk_ctrl at 2.5MHz, 1Gbs ethernet at 125 MHz, implies 50 ethernet ticks
// Worst case is a bit more than 50 ethernet ticks
// Add up all the overheads and we have at 8+20+22+4+12+UDP length minimum
// space between commands

sync_pulse #(.DEPTH(2)) syncio_cmd_rqst (
  .clock(clk_ctrl),
  .sig_in(cmd_cnt),
  .sig_out(cmd_rqst_io)
);

// Clocks are really synchronous so save time
sync_pulse #(.DEPTH(2)) syncio_rqst_io (
  .clock(clk_ctrl),
  .sig_in(resp_rqst),
  .sig_out(resp_rqst_iosync)
);

sync syncio_rxclip (
  .clock(clk_ctrl),
  .sig_in(rxclip),
  .sig_out(rxclip_iosync)
);

sync syncio_rxgoodlvl (
  .clock(clk_ctrl),
  .sig_in(rxgoodlvl),
  .sig_out(rxgoodlvl_iosync)
);

sync syncio_run (
  .clock(clk_ctrl),
  .sig_in(run),
  .sig_out(run_iosync)
);

sync syncio_tx_on (
  .clock(clk_ctrl),
  .sig_in(tx_on),
  .sig_out(tx_on_iosync)
);

sync syncio_cw_on (
  .clock(clk_ctrl),
  .sig_in(cw_on),
  .sig_out(cw_on_iosync)
);

control #(
  .VERSION_MAJOR(VERSION_MAJOR),
  .UART         (UART         ),
  .ATU          (ATU          ),
  .FAN          (FAN          ),
  .PSSYNC       (PSSYNC       ),
  .CW           (CW           ),
  .FAST_LNA     (FAST_LNA     ),
  .AK4951       (AK4951       ),
  .EXTENDED_RESP(EXTENDED_RESP),
  .BYPASS_VERSA (BYPASS_VERSA )
) control_i (
  // Internal
  .clk                (clk_ctrl                   ),
  .clk_ad9866         (clk_ad9866                 ), // Just for measurement
  .clk_125            (clock_125_mhz_0_deg        ),
  .clk_slow           (clk_ad9866_slow            ),
  
  .ethup              (ethup                      ),
  .have_dhcp_ip       (~network_state_dhcp        ),
  .have_fixed_ip      (~network_state_fixedip     ),
  .network_speed      (network_speed              ),
  .is_ksz9021         (is_ksz9021                 ),
  .ad9866up           (ad9866up                   ),
  
  .rxclip             (rxclip_iosync              ),
  .rxgoodlvl          (rxgoodlvl_iosync           ),
  .rxclrstatus        (rxclrstatus                ),
  .run                (run_iosync                 ),
  .slave_link_running (link_running & ~link_master),
  
  .dsiq_status        (dsiq_status                ),
  .dsiq_sample        (dsiq_sample                ),
  
  .cmd_addr           (cmd_addr                   ),
  .cmd_data           (cmd_data                   ),
  .cmd_rqst           (cmd_rqst_io                ),
  .cmd_is_alt         (cmd_is_alt                 ),
  .cmd_requires_resp  (cmd_resprqst               ),
  
  .atu_txinhibit      (atu_txinhibit              ),
  .tx_on              (tx_on_iosync               ),
  .cw_on              (cw_on_iosync               ),
  .cw_keydown         (cw_keydown                 ),
  .ext_pttout         (ext_ptt                    ),
  
  
  .msec_pulse         (msec_pulse                 ),
  .qmsec_pulse        (qmsec_pulse                ),
  
  .resp_rqst          (resp_rqst_iosync           ),
  .resp               (resp                       ),
  
  .static_ip          (static_ip                  ),
  .alt_mac            (alt_mac                    ),
  .eeprom_config      (eeprom_config              ),
  
  // External
  .rffe_rfsw_sel      (rffe_rfsw_sel              ),
  
  // AD9866
  .rffe_ad9866_rst_n  (rffe_ad9866_rst_n          ),
  
  .rffe_ad9866_sdio   (rffe_ad9866_sdio           ),
  .rffe_ad9866_sclk   (rffe_ad9866_sclk           ),
  .rffe_ad9866_sen_n  (rffe_ad9866_sen_n          ),
  
  // Power
  .pwr_clk3p3         (pwr_clk3p3                 ),
  .pwr_clk1p2         (pwr_clk1p2                 ),
  .pwr_envpa          (pwr_envpa                  ),
  .pwr_envop          (pwr_envop                  ),
  .pwr_envbias        (pwr_envbias                ),
  
  .sda1_i             (sda1_i                     ),
  .sda1_o             (sda1_o                     ),
  .sda1_t             (sda1_t                     ),
  .scl1_i             (scl1_i                     ),
  .scl1_o             (scl1_o                     ),
  .scl1_t             (scl1_t                     ),
  
  .sda2_i             (sda2_i                     ),
  .sda2_o             (sda2_o                     ),
  .sda2_t             (sda2_t                     ),
  .scl2_i             (scl2_i                     ),
  .scl2_o             (scl2_o                     ),
  .scl2_t             (scl2_t                     ),
  
  .sda3_i             (sda3_i                     ),
  .sda3_o             (sda3_o                     ),
  .sda3_t             (sda3_t                     ),
  .scl3_i             (scl3_i                     ),
  .scl3_o             (scl3_o                     ),
  .scl3_t             (scl3_t                     ),
  
  // IO
  .io_led_run         (io_led_run                 ),
  .io_led_tx          (io_led_tx                  ),
  .io_led_adc75       (io_led_adc75               ),
  .io_led_adc100      (io_led_adc100              ),
  
  .io_tx_inhibit      (io_tx_inhibit              ),
  
  .io_uart_txd        (io_uart_txd                ),
  //.io_uart_txd        (                      ),
  .io_cw_keydown      (io_cw_keydown              ),
  
  .io_phone_tip       (io_phone_tip               ),
  .io_phone_ring      (io_phone_ring              ),
  
  .io_atu_ack         (io_atu_ack                 ),
  .io_atu_req         (io_atu_req                 ),
  
  // PA
  .pa_inttr           (pa_inttr                   ),
  .pa_exttr           (pa_exttr                   ),
  
  .hl2_reset          (hl2_reset                  ),
  
  .fan_pwm            (fan_pwm                    ),
  
  .ad9866_rst         (ad9866_rst                 ),
  
  .clk_i2c_rst        (clk_i2c_rst                ),
  .io_ptt_in          (io_ptt_in                  ),
  
  .alt_resp_cnt       (alt_resp_cnt               ),
  .resp_data          (resp_data                  ),
  .resp_control       (resp_control               ),
  .temp               (temperature                ),
  .fwdpwr             (fwdpwr                     ),
  .revpwr             (revpwr                     ),
  .bias               (bias                       ),
  .control_dsiq_status(control_dsiq_status        ),
  
  .hl2link_rst_req    (hl2link_rst_req            ),
  .hl2link_rst_ack    (hl2link_rst_ack            ),
  
  .debug              (16'h0000                   )  //(debug                      )
);


assign scl1_i = clk_scl1;
assign clk_scl1 = scl1_t ? 1'bz : scl1_o;
assign sda1_i = clk_sda1;
assign clk_sda1 = sda1_t ? 1'bz : sda1_o;

assign scl2_i = io_scl2;
assign io_scl2 = scl2_t ? 1'bz : scl2_o;
assign sda2_i = io_sda2;
assign io_sda2 = sda2_t ? 1'bz : sda2_o;

assign scl3_i = io_adc_scl;
assign io_adc_scl = scl3_t ? 1'bz : scl3_o;
assign sda3_i = io_adc_sda;
assign io_adc_sda = sda3_t ? 1'bz : sda3_o;


generate case (ASMII)

  1: begin: INCLUDEASMII
    logic [ 7:0]    asmi_data;
    logic [ 9:0]    asmi_rx_used;
    logic           asmi_rdreq;
    logic           asmi_reconfig;

    asmi_fifo asmi_fifo_i (
      .wrclk (clock_ethrxint),
      .wrreq(dsethasmi_tvalid),
      .data (dseth_tdata),
      .rdreq (asmi_rdreq),
      .rdclk (clk_ctrl),
      .q (asmi_data),
      .rdusedw(asmi_rx_used),
      .aclr(1'b0)
    );

    asmi_interface asmi_interface_i (
      .clock(clk_ctrl),
      .busy(),
      .erase(dsethasmi_erase),
      .erase_ACK(dsethasmi_erase_ack),
      .IF_Rx_used(asmi_rx_used),
      .rdreq(asmi_rdreq),
      .IF_PHY_data(asmi_data),
      .erase_done(usethasmi_erase_done),
      .erase_done_ACK(usethasmi_ack),
      .send_more(usethasmi_send_more),
      .send_more_ACK(usethasmi_ack),
      .num_blocks(asmi_cnt),
      .NCONFIG(asmi_reconfig)
    );

    remote_update remote_update_i (
      .clk(clk_ctrl),
      .rst(~ethpll_locked),
      .reboot(asmi_reconfig | hl2_reset),
      .factory( (~io_phone_tip & ~io_phone_ring) )
    );

  end

  default: begin: NOASMII

    assign usethasmi_erase_done = 1'b0;
    assign usethasmi_send_more = 1'b0;
    assign dsethasmi_erase_ack = 1'b1;

  end
endcase
endgenerate

generate
if (HL2LINK == 1) begin

  logic ds_cmd_rqst_ad9866;

  sync_pulse sync_pulse_ad9866 (
    .clock(clk_ad9866),
    .sig_in(ds_cmd_cnt),
    .sig_out(ds_cmd_rqst_ad9866)
  );

  sync sync_stall_ack (
    .clock(clk_ad9866),
    .sig_in(stall_ack),
    .sig_out(stall_ack_ad9866)
  );

  sync sync_stall_req(
    .clock(clock_ethtxint),
    .sig_in(stall_req),
    .sig_out(stall_req_sync)
  );

  hl2link_app hl2link_app_i (
    .clk            (clk_ad9866        ),
    .phy_connected  (phy_connected     ),
    .linkrx         (linkrx            ),
    .linktx         (linktx            ),
    .stall_req      (stall_req         ),
    .stall_ack      (stall_ack_ad9866  ),
    .rst_all        (rst_all           ),
    .rst_nco        (rst_nco           ),
    .running        (link_running      ),
    .master_sel     (link_master       ),
    .lm_data        (lm_data           ),
    .lm_valid       (lm_valid          ),
    .ls_valid       (ls_valid          ),
    .ls_done        (ls_done           ),
    .ls_data        (rx_tdata          ),
    .ds_cmd_addr    (ds_cmd_addr       ),
    .ds_cmd_data    (ds_cmd_data       ),
    .ds_cmd_rqst    (ds_cmd_rqst_ad9866),
    .ds_cmd_resprqst(ds_cmd_resprqst   ),
    .ds_cmd_is_alt  (ds_cmd_is_alt     ),
    .ds_cmd_mask    (ds_cmd_mask       ),
    .cmd_addr       (cmd_addr          ),
    .cmd_data       (cmd_data          ),
    .cmd_cnt        (cmd_cnt           ),
    .cmd_resprqst   (cmd_resprqst      ),
    .cmd_is_alt     (cmd_is_alt        ),
    .cmd_rqst       (cmd_rqst_ad9866   ),
    .hl2link_rst_req(hl2link_rst_req   ),
    .hl2link_rst_ack(hl2link_rst_ack   ),
    .link_error(link_error)
  );

  //assign io_uart_txd = cmd_cnt;



end else begin
  assign linktx = 2'b00;
  assign stall_req_sync = 1'b0;
  assign rst_all        = 1'b0;
  assign rst_nco        = 1'b0;

  assign cmd_addr           = ds_cmd_addr;
  assign cmd_data           = ds_cmd_data;
  assign cmd_cnt            = ds_cmd_cnt;
  assign cmd_is_alt         = ds_cmd_is_alt;
  assign cmd_resprqst       = ds_cmd_resprqst;
  assign link_running       = 1'b0;
  assign link_master        = 1'b0;
  assign lm_data       = 24'hXXXXXX;
  assign lm_valid = 1'b1;
end

endgenerate


generate
if (AK4951 == 1) begin

  logic        au_tready  ;

  dslr_fifo dslr_fifo_i (
    .wr_clk(clock_ethrxint),
    .wr_tdata(dseth_tdata),
    .wr_tvalid(dsethlr_tvalid),
    .wr_tready(),

    .rd_clk(clk_ad9866),
    .rd_tdata(dslr_tdata),
    .rd_tvalid(dslr_tvalid),
    .rd_tready(au_tready)
  );

  localaudio localaudio_i (
    .clk(clk_ad9866),
    .rst(ad9866_rst),
    .clk_i2c_rst(clk_i2c_rst),

    .au_tdata(dslr_tdata),                 // audio L/R tx data (16bit * 2)
    .au_tready(au_tready),                 // next tx data request
    .au_rdata(au_rdata),                   // audio L rx data (16bit)
    .au_rvalid(),                          // audio rx data valid

    .sidetone_sel(cw_on),                  // select sidetone as audio output ; ad9866sync
    .profile(cw_profile[18:12]),           // sidetone profile (7bit)

    .cmd_addr(cmd_addr),                   // Command slave interface
    .cmd_data(cmd_data),
    .cmd_rqst(cmd_rqst_ad9866),            // cmd_cnt ; ad9866sync

    .i2s_pdn(i2s_pdn),                     // AK4951 i/o pins (I2S)
    .i2s_bck(i2s_bck),
    .i2s_lrck(i2s_lrck),
    .i2s_mosi(i2s_mosi),
    .i2s_miso(i2s_miso)
  );

  assign pa_exttr_clone = pa_exttr ; // AK4951 Companion Board V3


end else begin
  assign pa_exttr_clone = 1'b0;
  assign i2s_pdn  = 1'b0;
  assign i2s_bck  = 1'b0;
  assign i2s_lrck = 1'b0;
  assign i2s_mosi = 1'b0;

end
endgenerate



endmodule
