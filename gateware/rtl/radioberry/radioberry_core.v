//
//  Radioberry 
//

module radioberry_core(

	//RF Frontend
	output          rffe_ad9866_rst_n,
	output  [5:0]   rffe_ad9866_tx,
	input   [5:0]   rffe_ad9866_rx,
	input           rffe_ad9866_rxsync,
	input           rffe_ad9866_rxclk,  
	output          rffe_ad9866_txquiet_n,
	output          rffe_ad9866_txsync,
	output          rffe_ad9866_sdio,
	input           rffe_ad9866_sdo,
	output          rffe_ad9866_sclk,
	output          rffe_ad9866_sen_n,
	input           rffe_ad9866_clk76p8,
	output          rffe_ad9866_mode,
	
	//Radio Control
	input 			pi_spi_sck, 
	input 			pi_spi_mosi, 
	output 			pi_spi_miso, 
	input [1:0] 	pi_spi_ce,
	
	//RX IQ data
	input 	 		pi_rx_clk,
	output 			pi_rx_samples,
	output [3:0] 	pi_rx_data,
	output 			pi_rx_last,
	
	//TX IQ data
	input wire 		pi_tx_clk,
	input [3:0] 	pi_tx_data,
 
	// Radioberry IO
	output 			ptt_out
	
);

// PARAMETERS
parameter       NR = 1; // Receivers
parameter       NT = 1; // Transmitters
parameter       CLK_FREQ = 76800000;
parameter       UART = 0;
parameter       ATU = 0;
parameter       VNA = 0;

localparam      VERSION_MAJOR = 8'd68;


logic   [5:0]   cmd_addr;
logic   [31:0]  cmd_data;
logic           cmd_cnt;
logic           cmd_cnt_next;
logic           cmd_ptt;
logic           cmd_requires_resp;         

logic           tx_on, tx_on_ad9866sync;
logic           cw_keydown, cw_keydown_ad9866sync;
logic           tx_cw_waveform;    

logic   [31:0]  dsiq_tdata;
logic           dsiq_tready;   
logic           dsiq_tvalid;

logic  [23:0]   rx_tdata;
logic           rx_tlast;
logic           rx_tready;
logic           rx_tvalid;
logic  [ 1:0]   rx_tuser;

logic  [23:0]   usiq_tdata;
logic           usiq_tlast;
logic           usiq_tready;
logic           usiq_tvalid;
logic  [ 1:0]   usiq_tuser;
logic  [10:0]   usiq_tlength;

logic           clk_ad9866;
logic           clk_ad9866_2x;
logic           clk_envelope;
logic			clk_internal;
logic           ad9866up;

logic           tx_hang, tx_hang_iosync;

logic [11:0]    rx_data;
logic [11:0]    tx_data;

logic           rxclip, rxclip_iosync;
logic           rxgoodlvl, rxgoodlvl_iosync;
logic           rxclrstatus, rxclrstatus_ad9866sync;

//------------------------------------------------------------------------------
//                           Radioberry Software Reset Handler
//------------------------------------------------------------------------------
wire reset;
reset_handler reset_handler_inst(.clock(clk_internal), .reset(reset));

//------------------------------------------------------------------------------
//                           Radioberry Command Handler
//------------------------------------------------------------------------------
wire [47:0] spi0_recv;

spi_slave spi_slave_inst(.rstb(!reset),.ten(1'b1),.tdata({40'h0, VERSION_MAJOR}),.mlb(1'b1),.ss(pi_spi_ce[0]),.sck(pi_spi_sck),.sdin(pi_spi_mosi), .sdout(pi_spi_miso),.done(pi_spi_done),.rdata(spi0_recv));

always @ (posedge pi_spi_done) 	cmd_cnt <= ~cmd_cnt_next; 
		
always @* begin
	cmd_cnt_next = cmd_cnt;
	cmd_requires_resp = spi0_recv[39];
	cmd_ptt = spi0_recv[32];
	cmd_addr = spi0_recv[38:33];
	cmd_data = spi0_recv[31: 0];
end

//------------------------------------------------------------------------------
//                           Radioberry RX Stream Handler
//------------------------------------------------------------------------------
assign pi_rx_samples = (usiq_tlength > 11'd256) ? 1'b1: 1'b0;

logic last;
logic rx_rd_req;
logic rd_req;
ddr_mux ddr_mux_rx_inst(.clk(pi_rx_clk), .reset(reset), .rd_req(rx_rd_req), .in_data(usiq_tdata), .in_last(last), .out_last(pi_rx_last),  .out_data(pi_rx_data));

sync_one sync_one_inst(.clock(clk_internal), .sig_in(rx_rd_req), .sig_out(rd_req));

usiq_fifo usiq_fifo_i (
  .wr_clk(clk_ad9866),
  .wr_tdata(rx_tdata), 
  .wr_tvalid(rx_tvalid),
  .wr_tready(rx_tready),
  .wr_tlast(rx_tlast),
  .wr_tuser(rx_tuser),

  .rd_clk(clk_internal), 
  .rd_tdata(usiq_tdata), 
  .rd_tvalid(usiq_tvalid),
  .rd_tready(rd_req),  
  .rd_tlast(last),  
  .rd_tuser(usiq_tuser),
  .rd_tlength(usiq_tlength)
);

//------------------------------------------------------------------------------
//                           Radioberry TX Stream Handler
//------------------------------------------------------------------------------
logic [7:0] tx_data_assembled;
logic [3:0] tx_data_n;
logic tx_data_valid = 1'b0;

assign tx_on = cmd_ptt;
assign ptt_out = cmd_ptt;

always @ (posedge pi_tx_clk)
begin
	if (tx_on_ad9866sync) tx_data_valid <= 1'b1; else tx_data_valid <= 1'b0;
	tx_data_assembled <= {pi_tx_data, tx_data_n};
end

always @ (negedge pi_tx_clk) tx_data_n <= pi_tx_data;


dsiq_fifo #(.depth(8192)) dsiq_fifo_i (
  .wr_clk(pi_tx_clk),
  .wr_tdata(tx_data_assembled),
  .wr_tvalid(tx_data_valid),
  .wr_tready(),
  .wr_tlast(1'b1),

  .rd_clk(clk_ad9866),
  .rd_tdata(dsiq_tdata),
  .rd_tvalid(dsiq_tvalid),
  .rd_tready(dsiq_tready),
  .rd_sample(1'b0),
  .rd_status(),
);

//------------------------------------------------------------------------------
//                           Radioberry Clock Handler
//------------------------------------------------------------------------------													
ad9866pll ad9866pll_inst (.inclk0(rffe_ad9866_clk76p8), .c0(clk_ad9866), .c1(clk_ad9866_2x), .c2(clk_envelope), .c3(clk_internal),  .locked(ad9866up));

//------------------------------------------------------------------------------
//                           Radioberry AD9866 Clock Domain Handler
//------------------------------------------------------------------------------

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

sync sync_ad9866_tx_on (
  .clock(clk_ad9866),
  .sig_in(tx_on),
  .sig_out(tx_on_ad9866sync)
);

sync sync_ad9866_cw_keydown (
  .clock(clk_ad9866),
  .sig_in(cw_keydown),
  .sig_out(cw_keydown_ad9866sync)
);


ad9866 ad9866_i (
  .clk(clk_ad9866),
  .clk_2x(clk_ad9866_2x),

  .tx_data(tx_data),
  .rx_data(rx_data),
  .tx_en(tx_on_ad9866sync | tx_cw_waveform),

  .rxclip(rxclip),
  .rxgoodlvl(rxgoodlvl),
  .rxclrstatus(rxclrstatus_ad9866sync),

  .rffe_ad9866_tx(rffe_ad9866_tx),
  .rffe_ad9866_rx(rffe_ad9866_rx),
  .rffe_ad9866_rxsync(rffe_ad9866_rxsync),
  .rffe_ad9866_rxclk(rffe_ad9866_rxclk),  
  .rffe_ad9866_txquiet_n(rffe_ad9866_txquiet_n),
  .rffe_ad9866_txsync(rffe_ad9866_txsync),

  .rffe_ad9866_mode(rffe_ad9866_mode)

);

//------------------------------------------------------------------------------
//                           Radioberry Radio Handler
//------------------------------------------------------------------------------
radio #(
  .NR(NR), 
  .NT(NT),
  .CLK_FREQ(CLK_FREQ),
  .VNA(VNA)
) 
radio_i 
(
  .clk(clk_ad9866),
  .clk_2x(clk_ad9866_2x),

  .cw_keydown(cw_keydown_ad9866sync),
  .tx_on(tx_on_ad9866sync),
  .tx_cw_key(tx_cw_waveform),
  .tx_hang(tx_hang),

  // Transmit
  .tx_tdata({dsiq_tdata[23:16],dsiq_tdata[31:24], dsiq_tdata[7:0],dsiq_tdata[15:8]}),
  .tx_tid(3'h0),
  .tx_tlast(1'b1),
  .tx_tready(dsiq_tready),
  .tx_tvalid(dsiq_tvalid),

  .tx_data_dac(tx_data),

  .clk_envelope(clk_envelope),
  .tx_envelope_pwm_out(),
  .tx_envelope_pwm_out_inv(),

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
  .cmd_ack() // No need for ack from radio yet
);

//------------------------------------------------------------------------------
//                           Radioberry IO Clock Domain Handler
//------------------------------------------------------------------------------
sync_pulse syncio_cmd_rqst (
  .clock(clk_internal),
  .sig_in(cmd_cnt),
  .sig_out(cmd_rqst_io)
);

sync syncio_rxclip (
  .clock(clk_internal),
  .sig_in(rxclip),
  .sig_out(rxclip_iosync)
);

sync syncio_rxgoodlvl (
  .clock(clk_internal),
  .sig_in(rxgoodlvl),
  .sig_out(rxgoodlvl_iosync)
);

sync syncio_txhang (
  .clock(clk_internal),
  .sig_in(tx_hang),
  .sig_out(tx_hang_iosync)
);

//------------------------------------------------------------------------------
//                           Radioberry AD9866 Control Handler
//------------------------------------------------------------------------------
assign rffe_ad9866_rst_n = ~reset;

ad9866ctrl ad9866ctrl_i (
  .clk(clk_internal),
  .rst(reset),

  .rffe_ad9866_sdio(rffe_ad9866_sdio),
  .rffe_ad9866_sclk(rffe_ad9866_sclk),
  .rffe_ad9866_sen_n(rffe_ad9866_sen_n),
  .rffe_ad9866_pga5(),

  .cmd_addr(cmd_addr),
  .cmd_data(cmd_data),
  .cmd_rqst(cmd_rqst_io),
  .cmd_ack()
);

endmodule