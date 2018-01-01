//
//  HPSDR - High Performance Software Defined Radio
//
//  Metis code.
//
//  This program is free software; you can redistribute it and/or modify
//  it under the t=erms of the GNU General Public License as published by
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


//  Metis code copyright 2010, 2011, 2012, 2013 Phil Harman VK6APH, Alex Shovkoplyas, VE3NEA.
//  April 2016, N2ADR: Added dhcp_seconds_timer
//  January 2017, N2ADR: Added remote_mac_sync to the dhcp module


module network (

    //input
    input clock_2_5MHz,
    input udp_tx_request,
    input [15:0] udp_tx_length,
    input [7:0] udp_tx_data,
    input set_ip,
    input [31:0] assign_ip,
    input [7:0] port_ID,
    input run,

    //output
    input  rx_clock,
    input  tx_clock,
    output udp_rx_active,
    output udp_tx_enable,
    output [7:0] udp_rx_data,
    output udp_tx_active,
    output [47:0] local_mac,
    output broadcast,
    //output IP_write_done,
    output [15:0]to_port,
    output dst_unreachable,


  //status output
  output speed_1gb,
  output [3:0] network_state,
  output [7:0] network_status,
  output static_ip_assigned,
  output dhcp_timeout,
  output dhcp_success,
  output dhcp_failed,
  output icmp_rx_enable,  // *** test for ping bug

  //hardware pins
  output [3:0]PHY_TX,
  output PHY_TX_EN,
  input  [3:0]PHY_RX,
  input  PHY_DV,
  input  PHY_INT_N,
  input macbit,

  inout  PHY_MDIO,
  output PHY_MDC,

  //output SCK,
  //output SI,
  //input  SO,
  //output CS,

  input MODE2
  );

parameter MAC;
parameter IP;

wire [31:0] static_ip;
wire eeprom_ready;
wire [1:0] phy_speed;
wire phy_duplex;
wire phy_connected = phy_duplex && (phy_speed[1] != phy_speed[0]);

reg speed_1gb_i = 1'b0;
assign dhcp_timeout = (dhcp_seconds_timer == 15);


//-----------------------------------------------------------------------------
//                             state machine
//-----------------------------------------------------------------------------
//IP addresses
reg  [31:0] local_ip;
wire [31:0] apipa_ip = {8'd192, 8'd168, 8'd22, 8'd248};
//wire [31:0] ip_to_write;
assign static_ip_assigned = (static_ip != 32'hFFFFFFFF) && (static_ip != 32'd0);


localparam
  ST_START         = 4'd0,
  ST_EEPROM_START  = 4'd1,
  ST_EEPROM_READ   = 4'd2,
  ST_PHY_INIT      = 4'd3,
  ST_PHY_CONNECT   = 4'd4,
  ST_PHY_SETTLE    = 4'd5,
  ST_DHCP_REQUEST  = 4'd6,
  ST_DHCP          = 4'd7,
  ST_DHCP_RENEW    = 4'd8,
  ST_RUNNING       = 4'd9;



reg [3:0] state = ST_START;
reg [21:0] settle_cnt;
reg [21:0] dhcp_timer;
reg dhcp_tx_enable;
reg [37:0] dhcp_renew_timer;  // holds number of seconds before DHCP IP address must be renewed
reg [3:0] dhcp_seconds_timer;   // number of seconds since the DHCP request started



//reset all child modules
wire rx_reset, tx_reset;
sync sync_inst1(.clock(rx_clock), .sig_in(state <= ST_PHY_SETTLE), .sig_out(rx_reset));
sync sync_inst2(.clock(tx_clock), .sig_in(state <= ST_PHY_SETTLE), .sig_out(tx_reset));


always @(negedge clock_2_5MHz)
  //if connection lost, wait until reconnects
  if ((state > ST_PHY_CONNECT) && !phy_connected)
    state <= ST_PHY_CONNECT;

  else
    case (state)
      //set eeprom read request
      ST_START:
        begin
          speed_1gb_i <= 0;
          state <= ST_EEPROM_START;
        end
      //clear eeprom read request
      ST_EEPROM_START:
        state <= ST_EEPROM_READ;

      //wait for eeprom
      ST_EEPROM_READ:
        begin
                    local_ip <= static_ip;
                    dhcp_timer <= 22'd2_500_000;    // set dhcp timer to one second
                    dhcp_seconds_timer <= 4'd0; // zero seconds have elapsed
          state <= ST_PHY_INIT;
        end

      //set phy initialization request
      ST_PHY_INIT:
        state <= ST_PHY_CONNECT;

      //clear phy initialization request
      //wait for phy to initialize and connect
      ST_PHY_CONNECT:
        if (phy_connected) begin
          settle_cnt <= 22'd2500000; //1 second
          state <= ST_PHY_SETTLE;
          speed_1gb_i <= phy_speed[1];
         end

      //wait for connection to settle
      ST_PHY_SETTLE:
        begin
        //when network has settled, get ip address, if static IP assigned then use it else try DHCP
        if (settle_cnt == 0) begin
              if (static_ip_assigned) state <= ST_RUNNING;
              else begin
                local_ip <= 32'h00_00_00_00;                // needs to be 0.0.0.0 for DHCP
                state <= ST_DHCP_REQUEST;
              end
          end
        settle_cnt <= settle_cnt - 22'b1;          //no time out yet, count down
        end

      // send dhcp request
      ST_DHCP_REQUEST:
          begin
          dhcp_tx_enable <= 1'b1;           // set dhcp flag
          dhcp_enable <= 1'b1;              // enable dhcp receive
          state <= ST_DHCP;
          end

      // wait for dhcp success, fail or time out.  Do time out here since same clock speed for 100/1000T
          // If DHCP provided IP address then set lease timeout to lease/2 seconds.
    ST_DHCP:
        begin
            dhcp_tx_enable <= 1'b0;         // clear dhcp flag
            if (dhcp_success) begin
                local_ip <= ip_accept;
                dhcp_timer <= 22'd2_500_000;    // reset dhcp timers for next Renewal
                dhcp_seconds_timer <= 4'd0;
                if (lease == 32'd0) dhcp_renew_timer <= 43_200 * 2_500_000;  // use 43,200 seconds (12 hours) if no lease time set
                else dhcp_renew_timer <= (lease * 2_500_000) >> 1;  // set timer to half lease time.
                state <= ST_DHCP_RENEW;
            end
            else if (dhcp_timer == 0) begin  // another second has elapsed
                dhcp_renew_timer <= 38'h020000; // delay 50 ms
                dhcp_timer <= 22'd2_500_000;    // reset dhcp timer to one second
                dhcp_seconds_timer <= dhcp_seconds_timer + 4'd1;    // dhcp_seconds_timer still has its old value
                // Retransmit Discover at 1, 3, 7 seconds
                if (dhcp_seconds_timer == 0 || dhcp_seconds_timer == 2 || dhcp_seconds_timer == 6) begin
                    state <= ST_DHCP_RENEW;     // retransmit the Discover request
                end
                else if (dhcp_seconds_timer == 14) begin    // no DHCP Offer received in 15 seconds; use apipa
                    local_ip <= apipa_ip;
                    state <= ST_RUNNING;
                end
            end
            else dhcp_timer <= dhcp_timer - 22'd1;
        end

      ST_DHCP_RENEW:  // DHCP IP address obtained
          begin
                dhcp_enable <= 1'b0;                // disable dhcp receive
                if (dhcp_renew_timer == 0)
                    state <= ST_DHCP_REQUEST;
                else
                    dhcp_renew_timer <= dhcp_renew_timer - 38'd1;
          end

      // static or APIPA ip address obtained
      ST_RUNNING: dhcp_enable <= 1'b0;    // disable dhcp receive

    endcase

assign static_ip = IP;
assign local_mac =  {MAC[47:2],~macbit,MAC[0]};


//-----------------------------------------------------------------------------
// writes configuration words to the phy registers, reads phy state
//-----------------------------------------------------------------------------
phy_cfg phy_cfg_inst(
  .clock(clock_2_5MHz),
  .init_request(state == ST_PHY_INIT),
  .allow_1Gbit(MODE2),
  .speed(phy_speed),
  .duplex(phy_duplex),
  .mdio_pin(PHY_MDIO),
  .mdc_pin(PHY_MDC)
);



//-----------------------------------------------------------------------------
//                           interconnections
//-----------------------------------------------------------------------------
localparam PT_ARP = 2'd0, PT_ICMP = 2'd1, PT_DHCP = 2'd2, PT_UDP = 2'd3;
localparam false = 1'b0, true = 1'b1;



reg tx_ready = false;
reg tx_start = false;
reg [1:0] tx_protocol;

wire tx_is_icmp = tx_protocol == PT_ICMP;
wire tx_is_arp = tx_protocol  == PT_ARP;
wire tx_is_udp = tx_protocol  == PT_UDP;
wire tx_is_dhcp = (state == ST_DHCP_REQUEST) || (state == ST_DHCP);


//udp = dhcp or udp, they have separate data
wire [7:0]  udp_data;
wire [15:0] udp_length;
wire [15:0] destination_port;
wire [31:0] to_ip;


//rgmii_recv out
wire          rgmii_rx_active_pipe;
wire [7:0]    rx_data_pipe;
reg           rgmii_rx_active;
reg [7:0]     rx_data;

//mac_recv in
wire mac_rx_enable = rgmii_rx_active;

wire rx_is_arp;

//ip_recv in
wire ip_rx_enable = mac_rx_active && !rx_is_arp;
//ip_recv out
wire ip_rx_active;
wire rx_is_icmp;

//udp_recv in
wire udp_rx_enable = ip_rx_active && !rx_is_icmp;
assign udp_tx_enable = tx_start && tx_is_udp;
//udp_recv out
assign udp_rx_data = rx_data;

//arp in
wire arp_rx_enable = mac_rx_active && rx_is_arp;
wire arp_tx_enable = tx_start && tx_is_arp;
//arp out
wire arp_tx_request;
wire arp_tx_active;
wire [7:0] arp_tx_data;
wire [47:0] arp_destination_mac;

// icmp in
assign  icmp_rx_enable = ip_rx_active && rx_is_icmp;
wire icmp_tx_enable = tx_start && tx_is_icmp;
//icmp out
wire icmp_tx_request;
wire icmp_tx_active;
wire [7:0] icmp_data;
wire [15:0] icmp_length;
wire [47:0] icmp_destination_mac;
wire [31:0] icmp_destination_ip;

reg [15:0] run_destination_port;
reg [31:0] run_destination_ip;
reg [47:0] run_destination_mac;

//ip_send in
wire ip_tx_enable = icmp_tx_active || udp_tx_active;
wire [7:0] ip_tx_data_in = tx_is_icmp? icmp_data : udp_data;
wire [15:0] ip_tx_length = tx_is_icmp? icmp_length : udp_length;
wire [31:0] destination_ip = tx_is_icmp? icmp_destination_ip : (tx_is_dhcp ? dhcp_destination_ip : run_destination_ip); //udp_destination_ip_sync);

//ip_send out
wire [7:0] ip_tx_data;
wire ip_tx_active;

//mac_send in
wire mac_tx_enable = arp_tx_active || ip_tx_active;
wire [7:0] mac_tx_data_in = tx_is_arp? arp_tx_data : ip_tx_data;
wire [47:0] destination_mac = tx_is_arp  ? arp_destination_mac  :
                                        tx_is_icmp ? icmp_destination_mac :
                                        tx_is_dhcp ? dhcp_destination_mac : run_destination_mac; //udp_destination_mac_sync;
//mac_send out
wire [7:0] mac_tx_data;
wire mac_tx_active;

//rgmii_send in
wire [7:0] rgmii_tx_data_in = mac_tx_data;
wire rgmii_tx_enable = mac_tx_active;

reg  [7:0]  rgmii_tx_data_in_pipe;
reg         rgmii_tx_enable_pipe = 1'b0;



//rgmii_send out
wire        rgmii_tx_active;

//dhcp
wire       dhcp_udp_tx_request       = tx_is_dhcp ? dhcp_tx_request       : udp_tx_request;
wire [15:0]dhcp_udp_tx_length        = tx_is_dhcp ? dhcp_tx_length        : udp_tx_length;
wire [7:0] dhcp_udp_tx_data          = tx_is_dhcp ? dhcp_tx_data          : udp_tx_data;
wire [15:0]local_port                   = tx_is_dhcp ? 16'd68                  : 16'd1024;



// Hold destination port once run is set
always @(posedge tx_clock)
    if (!run) begin
        run_destination_port <= udp_destination_port_sync;
        run_destination_ip <= udp_destination_ip_sync;
        run_destination_mac <= udp_destination_mac_sync;
    end

wire [15:0]dhcp_udp_destination_port = tx_is_dhcp ? dhcp_destination_port : run_destination_port; //udp_destination_port_sync;
wire dhcp_rx_active;
wire mac_rx_active;


always @(posedge tx_clock)
  if (rgmii_tx_active)
    begin
    tx_ready <= false;
    tx_start <= false;
    end
  else if (tx_ready) tx_start <= true;
  else
    begin
    if (arp_tx_request) begin tx_protocol <= PT_ARP; tx_ready <= true; end
    else if (icmp_tx_request) begin tx_protocol <= PT_ICMP; tx_ready <= true; end
     else if (dhcp_udp_tx_request) begin tx_protocol <= PT_UDP; tx_ready <= true; end;
    end



//-----------------------------------------------------------------------------
//                               receive
//-----------------------------------------------------------------------------

always @(posedge rx_clock) begin
  rx_data <= rx_data_pipe;
  rgmii_rx_active <= rgmii_rx_active_pipe;
end

rgmii_recv rgmii_recv_inst (
  //out
  .active(rgmii_rx_active_pipe),

  .reset(rx_reset),
  .clock(rx_clock),
  .data(rx_data_pipe),
  .PHY_RX(PHY_RX),
  .PHY_DV(PHY_DV)
  );

mac_recv mac_recv_inst(
  //in
  .rx_enable(mac_rx_enable),
  //out
  .active(mac_rx_active),
  .is_arp(rx_is_arp),
  .remote_mac(remote_mac),
  .clock(rx_clock),
  .data(rx_data),
  .local_mac(local_mac),
  .broadcast(broadcast)
  );


ip_recv ip_recv_inst(
  // in
  .local_ip(local_ip),
  //out
  .active(ip_rx_active),
  .is_icmp(rx_is_icmp),
  .remote_ip(remote_ip),
  .clock(rx_clock),
  .rx_enable(ip_rx_enable),
  .broadcast(broadcast),
  .data(rx_data),

  .to_ip(to_ip)
  );

udp_recv udp_recv_inst(
    //in
    .clock(rx_clock),
    .rx_enable(udp_rx_enable),
    .data(rx_data),
    .to_ip(to_ip),
   .local_ip(local_ip),
   .broadcast(broadcast),
    .remote_mac(remote_mac),
   .remote_ip(remote_ip),

    //out
    .active(udp_rx_active),
    .dhcp_active(dhcp_rx_active),
    .to_port(to_port),
    .udp_destination_ip(udp_destination_ip),
   .udp_destination_mac(udp_destination_mac),
    .udp_destination_port(udp_destination_port)
    );

//-----------------------------------------------------------------------------
//                           receive/reply
//-----------------------------------------------------------------------------
arp arp_inst(
  //in
  .rx_enable(arp_rx_enable),
  .tx_enable(arp_tx_enable),
  //out
  .tx_active(arp_tx_active),
  .tx_data(arp_tx_data),
  .destination_mac(arp_destination_mac),
  .reset(tx_reset),
  .rx_clock(rx_clock),
  .rx_data(rx_data),
  .tx_clock(tx_clock),
  .local_mac(local_mac),
  .local_ip(local_ip),
  .tx_request(arp_tx_request),
  .remote_mac(remote_mac_sync)
);

icmp icmp_inst (
  //in
  .rx_enable(icmp_rx_enable),
  .tx_enable(icmp_tx_enable),
  //out
  .tx_request(icmp_tx_request),
  .tx_active(icmp_tx_active),
  .tx_data(icmp_data),
  .destination_mac(icmp_destination_mac),
  .destination_ip(icmp_destination_ip),
  .length(icmp_length),
  .dst_unreachable(dst_unreachable),

  .remote_mac(remote_mac_sync),
  .remote_ip(remote_ip_sync),
  .reset(tx_reset),
  .rx_clock(rx_clock),
  .rx_data(rx_data),
  .tx_clock(tx_clock)
);

wire dhcp_tx_request;
reg dhcp_enable;
wire [7:0]  dhcp_tx_data;
wire [15:0] dhcp_tx_length;
wire [47:0] dhcp_destination_mac;
wire [31:0] dhcp_destination_ip;
wire [15:0] dhcp_destination_port;
wire [31:0] ip_accept;                  // DHCP provided IP address
wire [31:0] lease;                      // time in seconds that DHCP supplied IP address is valid
wire [31:0] server_ip;                  // IP address of the DHCP that provided the IP address
wire erase;
wire EPCS_FIFO_enable;
wire [47:0]remote_mac;
wire [31:0]remote_ip;
wire [15:0]remote_port;


dhcp dhcp_inst(
  //rx in
  .rx_clock(rx_clock),
  .rx_data(rx_data),
  .rx_enable(dhcp_enable),
  .dhcp_rx_active(dhcp_rx_active),
  //rx out
  .lease(lease),
  .server_ip(server_ip),

  //tx in
  .reset(tx_reset),
  .tx_clock(tx_clock),
  .udp_tx_enable(udp_tx_enable),
  .tx_enable(dhcp_tx_enable),
  .udp_tx_active(udp_tx_active),
  .remote_mac(remote_mac_sync),             // MAC address of DHCP server
  .remote_ip(remote_ip_sync),               // IP address of DHCP server
  .dhcp_seconds_timer(dhcp_seconds_timer),

  // tx_out
  .dhcp_tx_request(dhcp_tx_request),
  .tx_data(dhcp_tx_data),
  .length(dhcp_tx_length),
  .ip_accept(ip_accept),                // IP address from DHCP server

  //constants
  .local_mac(local_mac),
  .dhcp_destination_mac(dhcp_destination_mac),
  .dhcp_destination_ip(dhcp_destination_ip),
  .dhcp_destination_port(dhcp_destination_port),

  // result
  .dhcp_success(dhcp_success),
  .dhcp_failed(dhcp_failed)

  );

//-----------------------------------------------------------------------------
//                                rx to tx clock domain transfers
//-----------------------------------------------------------------------------
wire [47:0] remote_mac_sync;
wire [31:0] remote_ip_sync;
wire [15:0] udp_destination_port;
wire [15:0] udp_destination_port_sync;
wire [47:0] udp_destination_mac;
wire [47:0] udp_destination_mac_sync;
wire [31:0] udp_destination_ip;
wire [31:0] udp_destination_ip_sync;

cdc_sync #(48)cdc_sync_inst1 (.siga(remote_mac), .rstb(0), .clkb(tx_clock), .sigb(remote_mac_sync));
cdc_sync #(32)cdc_sync_inst2 (.siga(remote_ip), .rstb(0), .clkb(tx_clock), .sigb(remote_ip_sync));
cdc_sync #(32) cdc_sync_inst7 (.siga(udp_destination_ip), .rstb(0), .clkb(tx_clock), .sigb(udp_destination_ip_sync));
cdc_sync #(48) cdc_sync_inst8 (.siga(udp_destination_mac), .rstb(0), .clkb(tx_clock), .sigb(udp_destination_mac_sync));
cdc_sync #(16) cdc_sync_inst9 (.siga(udp_destination_port), .rstb(0), .clkb(tx_clock), .sigb(udp_destination_port_sync));


//-----------------------------------------------------------------------------
//                               send
//-----------------------------------------------------------------------------

udp_send udp_send_inst (
  //in
  .reset(tx_reset),
  .clock(tx_clock),
  .tx_enable(udp_tx_enable),
  .data_in(dhcp_udp_tx_data),
  .length_in(dhcp_udp_tx_length),
  .local_port(local_port),
  .destination_port(dhcp_udp_destination_port),
  //out
  .active(udp_tx_active),
  .data_out(udp_data),
  .length_out(udp_length),
  .port_ID(port_ID)
  );

ip_send ip_send_inst (
  //in
  .data_in(ip_tx_data_in),
  .tx_enable(ip_tx_enable),
  .is_icmp(tx_is_icmp),
  .length(ip_tx_length),
  .destination_ip(destination_ip),
  //out
  .data_out(ip_tx_data),
  .active(ip_tx_active),

  .clock(tx_clock),
  .reset(tx_reset),
  .local_ip(local_ip)
  );

mac_send mac_send_inst (
  //in
  .data_in(mac_tx_data_in),
  .tx_enable(mac_tx_enable),
  .destination_mac(destination_mac),
  //out
  .data_out(mac_tx_data),
  .active(mac_tx_active),

  .clock(tx_clock),
  .local_mac(local_mac),
  .reset(tx_reset)
  );

always @(posedge tx_clock) begin
  rgmii_tx_data_in_pipe <= rgmii_tx_data_in;
  rgmii_tx_enable_pipe <= rgmii_tx_enable;
end

rgmii_send rgmii_send_inst (
  //in
  .data(rgmii_tx_data_in_pipe),
  .tx_enable(rgmii_tx_enable_pipe),
  .active(rgmii_tx_active),
  .clock(tx_clock),
  .PHY_TX(PHY_TX),
  .PHY_TX_EN(PHY_TX_EN),
  .PHY_INT_N(PHY_INT_N)
  );


//-----------------------------------------------------------------------------
//                              debug output
//-----------------------------------------------------------------------------
assign network_state = state;
assign speed_1gb = speed_1gb_i; //phy_speed[1];
assign network_status = {phy_connected,phy_speed[1],phy_speed[0], udp_rx_active, udp_rx_enable, rgmii_rx_active, rgmii_tx_active, mac_rx_active};


endmodule
