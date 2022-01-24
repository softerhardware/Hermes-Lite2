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
	
	//Radio Control & TX IQ data
	input 			pi_spi_sck, 
	input 			pi_spi_mosi, 
	output 			pi_spi_miso, 
	input [1:0] 	pi_spi_ce,
	
	//RX IQ data
	input 	 		pi_rx_clk,
	output 			pi_rx_samples,
	output [7:0] 	pi_rx_data,
 
	// Radioberry IO
	input           io_phone_tip,
	input           io_phone_ring,
	output 			io_pa_exttr,
	output       	io_pa_inttr,
	
	// Local CW using pihpsdr
	input 			io_cwl,
	input 			io_cwr,
	output 			pi_cwl,
	output 			pi_cwr,
	
	// Power
	output			io_pwr_envpa,
	output			io_pwr_envbias
);

// PARAMETERS
parameter       NR = 1; // Receivers
parameter       NT = 1; // Transmitters
parameter       CLK_FREQ = 76800000;
parameter       UART = 0;
parameter       ATU = 0;
parameter       VNA = 0;
parameter       CW = 0; // CW Support
parameter       FAST_LNA = 0; 
parameter       AK4951 = 0; 
parameter       DSIQ_FIFO_DEPTH = 16384;

parameter 		FPGA_TYPE = 2'b10; //CL016 = 2'b01 ; CL025 = 2'b10
localparam      VERSION_MAJOR = 8'd73;
localparam      VERSION_MINOR = 8'd3;


logic   [5:0]   cmd_addr;
logic   [31:0]  cmd_data;
logic           cmd_cnt;
logic           cmd_cnt_next;
logic           cmd_ptt;
logic			cwx_enabled = 1'b0;    

logic           tx_on, tx_on_iosync;
logic           cw_on, cw_on_iosync;
logic           cw_keydown = 1'b0, cw_keydown_ad9866sync;

logic   [35:0]  dsiq_tdata;
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
logic           clk_ad9866_slow;
logic           ad9866up;

logic [11:0]    rx_data;
logic [11:0]    tx_data;

logic           rxclip, rxclip_iosync;
logic           rxgoodlvl, rxgoodlvl_iosync;
logic           rxclrstatus, rxclrstatus_ad9866sync;

logic           qmsec_pulse, qmsec_pulse_ad9866sync;
logic           msec_pulse;

logic           run, run_iosync, run_ad9866sync;

logic [3:0] 	channels;
logic 			reset_channels, reset_channels_ad9866sync;
logic			reset, reset_ad9866sync;

logic 			cwx;

logic [7:0]		resp;

logic			temp_enabletx; 

//------------------------------------------------------------------------------
//                           Radioberry Software Reset Handler
//------------------------------------------------------------------------------
reset_handler reset_handler_inst(.clock(clk_internal), .reset(reset));

//------------------------------------------------------------------------------
//                           Radioberry Command Handler
//------------------------------------------------------------------------------
wire [47:0] spi0_recv;

logic [1:0] fpgatype;
generate
	if (FPGA_TYPE == 2'b01) assign fpgatype = 2'b01; else assign fpgatype = 2'b10;
endgenerate

logic [47:0] ret_info;
assign ret_info = {resp, 8'b0 , 8'b0, 6'b0, fpgatype, VERSION_MAJOR, VERSION_MINOR};

spi_slave #(.WIDTH(48)) spi_slave_inst(.rstb(!reset),.ten(1'b1),.tdata(ret_info),.mlb(1'b1),.ss(pi_spi_ce[0]),.sck(pi_spi_sck),.sdin(pi_spi_mosi), .sdout(pi_spi_miso),.done(pi_spi_done),.rdata(spi0_recv));

always @ (posedge pi_spi_done) 	cmd_cnt <= ~cmd_cnt_next; 
		
always @* begin
	cmd_cnt_next = cmd_cnt;
	temp_enabletx = spi0_recv[42];
	cwx_enabled = spi0_recv[41];
	run = spi0_recv[40];
	cmd_ptt = spi0_recv[32];
	cmd_addr = spi0_recv[38:33];
	cmd_data = spi0_recv[31: 0];
end

always @(posedge clk_internal) 
begin
	if ((cmd_addr == 6'h00) && (cmd_data[6:3] != channels[3:0])) begin
		channels[3:0] <= cmd_data[6:3];
		reset_channels <= 1;
	end else reset_channels <= 0;
end

//------------------------------------------------------------------------------
//                           Radioberry RX Stream Handler
//------------------------------------------------------------------------------
assign pi_rx_samples = (usiq_tlength > 11'd256) ? 1'b1: 1'b0;

logic  last, rx_rd_req = 0, rd_req;
logic [23:0] tdata, idata, qdata;
logic [3:0]	 hptr	= 4'h01, lptr	= 4'h01;
logic [2:0]	 up		= 3'h00, down	= 3'h00;

logic [4:0] hindex [3] = '{ 5'd23, 5'd7, 5'd15};
logic [4:0] lindex [3] = '{ 5'd15, 5'd23, 5'd7};

assign pi_rx_data = (pi_rx_clk == 1) ?  tdata[hindex[hptr[3:2]] -: 8] : tdata[lindex[lptr[3:2]] -: 8];
always @ (posedge pi_rx_clk) if (!reset) begin hptr <= (|hptr) ?  hptr << 1 :  4; end
always @ (negedge pi_rx_clk) if (!reset) begin lptr <= (|lptr) ?  lptr << 1 :  4; end

assign tdata =  (up[1] & !down ) ? qdata : (up[2] & down[2] ) ? idata : tdata;
always @ (posedge pi_rx_clk) if (!reset) begin if ((up[1] & down[1])) idata <= usiq_tdata; end
always @ (negedge pi_rx_clk) if (!reset) begin if ((up[2] & down[1])) qdata <= usiq_tdata; end

sync_one sync_one_inst(.clock(clk_ad9866), .sig_in(rx_rd_req), .sig_out(rd_req));
assign rx_rd_req = ( (up[1] & !down) | (up[2] & down[1]) )? 1: 0;
always @ (posedge pi_rx_clk)  if (!reset) begin up  <= (|up)    ? up   << 1: 2; end
always @ (negedge pi_rx_clk)  if (!reset) begin down <= (|down) ? down << 1: 2; end

usiq_fifo usiq_fifo_i (
  .wr_clk(clk_ad9866),
  .wr_tdata(rx_tdata), 
  .wr_tvalid(rx_tvalid),
  .wr_tready(rx_tready),
  .wr_tlast(rx_tlast),
  .wr_tuser(rx_tuser),
  .wr_aclr(reset_channels_ad9866sync | reset_ad9866sync),

  .rd_clk(clk_ad9866), 
  .rd_tdata(usiq_tdata), 
  .rd_tvalid(usiq_tvalid),
  .rd_tready(rd_req),  
  .rd_tlast(last),  
  .rd_tuser(usiq_tuser),
  .rd_tlength(usiq_tlength)
);

generate

if (NT != 0) begin
//------------------------------------------------------------------------------
//                           Radioberry TX Stream Handler
//------------------------------------------------------------------------------

// spi rpi linux dev 1 (0 based)
// decided to send IQ sample in one call. (4 bytes; 16 bit signed per I/Q sample)
// used for transmitting data ; always 48K sampling rate!
// return indicator next iq sample allowed; the driver add a wait if not allowed to overflow the FIFO!

logic [31:0] spi_tx_iq;
logic [31:0] tx_iq;
logic [7:0] tx_part_iq;
logic spi_tx_done;
logic tx_cnt, tx_cnt_next = 0;
logic tlast = 0;

always @ (posedge spi_tx_done) tx_cnt <= ~tx_cnt_next;

always @* begin
	tx_cnt_next = tx_cnt;
	tx_iq = spi_tx_iq;
end
		
spi_slave #(.WIDTH(32)) spi_slave_tx_inst(.rstb(!reset),.ten(1'b1),.tdata({31'b0, 1'b1}),.mlb(1'b1),.ss(pi_spi_ce[1]),.sck(pi_spi_sck),.sdin(pi_spi_mosi), .sdout(pi_spi_miso),.done(spi_tx_done),.rdata(spi_tx_iq));

sync_one sync_one_tx_inst(.clock(clk_internal), .sig_in(pi_spi_ce[1]), .sig_out(tx_req));

localparam START       		= 2'h0,
           TX_DATA        	= 2'h1;
		   
logic [ 1:0] state	= START;
logic [ 1:0] state_next;
logic [ 2:0] byte_no = 3'h00;
logic [ 2:0] byte_no_next;
logic txvalid = 0;
logic [11:0]  rd_tlength;

always @ (posedge clk_internal) begin
	state <= state_next;	
	byte_no <= byte_no_next;
end

always @* begin

	state_next = state;
	byte_no_next = byte_no;
	txvalid = 0;
	tlast = 0;
	
    case (state)
		START: begin
			byte_no_next = 3'h3;
			if ((cmd_ptt | cwx_enabled) & tx_req) state_next = TX_DATA;
		end
		
		TX_DATA: begin
			txvalid = 1;
			byte_no_next = byte_no - 3'd1;
			case (byte_no[2:0])
				3'h3: tx_part_iq = tx_iq[31:24];  // I1 – Bits 15-8 of I sample
				3'h2: tx_part_iq = tx_iq[23:16];  // I0 – Bits  7-0 of I sample
				3'h1: tx_part_iq = tx_iq[15:8];   // Q1 - Bits 15-8 of Q sample
				3'h0: begin
					  tlast = 1;
					  tx_part_iq = tx_iq[7:0];    // Q0 - Bits  7-0 of Q sample
					  state_next = START;
				end	
				default: tx_part_iq = 8'h42;
			endcase
		end
		
		default: state_next = START;

	endcase // state
end

dsiq_fifo #(.depth(DSIQ_FIFO_DEPTH)) dsiq_fifo_i (
  .wr_clk(clk_internal),
  .wr_tdata({1'b0, tx_part_iq}),
  .wr_tvalid(txvalid),
  .wr_tready(),
  .wr_tlast(tlast),

  .rd_clk(clk_ad9866),
  .rd_tdata(dsiq_tdata),
  .rd_tvalid(dsiq_tvalid),
  .rd_tready(dsiq_tready)
);

end else begin
  assign dsiq_tdata = 36'b0;
  assign dsiq_tvalid = 1'b0;
end

endgenerate

//------------------------------------------------------------------------------
//                           Radioberry Clock Handler
//------------------------------------------------------------------------------													
ad9866pll ad9866pll_inst (
	.inclk0(rffe_ad9866_clk76p8), 
	.c0(clk_ad9866), 
	.c1(clk_ad9866_2x), 
	.c2(clk_envelope), 
	.c3(clk_internal), 
	.c4(clk_ad9866_slow), 
	.locked(ad9866up));

//------------------------------------------------------------------------------
//                           Radioberry AD9866 Clock Domain Handler
//------------------------------------------------------------------------------

sync_pulse sync_pulse_ad9866 (
  .clock(clk_ad9866),
  .sig_in(reset_channels),
  .sig_out(reset_channels_ad9866sync)
);

sync_pulse sync_channel_reset_ad9866 (
  .clock(clk_ad9866),
  .sig_in(cmd_cnt),
  .sig_out(cmd_rqst_ad9866)
);

sync_pulse sync_rxclrstatus_ad9866 (
  .clock(clk_ad9866),
  .sig_in(rxclrstatus),
  .sig_out(rxclrstatus_ad9866sync)
);

sync_one sync_qmsec_pulse_ad9866 (
  .clock(clk_ad9866),
  .sig_in(qmsec_pulse),
  .sig_out(qmsec_pulse_ad9866sync)
);

sync sync_ad9866_cw_keydown (
  .clock(clk_ad9866),
  .sig_in(cw_keydown),
  .sig_out(cw_keydown_ad9866sync)
);

sync sync_run_ad9866 (
  .clock(clk_ad9866),
  .sig_in(run),
  .sig_out(run_ad9866sync)
);

sync sync_reset_ad9866 (
  .clock(clk_ad9866),
  .sig_in(reset),
  .sig_out(reset_ad9866sync)
);

ad9866 #(.FAST_LNA(FAST_LNA)) ad9866_i (
  .clk(clk_ad9866),
  .clk_2x(clk_ad9866_2x),
  
  .rst(reset_ad9866sync),

  .tx_data(tx_data),
  .rx_data(rx_data),
  .tx_en(tx_on),

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
  
  // Command Slave
  .cmd_addr(cmd_addr),
  .cmd_data(cmd_data),
  .cmd_rqst(cmd_rqst_ad9866),
  .cmd_ack() // No need for ack
);

//------------------------------------------------------------------------------
//                           Radioberry Radio Handler
//------------------------------------------------------------------------------
assign cwx = (cwx_enabled) ? (dsiq_tdata[0] | dsiq_tdata[9] | dsiq_tdata[18] | dsiq_tdata[27] ) : 1'b0;

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
  
  .rst_channels(reset_channels_ad9866sync | reset_ad9866sync),

  .rst_all(1'b0),
  .rst_nco(1'b0),

  .ds_cmd_ptt(cmd_ptt),
  .run(run_ad9866sync),
  .qmsec_pulse(qmsec_pulse_ad9866sync),
  .ext_keydown(cw_keydown_ad9866sync),

  .tx_on(tx_on),
  .cw_on(cw_on),

  // Transmit
  .tx_tdata({dsiq_tdata[7:0],dsiq_tdata[16:9], dsiq_tdata[25:18],dsiq_tdata[34:27]}),
  .tx_tlast(1'b1),
  .tx_tready(dsiq_tready),
  .tx_tvalid(dsiq_tvalid),
  .tx_tuser({cmd_ptt, cwx,  2'b00}),  

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

  .cmd_addr(cmd_addr),
  .cmd_data(cmd_data),
  .cmd_rqst(cmd_rqst_io),
  .cmd_ack()
);


//------------------------------------------------------------------------------
//                           Radioberry IO Clock Domain Handler
//------------------------------------------------------------------------------
sync syncio_run (
  .clock(clk_internal),
  .sig_in(run),
  .sig_out(run_iosync)
);

control #(.CW(CW)) control_i (
	.clk(clk_internal),
	.clk_slow(clk_ad9866_slow),  
	
	.run(run_iosync),
	
	.cmd_addr(cmd_addr),
	.cmd_data(cmd_data),
	.cmd_rqst(cmd_rqst_io),
 
	.tx_on(tx_on),
	.cw_on(cw_on),
	.cw_keydown(cw_keydown),
  
	.io_phone_tip(io_phone_tip),  
	.io_phone_ring(io_phone_ring),  

	.msec_pulse(msec_pulse),
	.qmsec_pulse(qmsec_pulse),
	
	.resp(resp),
	
	.pa_temp_enabletx(temp_enabletx),
	
	.pa_exttr(io_pa_exttr),
	.pa_inttr(io_pa_inttr),
	
	.pwr_envpa(io_pwr_envpa), 
	.pwr_envbias(io_pwr_envbias)
	
  );

// cw assignment.  
assign pi_cwl = io_cwl;
assign pi_cwr = io_cwr;

endmodule