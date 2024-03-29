//
//  HPSDR - High Performance Software Defined Radio
//
//  Metis code.
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


//  Metis code copyright 2010, 2011, 2012, 2013 Phil Harman VK6APH, Alex Shovkoplyas, VE3NEA.
//  April 2016, N2ADR: Added dhcp_seconds_timer
//  January 2017, N2ADR: Added remote_mac_sync to the dhcp module
//  January 2017, N2ADR: Added ST_DHCP_RENEW states to allow IO to continue during DHCP lease renewal
//  2018 Steve Haynal KF7O


module network (

  // dhcp and mdio clock
  input clock_2_5MHz,

  // upstream
  input         tx_clock,
  input  [1:0]  udp_tx_request,
  input [15:0]  udp_tx_length,
  input [7:0]   udp_tx_data,
  output        udp_tx_enable,
  input         run,
  input [7:0]   port_id,

  // downstream
  input         rx_clock,
  output [15:0] to_port,
  output [7:0]  udp_rx_data,
  output        udp_rx_active,
  output        broadcast,
  output        dst_unreachable,

  // status and control
  input  [ 7:0] eeprom_config,
  input  [31:0] static_ip,
  input  [47:0] local_mac,
  output        speed_1gb,
  output        network_state_dhcp,
  output        network_state_fixedip,
  output [1:0]  network_speed,
  output reg    phy_connected,
  output        is_ksz9021,

  // phy
  output [3:0]  PHY_TX,
  output        PHY_TX_EN,
  input  [3:0]  PHY_RX,
  input         PHY_DV,

  inout         PHY_MDIO,
  output        PHY_MDC
);

parameter SIM = 0;

wire udp_tx_active;
wire eeprom_ready;
wire [1:0] phy_speed;
wire phy_duplex;
wire dhcp_success;
wire icmp_rx_enable;
wire phy_connected_int = phy_duplex && (phy_speed[1] != phy_speed[0]);

reg speed_1gb_i = 1'b0;
//assign dhcp_timeout = (dhcp_seconds_timer == 15);


//-----------------------------------------------------------------------------
//                             state machine
//-----------------------------------------------------------------------------
//IP addresses
reg  [31:0] local_ip;
//wire [31:0] apipa_ip = {8'd192, 8'd168, 8'd22, 8'd248};
wire [31:0] apipa_ip = {8'd169, 8'd254, local_mac[15:0]};
//wire [31:0] ip_to_write;

localparam
  ST_START         = 4'd0,
  ST_PHY_INIT      = 4'd3,
  ST_PHY_CONNECT   = 4'd4,
  ST_PHY_SETTLE    = 4'd5,
  ST_DHCP_REQUEST  = 4'd6,
  ST_DHCP          = 4'd7,
  ST_DHCP_RETRY    = 4'd8,
  ST_RUNNING       = 4'd9,
  ST_DHCP_RENEW_WAIT  = 4'd10,
  ST_DHCP_RENEW_REQ   = 4'd11,
  ST_DHCP_RENEW_ACK   = 4'd12;



// Set Tx_reset (no sdr send) if network_state is True
assign network_state_dhcp = reg_network_state_dhcp;   // network_state is low when we have an IP address
assign network_state_fixedip = reg_network_state_fixedip;
reg reg_network_state_dhcp = 1'b1;           // this is used in network.v to hold code in reset when high
reg reg_network_state_fixedip = 1'b1;
reg [3:0] state = ST_START;
reg [21:0] dhcp_timer;
reg dhcp_tx_enable;
reg [17:0] dhcp_renew_timer;  // holds number of seconds before DHCP IP address must be renewed
reg [3:0] dhcp_seconds_timer;   // number of seconds since the DHCP request started



//reset all child modules
wire rx_reset, tx_reset;
sync sync_inst1(.clock(rx_clock), .sig_in(state <= ST_PHY_SETTLE), .sig_out(rx_reset));
sync sync_inst2(.clock(tx_clock), .sig_in(state <= ST_PHY_SETTLE), .sig_out(tx_reset));


always @(negedge clock_2_5MHz)
  //if connection lost, wait until reconnects
  if ((state > ST_PHY_CONNECT) && !phy_connected_int) begin
    reg_network_state_dhcp <= 1'b1;
    reg_network_state_fixedip <= 1'b1;
    state <= ST_PHY_CONNECT;
  end

  else
  case (state)
    //set eeprom read request
    ST_START: begin
      speed_1gb_i <= 0;
      state <= ST_PHY_INIT;
    end

    //set phy initialization request
    ST_PHY_INIT:
      state <= ST_PHY_CONNECT;

    //clear phy initialization request
    //wait for phy to initialize and connect
    ST_PHY_CONNECT:
      if (phy_connected_int) begin
        dhcp_timer <= (SIM==1) ? 22'h01 : 22'd2500000; //1 second
        state <= ST_PHY_SETTLE;
        speed_1gb_i <= phy_speed[1];
      end

    //wait for connection to settle
    ST_PHY_SETTLE: begin
      //when network has settled, get ip address, if static IP assigned then use it else try DHCP
      if (dhcp_timer == 0) begin
        if (eeprom_config[7] & ~eeprom_config[5]) begin
          local_ip <= static_ip;
          state <= ST_RUNNING;
        end else begin
          local_ip <= 32'h00_00_00_00;                // needs to be 0.0.0.0 for DHCP
          dhcp_timer <= 22'd2_500_000;    // set dhcp timer to one second
          dhcp_seconds_timer <= 4'd0; // zero seconds have elapsed
          state <= ST_DHCP_REQUEST;
        end
      end
      dhcp_timer <= dhcp_timer - 22'b1;          //no time out yet, count down
    end

    // send initial dhcp discover and request on power up
    ST_DHCP_REQUEST: begin
      dhcp_tx_enable <= 1'b1;           // set dhcp flag
      dhcp_enable <= 1'b1;              // enable dhcp receive
      state <= ST_DHCP;
    end

    // wait for dhcp success, fail or time out.  Do time out here since same clock speed for 100/1000T
    // If DHCP provided IP address then set lease timeout to lease/2 seconds.
    ST_DHCP: begin
      dhcp_tx_enable <= 1'b0;         // clear dhcp flag
      if (dhcp_success) begin
        local_ip <= ip_accept;
        dhcp_timer <= 22'd2_500_000;    // reset dhcp timers for next Renewal
        dhcp_seconds_timer <= 4'd0;
        reg_network_state_dhcp <= 1'b0;    // Let network code know we have a valid IP address so can run when needed.
        if (lease == 32'd0)
          dhcp_renew_timer <= 43_200;  // use 43,200 seconds (12 hours) if no lease time set
        else
          dhcp_renew_timer <= lease >> 1;  // set timer to half lease time.
        //    dhcp_renew_timer <= (32'd10 * 2_500_000);     // **** test code - set DHCP renew to 10 seconds ****
        state <= ST_DHCP_RENEW_WAIT;
      end
      else if (dhcp_timer == 0) begin  // another second has elapsed
        dhcp_renew_timer <= 18'h020000; // delay 50 ms
        dhcp_timer <= 22'd2_500_000;    // reset dhcp timer to one second
        dhcp_seconds_timer <= dhcp_seconds_timer + 4'd1;    // dhcp_seconds_timer still has its old value
        // Retransmit Discover at 1, 3, 7 seconds
        if (dhcp_seconds_timer == 0 || dhcp_seconds_timer == 2 || dhcp_seconds_timer == 6) begin
          state <= ST_DHCP_RETRY;     // retransmit the Discover request
        end
        else if (dhcp_seconds_timer == 14) begin    // no DHCP Offer received in 15 seconds; use fixed ip or apipa
          if (eeprom_config[7] & eeprom_config[5]) begin
            local_ip <= static_ip;
          end else begin
            local_ip <= apipa_ip;
          end
          state <= ST_RUNNING;
        end
      end
      else
        dhcp_timer <= dhcp_timer - 22'd1;
    end

    ST_DHCP_RETRY: begin  // Initial DHCP IP address was not obtained.  Try again.
      dhcp_enable <= 1'b0;                // disable dhcp receive
      if (dhcp_renew_timer == 0)
        state <= ST_DHCP_REQUEST;
      else
        dhcp_renew_timer <= dhcp_renew_timer - 18'h01;
    end

    // static ,DHCP or APIPA ip address obtained
    ST_RUNNING: begin
      dhcp_enable <= 1'b0;          // disable dhcp receive
      reg_network_state_fixedip <= 1'b0;    // let network.v know we have a valid IP address
    end

    // NOTE: reg_network_state is not set here so we can send DHCP packets whilst waiting for DHCP renewal.

    ST_DHCP_RENEW_WAIT: begin // Wait until the DHCP lease expires
      dhcp_enable <= 1'b0;        // disable dhcp receive

      if (dhcp_timer == 0) begin // another second has elapsed
        dhcp_renew_timer <= dhcp_renew_timer - 18'h01;
        dhcp_timer <= 22'd2_500_000;    // reset dhcp timer to one second
      end
      else begin
        dhcp_timer <= dhcp_timer - 22'h01;
      end

      if (dhcp_renew_timer == 0)
        state <= ST_DHCP_RENEW_REQ;
    end

    ST_DHCP_RENEW_REQ: begin // DHCP sends a request to renew the lease
      dhcp_tx_enable <= 1'b1;
      dhcp_enable <= 1'b1;
      dhcp_renew_timer <= 'd20;   // time to wait for ACK
      dhcp_timer <= 22'd2_500_000;    // reset dhcp timers for next Renewal
      state <= ST_DHCP_RENEW_ACK;
    end

    ST_DHCP_RENEW_ACK: begin  // Wait for an ACK from the DHCP server in response to the request
      dhcp_tx_enable <= 1'b0;
      if (dhcp_success) begin
        if (lease == 32'd0)
          dhcp_renew_timer <= 43_200;  // use 43,200 seconds (12 hours) if no lease time set
        else
          dhcp_renew_timer <= lease >> 1;  // set timer to half lease time.
        //  dhcp_renew_timer <= (32'd10 * 2_500_000);     // **** test code - set DHCP renew to 10 seconds ****
        dhcp_timer <= 22'd2_500_000;    // reset dhcp timers for next Renewal
        state <= ST_DHCP_RENEW_WAIT;
      end

      else if (dhcp_timer == 0) begin  // another second has elapsed
        dhcp_timer <= 22'd2_500_000;    // reset dhcp timer to one second
        dhcp_renew_timer <= dhcp_renew_timer - 1'd1;

      end
      else if (dhcp_renew_timer == 0) begin
        dhcp_renew_timer <= 18'd300; // time between renewal requests
        state <= ST_DHCP_RENEW_WAIT;
      end
      else begin
        dhcp_timer <= dhcp_timer - 18'h01;
      end

    end

  endcase


//-----------------------------------------------------------------------------
// writes configuration words to the phy registers, reads phy state
//-----------------------------------------------------------------------------

generate
  if (SIM ==1) begin
    assign phy_speed = 2'b10;
    assign phy_duplex = 1'b1;
  end else begin
    phy_cfg phy_cfg_inst(
      .clock(clock_2_5MHz),
      .init_request(state == ST_PHY_INIT),
      .speed(phy_speed),
      .duplex(phy_duplex),
      .is_ksz9021(is_ksz9021),
      .mdio_pin(PHY_MDIO),
      .mdc_pin(PHY_MDC)
    );
  end
endgenerate

//-----------------------------------------------------------------------------
//                           interconnections
//-----------------------------------------------------------------------------
localparam PT_ARP = 3'd0, PT_ICMP = 3'd1, PT_DHCP = 3'd2, PT_UDP0 = 3'd4, PT_UDP1 = 3'd5;
localparam false = 1'b0, true = 1'b1;



reg tx_ready = false;
reg tx_start = false;
reg [2:0] tx_protocol;

wire tx_is_icmp = tx_protocol == PT_ICMP;
wire tx_is_arp  = tx_protocol  == PT_ARP;
wire tx_is_udp  = ((tx_protocol  == PT_UDP0) | (tx_protocol == PT_UDP1));
wire tx_is_udp1 = tx_protocol == PT_UDP1;
wire tx_is_dhcp = tx_protocol == PT_DHCP;



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
assign udp_tx_enable = tx_start && (tx_is_udp || tx_is_dhcp);
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
assign  icmp_rx_enable = ip_rx_active && rx_is_icmp && to_ip_is_me;
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

//reg [31:0] destination_ip;
//always @(posedge tx_clock) destination_ip <=
wire [31:0] destination_ip = tx_is_icmp ? icmp_destination_ip :
  (tx_is_dhcp ? dhcp_destination_ip :
    (tx_is_udp1 ? udp_destination_ip_sync :
      run_destination_ip));

//ip_send out
wire [7:0] ip_tx_data;
wire ip_tx_active;

//mac_send in
wire        mac_tx_enable   = arp_tx_active || ip_tx_active      ;
wire [ 7:0] mac_tx_data_in  = tx_is_arp? arp_tx_data : ip_tx_data;

//reg  [47:0] destination_mac                                      ;
//always @(posedge tx_clock) destination_mac <= 
wire [47:0] destination_mac = tx_is_arp  ? arp_destination_mac  :
  tx_is_icmp ? icmp_destination_mac :
    tx_is_dhcp ? dhcp_destination_mac :
      tx_is_udp1 ? udp_destination_mac_sync : run_destination_mac;

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
wire [15:0]dhcp_udp_tx_length        = tx_is_dhcp ? dhcp_tx_length        : udp_tx_length;
wire [7:0] dhcp_udp_tx_data          = tx_is_dhcp ? dhcp_tx_data          : udp_tx_data;
wire [15:0]local_port                = tx_is_dhcp ? 16'd68                : {15'd512,tx_is_udp1};


//reg [15:0] dhcp_udp_destination_port;
//always @(posedge tx_clock) dhcp_udp_destination_port <= 
wire [15:0] dhcp_udp_destination_port = tx_is_dhcp ? dhcp_destination_port :
  (tx_is_udp1 ? udp_destination_port_sync :
    run_destination_port);

wire dhcp_rx_active;
wire mac_rx_active;


always @(posedge tx_clock)
  if (rgmii_tx_active) begin
    tx_ready <= false;
    tx_start <= false;
  end
  else if (tx_ready)
    tx_start <= true;
  else begin
    if (arp_tx_request) begin
      tx_protocol <= PT_ARP;
      tx_ready <= true;
    end
    else if (icmp_tx_request) begin
      tx_protocol <= PT_ICMP;
      tx_ready <= true;
    end
    else if (dhcp_tx_request) begin
      tx_protocol <= PT_DHCP;
      tx_ready <= true;
    end
    else if (udp_tx_request == 2'b10)  begin
      tx_protocol <= PT_UDP0;
      tx_ready <= true;
    end
    else if (udp_tx_request == 2'b11)  begin
      tx_protocol <= PT_UDP1;
      tx_ready <= true;
    end
  end



//-----------------------------------------------------------------------------
//                               receive
//-----------------------------------------------------------------------------


wire [15:0] udp_destination_port ;
wire [47:0] udp_destination_mac  ;
wire [31:0] udp_destination_ip   ;
wire        udp_destination_valid;


always @(posedge rx_clock) begin
  rx_data <= rx_data_pipe;
  rgmii_rx_active <= rgmii_rx_active_pipe;
end


rgmii_recv #(.SIM(SIM)) rgmii_recv_inst (
  //out
  .active   (rgmii_rx_active_pipe),
  .reset    (rx_reset            ),
  .clock    (rx_clock            ),
  .speed_1gb(speed_1gb_i         ),
  .data     (rx_data_pipe        ),
  .PHY_RX   (PHY_RX              ),
  .PHY_DV   (PHY_DV              )
);



mac_recv mac_recv_inst (
  //in
  .rx_enable       (mac_rx_enable   ),
  //out
  .active          (mac_rx_active   ),
  .is_arp          (rx_is_arp       ),
  .remote_mac      (remote_mac      ),
  .remote_mac_valid(remote_mac_valid),
  .clock           (rx_clock        ),
  .data            (rx_data         ),
  .local_mac       (local_mac       ),
  .broadcast       (broadcast       )
);

ip_recv ip_recv_inst (
  // in
  .local_ip       (local_ip       ),
  //out
  .active         (ip_rx_active   ),
  .is_icmp        (rx_is_icmp     ),
  .remote_ip      (remote_ip      ),
  .remote_ip_valid(remote_ip_valid),
  .clock          (rx_clock       ),
  .rx_enable      (ip_rx_enable   ),
  .broadcast      (broadcast      ),
  .data           (rx_data        ),
  .to_ip          (to_ip          ),
  .to_ip_is_me    (to_ip_is_me    )
);

udp_recv udp_recv_inst (
  //in
  .clock                (rx_clock             ),
  .run                  (run                  ),
  .rx_enable            (udp_rx_enable        ),
  .data                 (rx_data              ),
  .to_ip                (to_ip                ),
  .local_ip             (local_ip             ),
  .broadcast            (broadcast            ),
  .remote_mac           (remote_mac           ),
  .remote_ip            (remote_ip            ),
  //out
  .active               (udp_rx_active        ),
  .dhcp_active          (dhcp_rx_active       ),
  .to_port              (to_port              ),
  .udp_destination_ip   (udp_destination_ip   ),
  .udp_destination_mac  (udp_destination_mac  ),
  .udp_destination_port (udp_destination_port ),
  .udp_destination_valid(udp_destination_valid)
);

//-----------------------------------------------------------------------------
//                           receive/reply
//-----------------------------------------------------------------------------
arp arp_inst (
  //in
  .rx_enable      (arp_rx_enable      ),
  .tx_enable      (arp_tx_enable      ),
  //out
  .tx_active      (arp_tx_active      ),
  .tx_data        (arp_tx_data        ),
  .destination_mac(arp_destination_mac),
  .reset          (tx_reset           ),
  .rx_clock       (rx_clock           ),
  .rx_data        (rx_data            ),
  .tx_clock       (tx_clock           ),
  .local_mac      (local_mac          ),
  .local_ip       (local_ip           ),
  .tx_request     (arp_tx_request     ),
  .remote_mac     (remote_mac         )
);

generate
  if (SIM==1) begin

    assign dst_unreachable = 1'b0;
    assign tx_request = 1'b0;
    assign tx_active = 1'b0;
    assign tx_data = 8'h00;
    assign length = 16'h0000;
    assign destination_mac = 48'h00;
    assign destination_ip = 32'h00;

  end else begin

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
  end
endgenerate

wire        dhcp_tx_request      ;
reg         dhcp_enable          ;
wire [ 7:0] dhcp_tx_data         ;
wire [15:0] dhcp_tx_length       ;
wire [47:0] dhcp_destination_mac ;
wire [31:0] dhcp_destination_ip  ;
wire [15:0] dhcp_destination_port;
wire [31:0] ip_accept            ; // DHCP provided IP address
wire [31:0] lease                ; // time in seconds that DHCP supplied IP address is valid
wire [31:0] server_ip            ; // IP address of the DHCP that provided the IP address
wire        erase                ;
wire        EPCS_FIFO_enable     ;
wire [47:0] remote_mac           ;
wire        remote_mac_valid     ;
wire [31:0] remote_ip            ;
wire        remote_ip_valid      ;

dhcp dhcp_inst (
  //rx in
  .rx_clock             (rx_clock             ),
  .rx_data              (rx_data              ),
  .rx_enable            (dhcp_enable          ),
  .dhcp_rx_active       (dhcp_rx_active       ),
  //rx out
  .lease                (lease                ),
  .server_ip            (server_ip            ),

  //tx in
  .reset                (tx_reset             ),
  .tx_clock             (tx_clock             ),
  .udp_tx_enable        (udp_tx_enable        ),
  .tx_enable            (dhcp_tx_enable       ),
  .udp_tx_active        (udp_tx_active        ),
  .remote_mac           (remote_mac_sync      ), // MAC address of DHCP server
  .remote_ip            (remote_ip_sync       ), // IP address of DHCP server
  .dhcp_seconds_timer   (dhcp_seconds_timer   ),
  .local_ip             (local_ip           ),

  // tx_out
  .dhcp_tx_request      (dhcp_tx_request      ),
  .tx_data              (dhcp_tx_data         ),
  .length               (dhcp_tx_length       ),
  .ip_accept            (ip_accept            ), // IP address from DHCP server

  //constants
  .local_mac            (local_mac            ),
  .dhcp_destination_mac (dhcp_destination_mac ),
  .dhcp_destination_ip  (dhcp_destination_ip  ),
  .dhcp_destination_port(dhcp_destination_port),

  // result
  .dhcp_success         (dhcp_success         ),
  .dhcp_failed          (                     )
);

//-----------------------------------------------------------------------------
//                                rx to tx clock domain transfers
//-----------------------------------------------------------------------------
reg  [47:0] remote_mac_sync           ;
wire        remote_mac_valid_sync     ;
reg  [31:0] remote_ip_sync            ;
wire        remote_ip_valid_sync      ;
reg  [15:0] udp_destination_port_sync ;
reg  [47:0] udp_destination_mac_sync  ;
reg  [31:0] udp_destination_ip_sync   ;
wire        udp_destination_valid_sync;

//cdc_sync #(48) cdc_sync_inst1 (.siga(remote_mac), .rstb(1'b0), .clkb(tx_clock), .sigb(remote_mac_sync));
//cdc_sync #(32) cdc_sync_inst2 (.siga(remote_ip), .rstb(1'b0), .clkb(tx_clock), .sigb(remote_ip_sync));

sync_pulse remote_ip_sync_i     (.clock(tx_clock), .sig_in(remote_ip_valid),       .sig_out(remote_ip_valid_sync));
sync_pulse remote_mac_sync_i    (.clock(tx_clock), .sig_in(remote_mac_valid),      .sig_out(remote_mac_valid_sync));
sync_pulse udp_destination_sync (.clock(tx_clock), .sig_in(udp_destination_valid), .sig_out(udp_destination_valid_sync));

always @(posedge tx_clock) begin
  if (udp_destination_valid_sync) begin
    // Alternate port 1025 info
    if (to_port[0]) begin
      udp_destination_ip_sync   <= udp_destination_ip;
      udp_destination_mac_sync  <= udp_destination_mac;
      udp_destination_port_sync <= udp_destination_port;
    end
    else if (~run) begin
      run_destination_ip <= udp_destination_ip;
      run_destination_mac <= udp_destination_mac;
      run_destination_port <= udp_destination_port;
    end
  end

  if (remote_mac_valid_sync) begin
    remote_mac_sync <= remote_mac;
  end

  if (remote_ip_valid) begin
    remote_ip_sync <= remote_ip;
  end

end



//-----------------------------------------------------------------------------
//                               send
//-----------------------------------------------------------------------------

udp_send udp_send_inst (
  //in
  .reset           (tx_reset                 ),
  .clock           (tx_clock                 ),
  .tx_enable       (udp_tx_enable            ),
  .data_in         (dhcp_udp_tx_data         ),
  .length_in       (dhcp_udp_tx_length       ),
  .local_port      (local_port               ),
  .destination_port(dhcp_udp_destination_port),
  //out
  .active          (udp_tx_active            ),
  .data_out        (udp_data                 ),
  .length_out      (udp_length               ),
  .port_ID         (port_id                  )
);

ip_send ip_send_inst (
  //in
  .data_in       (ip_tx_data_in ),
  .tx_enable     (ip_tx_enable  ),
  .is_icmp       (tx_is_icmp    ),
  .length        (ip_tx_length  ),
  .destination_ip(destination_ip),
  //out
  .data_out      (ip_tx_data    ),
  .active        (ip_tx_active  ),
  .clock         (tx_clock      ),
  .reset         (tx_reset      ),
  .local_ip      (local_ip      )
);

mac_send mac_send_inst (
  //in
  .data_in        (mac_tx_data_in ),
  .tx_enable      (mac_tx_enable  ),
  .destination_mac(destination_mac),
  //out
  .data_out       (mac_tx_data    ),
  .active         (mac_tx_active  ),
  .clock          (tx_clock       ),
  .local_mac      (local_mac      ),
  .reset          (tx_reset       )
);

always @(posedge tx_clock) begin
  rgmii_tx_data_in_pipe <= rgmii_tx_data_in;
  rgmii_tx_enable_pipe  <= rgmii_tx_enable;
end


rgmii_send #(.SIM(SIM)) rgmii_send_inst (
  //in
  .data     (rgmii_tx_data_in_pipe),
  .tx_enable(rgmii_tx_enable_pipe ),
  .active   (rgmii_tx_active      ),
  .clock    (tx_clock             ),
  .PHY_TX   (PHY_TX               ),
  .PHY_TX_EN(PHY_TX_EN            )
);

always @(negedge clock_2_5MHz) phy_connected <= phy_connected_int;

//-----------------------------------------------------------------------------
//                              debug output
//-----------------------------------------------------------------------------
assign speed_1gb = speed_1gb_i; //phy_speed[1];
assign network_speed = phy_speed;
// {phy_connected,phy_speed[1],phy_speed[0], udp_rx_active, udp_rx_enable, rgmii_rx_active, rgmii_tx_active, mac_rx_active};


endmodule
