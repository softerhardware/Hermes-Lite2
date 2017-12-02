

module ethernet (
    // Send to ethernet
    input  clock_2_5MHz,
    input  tx_clock,
    input  rx_clock,
    output Tx_fifo_rdreq_o,
    input [7:0] PHY_Tx_data_i,
    input [10:0] PHY_Tx_rdused_i,

    input [7:0] sp_fifo_rddata_i,
    input  sp_data_ready_i,
    output sp_fifo_rdreq_o,

    // Receive from ethernet
    output Rx_enable_o,
    output [7:0] Rx_fifo_data_o,

    // Status
    output this_MAC_o,
    output run_o,
    input [1:0] dipsw_i,
    input [7:0] AssignNR,
    output speed_1gb,

    //hardware pins
    output [3:0]PHY_TX,
    output PHY_TX_EN,
    input  [3:0]PHY_RX,
    input  RX_DV,
    inout  PHY_MDIO,
    output PHY_MDC);


parameter MAC;
parameter IP;
parameter Hermes_serialno;

wire [7:0] network_status;

wire dst_unreachable;
wire udp_tx_request;
wire run;
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

wire [3:0] network_state;
wire [47:0] local_mac;

wire discovery_reply_sync;
wire run_sync;
wire wide_spectrum_sync;

network #(.MAC(MAC), .IP(IP)) network_inst(

    //input
    .clock_2_5MHz(clock_2_5MHz),
    .udp_tx_request(udp_tx_request),
    .udp_tx_length({5'h00,udp_tx_length}),
    .udp_tx_data(udp_tx_data),
    .udp_tx_enable(udp_tx_enable),
    .udp_tx_active(udp_tx_active),
    .set_ip(1'b0),
    .assign_ip(32'h00000000),
    .port_ID(8'h00),
    .run(run_sync),
    .dst_unreachable(dst_unreachable),

    .tx_clock(tx_clock),
    .rx_clock(rx_clock),

    .local_mac(local_mac),
    .to_port(to_port),
    .broadcast(broadcast),
    .udp_rx_active(udp_rx_active),
    .udp_rx_data(udp_rx_data),

    //hardware pins
    .PHY_TX(PHY_TX),
    .PHY_TX_EN(PHY_TX_EN),
    .PHY_RX(PHY_RX),
    .PHY_DV(RX_DV),

    .PHY_INT_N(1'b1),
    .macbit(dipsw_i[1]),
  .PHY_MDIO(PHY_MDIO),
  .PHY_MDC(PHY_MDC),
  .MODE2(1'b1),
  .network_status(network_status),
  .network_state(network_state),
  .speed_1gb(speed_1gb)
);

Rx_recv rx_recv_inst(
    .rx_clk(rx_clock),
    .run(run),
    .wide_spectrum(wide_spectrum),
  .dst_unreachable(dst_unreachable),
    .discovery_reply(discovery_reply),
    .to_port(to_port),
    .broadcast(broadcast),
    .rx_valid(udp_rx_active),
    .rx_data(udp_rx_data),
    .rx_fifo_data(Rx_fifo_data_o),
    .rx_fifo_enable(Rx_enable_o)
);

// Only synchronizing one signal as run and wide_spectrum can take time to resolve meta stable state

sync sync_inst1(.clock(tx_clock), .sig_in(discovery_reply), .sig_out(discovery_reply_sync));

sync sync_inst2(.clock(tx_clock), .sig_in(run), .sig_out(run_sync));
//assign run_sync = run;

sync sync_inst3(.clock(tx_clock), .sig_in(wide_spectrum), .sig_out(wide_spectrum_sync));
//assign wide_spectrum_sync = wide_spectrum;

wire Tx_reset;

Tx_send tx_send_inst(
    .tx_clock(tx_clock),
    .Tx_reset(Tx_reset),
    .run(run_sync),
    .wide_spectrum(wide_spectrum_sync),
    .IP_valid(1'b1),
    .Hermes_serialno(Hermes_serialno),
    .IDHermesLite(dipsw_i[0]),
    .AssignNR(AssignNR),
    .PHY_Tx_data(PHY_Tx_data_i),
    .PHY_Tx_rdused(PHY_Tx_rdused_i),
    .Tx_fifo_rdreq(Tx_fifo_rdreq_o),
    .This_MAC(local_mac),
    .discovery(discovery_reply_sync),
    .sp_fifo_rddata(sp_fifo_rddata_i),
    .have_sp_data(sp_data_ready_i),
    .sp_fifo_rdreq(sp_fifo_rdreq_o),
    .udp_tx_enable(udp_tx_enable),
    .udp_tx_active(udp_tx_active),
    .udp_tx_request(udp_tx_request),
    .udp_tx_data(udp_tx_data),
    .udp_tx_length(udp_tx_length)
);

//assign This_MAC_o = local_mac;
assign this_MAC_o = network_status[0];

// FIXME: run_sync is in eth tx clock domain but used in 76 domain outside
assign run_o = run_sync;

// Set Tx_reset (no sdr send) if not in RUNNING or DHCP RENEW state
assign Tx_reset = network_state[3:1] != 3'b100;


endmodule
