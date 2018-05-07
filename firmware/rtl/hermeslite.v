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
localparam       HERMES_SERIALNO = 8'd40;     // Serial number of this version
localparam       MAC = {8'h00,8'h1c,8'hc0,8'ha2,8'h12,8'hdd};
`else 
localparam       HERMES_SERIALNO = 8'd60;     // Serial number of this version
localparam       MAC = {8'h00,8'h1c,8'hc0,8'ha2,8'h13,8'hdd};
`endif
localparam       IP = {8'd0,8'd0,8'd0,8'd0};

// ADC Oscillator
localparam       CLK_FREQ = 76800000;

// Experimental Predistort On=1 Off=0
localparam      PREDISTORT = 0;

localparam      NR = 3; // Recievers
localparam      NT = 1; // Transmitters

logic   [5:0]   cmd_addr;
logic   [31:0]  cmd_data;
logic           cmd_ack;
logic           cmd_cnt;
logic           cmd_ptt;
logic           cmd_resprqst;

// Individual acknowledges
logic           cmd_ack_i2c, cmd_ack_radio, cmd_ack_ad9866;

logic           ext_ptt, ext_cwkey, ext_txinhibit;
logic           tx_en;

logic   [7:0]   dseth_tdata;

logic   [31:0]  dsiq_rdata;
logic           dsiq_rreq;    // controls reading of fifo
logic           dsiq_rempty;
logic           dsethiq_tvalid;

logic   [31:0]  dslr_rdata;
logic           dslr_rreq;    // controls reading of fifo
logic           dslr_rempty;
logic           dsethlr_tvalid;

logic  [23:0]   rx_tdata;
logic           rx_tlast;
logic           rx_treadyn;
logic           rx_tvalid;

logic  [24:0]   usiq_q;
logic  [23:0]   usiq_tdata;
logic           usiq_tlast;
logic           usiq_tready;
logic           usiq_tvalidn;
logic  [10:0]   usiq_tlength;

logic           response_inp_tready;
logic   [37:0]  response_out_tdata;
logic           response_out_tvalid;
logic           response_out_tready;

logic           bs_ad9866_full, bs_ad9866_empty;
logic           bs_ad9866_push = 1'b0;

logic           bs_full, bs_empty;
logic           bs_tvalid = 1'b0;
logic           bs_tready;
logic [11:0]    bs_tdata;

logic           cmd_rqst_usopenhpsdr1;

logic           clock_125_mhz_0_deg;
logic           clock_125_mhz_90_deg;
logic           clock_2_5MHz;
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
logic           ad9866pll_locked;

logic           rst;
logic           clk_i2c_rst;
logic           clk_i2c_start;

logic [15:0]    resetcounter = 16'h0000;
logic           ad9866_rst_n = 1'b0;

logic           run, run_sync;
logic           wide_spectrum, wide_spectrum_sync;
logic           discovery_reply, discovery_reply_sync;

logic [ 7:0]    network_status;
logic           dst_unreachable;

logic           udp_tx_request;
logic [ 7:0]    udp_tx_data;
logic [10:0]    udp_tx_length;
logic           udp_tx_enable;

logic [15:0]    to_port;
logic           broadcast;
logic           udp_rx_active;
logic [ 7:0]    udp_rx_data;

logic           network_state;

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

logic           rxclipp;
logic           rxclipn;


/////////////////////////////////////////////////////
// Clocks

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
  .locked (ad9866pll_locked)
);


/////////////////////////////////////////////////////
// Reset

// Most FPGA logic is reset when ethernet is up and ad9866 PLL is locked
// AD9866 is released from reset

always @ (posedge clock_2_5MHz)
  if (~resetcounter[15] & ethup) resetcounter <= resetcounter + 16'h01;

// At ~410us
assign clk_i2c_rst = ~(|resetcounter[15:10]);

// At ~820us
assign clk_i2c_start = ~(|resetcounter[15:11]);

// At ~6.5ms
assign rst = ~(|resetcounter[15:14]);

// At ~13ms
always @ (posedge clock_2_5MHz)
  if (resetcounter[15] & ad9866pll_locked) ad9866_rst_n <= 1'b1;



/////////////////////////////////////////////////////
// Network

assign local_mac =  {MAC[47:2],~io_cn10,MAC[0]};

network network_inst(

  .clock_2_5MHz(clock_2_5MHz),

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

  .static_ip(IP),
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



///////////////////////////////////////////////
// Downstream ethrxint clock domain

dsopenhpsdr1 dsopenhpsdr1_i (
  .clk(clock_ethrxint),
  .eth_port(to_port),
  .eth_broadcast(broadcast),
  .eth_valid(udp_rx_active),
  .eth_data(udp_rx_data),
  .eth_unreachable(dst_unreachable),
  .eth_metis_discovery(discovery_reply),

  .run(run),
  .wide_spectrum(wide_spectrum),

  .cmd_addr(cmd_addr),
  .cmd_data(cmd_data),
  .cmd_cnt(cmd_cnt),
  .cmd_ptt(cmd_ptt),
  .cmd_resprqst(cmd_resprqst),  

  .dseth_tdata(dseth_tdata),
  .dsethiq_tvalid(dsethiq_tvalid),
  .dsethlr_tvalid(dsethlr_tvalid)
);

dcfifo_mixed_widths #(
  .intended_device_family("Cyclone IV E"),
  .lpm_numwords(8192), 
  .lpm_showahead ("ON"),
  .lpm_type("dcfifo_mixed_widths"),
  .lpm_width(8),
  .lpm_widthu(13),
  .lpm_widthu_r(11),
  .lpm_width_r(32),
  .overflow_checking("ON"),
  .rdsync_delaypipe(4),
  .underflow_checking("ON"),
  .use_eab("ON"),
  .wrsync_delaypipe(4)
) dsiq_fifo_i (
  .wrclk (clock_ethrxint),
  .wrreq (dsethiq_tvalid),  
  .wrfull (),
  .wrempty (),
  .wrusedw (),
  .data (dseth_tdata),

  .rdclk (clk_ad9866),
  .rdreq (dsiq_rreq),
  .rdfull (),
  .rdempty (dsiq_rempty),
  .rdusedw (),
  .q (dsiq_rdata),

  .aclr (1'b0),
  .eccstatus ()
);


generate 

if(PREDISTORT==1) begin: PD2

  dcfifo_mixed_widths #(
    .intended_device_family("Cyclone IV E"),
    .lpm_numwords(8192), 
    .lpm_showahead ("ON"),
    .lpm_type("dcfifo_mixed_widths"),
    .lpm_width(8),
    .lpm_widthu(13),
    .lpm_widthu_r(11),
    .lpm_width_r(32),
    .overflow_checking("ON"),
    .rdsync_delaypipe(4),
    .underflow_checking("ON"),
    .use_eab("ON"),
    .wrsync_delaypipe(4)
  ) dslr_fifo_i (
    .wrclk (clock_ethrxint),
    .wrreq (dsethlr_tvalid),  
    .wrfull (),
    .wrempty (),
    .wrusedw (),
    // Use iq here to save wires
    .data (dseth_tdata),
  
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
  assign dslr_rdata = 32'h0;

end
endgenerate



///////////////////////////////////////////////
// Upstream ethtxint clock domain

sync sync_inst1(.clock(clock_ethtxint), .sig_in(discovery_reply), .sig_out(discovery_reply_sync));
sync sync_inst2(.clock(clock_ethtxint), .sig_in(run), .sig_out(run_sync));
sync sync_inst3(.clock(clock_ethtxint), .sig_in(wide_spectrum), .sig_out(wide_spectrum_sync));

sync_pulse sync_pulse_usopenhpsdr1 (
  .clock(clock_ethtxint),
  .sig_in(cmd_cnt),
  .sig_out(cmd_rqst_usopenhpsdr1)
);

usopenhpsdr1 #(.NR(NR), .HERMES_SERIALNO(HERMES_SERIALNO)) usopenhpsdr1_i (
  .clk(clock_ethtxint),
  .rst(network_state),
  .run(run_sync),
  .wide_spectrum(wide_spectrum_sync),
  .idhermeslite(io_cn9),
  .mac(local_mac),
  .discovery(discovery_reply_sync),

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
  .us_tvalid(~usiq_tvalidn),
  .us_tlength(usiq_tlength),

  .cmd_addr(cmd_addr),
  .cmd_data(cmd_data),
  .cmd_rqst(cmd_rqst_usopenhpsdr1)
);


dcfifo #(
  .add_usedw_msb_bit("ON"),
  .intended_device_family("Cyclone IV E"),
  .lpm_numwords(1024), 
  .lpm_showahead ("ON"),
  .lpm_type("dcfifo"),
  .lpm_width(25),
  .lpm_widthu(11), 
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
  .data ({rx_tlast,rx_tdata}),

  .rdclk (clock_ethtxint),
  .rdreq (usiq_tready),
  .rdfull (),
  .rdempty (usiq_tvalidn),
  .rdusedw (usiq_tlength),
  .q (usiq_q),

  .aclr (1'b0),
  .eccstatus ()  
);

assign usiq_tlast = usiq_q[24];
assign usiq_tdata = usiq_q[23:0];


// BS AD9866 State
always @ (posedge clk_ad9866) begin
  if (bs_ad9866_empty) begin
    bs_ad9866_push <= 1'b1;
  end else if (bs_ad9866_full) begin
    bs_ad9866_push <= 1'b0;
  end 
end 

dcfifo #(
  .intended_device_family("Cyclone IV E"),
  .lpm_numwords(2048), 
  .lpm_showahead ("ON"),
  .lpm_type("dcfifo"),
  .lpm_width(12),
  .lpm_widthu(11), 
  .overflow_checking("ON"),
  .rdsync_delaypipe(4),
  .underflow_checking("ON"),
  .use_eab("ON"),
  .wrsync_delaypipe(4)
) bandscope_fifo_i (
  .wrclk (clk_ad9866),
  .wrreq (bs_ad9866_push & ~bs_ad9866_full),
  .wrfull (bs_ad9866_full),
  .wrempty (bs_ad9866_empty),
  .wrusedw (),
  .data (rx_data),

  .rdclk (clock_ethtxint),
  .rdreq (bs_tready),
  .rdfull (bs_full),
  .rdempty (bs_empty),
  .rdusedw (),
  .q (bs_tdata),

  .aclr (1'b0),
  .eccstatus ()  
);


// BS State
always @ (posedge clock_ethtxint) begin
  if (bs_full) begin
    bs_tvalid <= 1'b1;
  end else if (bs_empty) begin
    bs_tvalid <= 1'b0;
  end 
end 



///////////////////////////////////////////////
// AD9866 clock domain



sync_pulse sync_pulse_ad9866 (
  .clock(clk_ad9866),
  .sig_in(cmd_cnt),
  .sig_out(cmd_rqst_ad9866)
);

ad9866 ad9866_i (
  .clk(clk_ad9866),
  .clk_2x(clk_ad9866_2x),
  .rst_n(ad9866_rst_n),

  .tx_data(tx_data),
  .rx_data(rx_data),
  .tx_en(tx_en),

  .rxclipp(rxclipp),
  .rxclipn(rxclipn),
  .rxgoodlvlp(),
  .rxgoodlvln(),

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
  .cmd_rqst(cmd_rqst_ad9866),
  .cmd_ack(cmd_ack_ad9866)
);


radio #(
  .NR(NR), 
  .NT(NT),
  .PREDISTORT(PREDISTORT),
  .CLK_FREQ(CLK_FREQ)
) 
radio_i 
(
  .clk(clk_ad9866),

  .ext_ptt(ext_ptt),
  .ext_cwkey(ext_cwkey),
  .ext_txinhibit(ext_txinhibit),
  .cmd_ptt(cmd_ptt),

  .tx_en(tx_en),

  // Transmit
  .tx_tdata({dsiq_rdata[7:0],dsiq_rdata[15:8],dsiq_rdata[23:16],dsiq_rdata[31:24]}),
  .tx_tid(3'h0),
  .tx_tlast(1'b1),
  .tx_tready(dsiq_rreq),
  .tx_tvalid(~dsiq_rempty),

  .tx_data_dac(tx_data),

  // Optional Audio Stream
  .lr_tdata({dslr_rdata[7:0],dslr_rdata[15:8],dslr_rdata[23:16],dslr_rdata[31:24]}),
  .lr_tid(3'h0),
  .lr_tlast(1'b1),
  .lr_tready(dslr_rreq),
  .lr_tvalid(~dslr_rempty),

  // Receive
  .rx_data_adc(rx_data),

  .rx_tdata(rx_tdata),
  .rx_tlast(rx_tlast),
  .rx_tready(~rx_treadyn),
  .rx_tvalid(rx_tvalid),

  // Command Slave
  .cmd_addr(cmd_addr),
  .cmd_data(cmd_data),
  .cmd_rqst(cmd_rqst_ad9866),
  .cmd_ack(cmd_ack_radio)
);



///////////////////////////////////////////////
// IO clock domain

sync_pulse sync_pulse_io (
  .clock(clk_ad9866),
  .sig_in(cmd_cnt),
  .sig_out(cmd_rqst_io)
);


ioblock ioblock_i (
  // Internal
  .clk(clk_ad9866),
  .rst(rst),

  .rxclipp(rxclipp),
  .rxclipn(rxclipn),
  .this_MAC(network_status[0]),
  .run_sync(run_sync),

  .cmd_addr(cmd_addr),
  .cmd_data(cmd_data),
  .cmd_rqst(cmd_rqst_io),
  .cmd_ack(),  

  .clock_2_5MHz(clock_2_5MHz),
  .clk_i2c_rst(clk_i2c_rst),
  .clk_i2c_start(clk_i2c_start),

  .ext_ptt(ext_ptt),
  .ext_cwkey(ext_cwkey),
  .ext_txinhibit(ext_txinhibit),

  .cmd_ptt(cmd_ptt),

  // External
  .rffe_rfsw_sel(rffe_rfsw_sel),

  // Power
  .pwr_clk3p3(pwr_clk3p3),
  .pwr_clk1p2(pwr_clk1p2),
  .pwr_envpa(pwr_envpa), 

`ifdef BETA2
  .pwr_clkvpa(pwr_clkvpa),
`else
  .pwr_envop(pwr_envop),
  .pwr_envbias(pwr_envbias),
`endif

  // Clock
  .clk_recovered(clk_recovered),
 
  .sda1_i(sda1_i),
  .sda1_o(sda1_o),
  .sda1_t(sda1_t),
  .scl1_i(scl1_i),
  .scl1_o(scl1_o),
  .scl1_t(scl1_t),

  .sda2_i(sda2_i),
  .sda2_o(sda2_o),
  .sda2_t(sda2_t),
  .scl2_i(scl2_i),
  .scl2_o(scl2_o),
  .scl2_t(scl2_t),

  .sda3_i(sda3_i),
  .sda3_o(sda3_o),
  .sda3_t(sda3_t),
  .scl3_i(scl3_i),
  .scl3_o(scl3_o),
  .scl3_t(scl3_t),

  // IO
  .io_led_d2(io_led_d2),
  .io_led_d3(io_led_d3),
  .io_led_d4(io_led_d4),
  .io_led_d5(io_led_d5),
  .io_lvds_rxn(io_lvds_rxn),
  .io_lvds_rxp(io_lvds_rxp),
  .io_lvds_txn(io_lvds_txn),
  .io_lvds_txp(io_lvds_txp),
  .io_cn8(io_cn8),
  .io_cn9(io_cn9),
  .io_cn10(io_cn10),

  .io_db1_2(io_db1_2),     
  .io_db1_3(io_db1_3),     
  .io_db1_4(io_db1_4),     
  .io_db1_5(io_db1_5),     
  .io_db1_6(io_db1_6),       
  .io_phone_tip(io_phone_tip), 
  .io_phone_ring(io_phone_ring),
  .io_tp2(io_tp2),
  
`ifndef BETA2
  .io_tp7(io_tp7),
  .io_tp8(io_tp8),  
  .io_tp9(io_tp9),
`endif

  // PA
`ifdef BETA2
  .pa_tr(pa_tr),
  .pa_en(pa_en)
`else
  .pa_inttr(pa_inttr),
  .pa_exttr(pa_exttr)
`endif
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

endmodule
