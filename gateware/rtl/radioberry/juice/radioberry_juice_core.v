//
//  Radioberry 
//

module radioberry_juice_core(

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
	
	// Juice interface; based on FTDI 
	input  			ftd_clk_60,
    inout	[7:0] 	ftd_data, 					
	output			output_enable_ftd_n,  
    input			ftd_rx_fifo_empty,  
    output			read_rx_fifo_ftd_n,
    input  			ftd_tx_fifo_full,                  
    output 			write_tx_fifo_ftd_n,  
    output 			send_immediately_ftd_n, 
 
	// Radioberry IO
	input           io_phone_tip,
	input           io_phone_ring,
	output 			io_pa_exttr,
	output       	io_pa_inttr,
	
	// Power
	output			io_pwr_envpa,
	output			io_pwr_envbias,
	
	// I2C
	inout        	io_scl,
	inout        	io_sda
);

// PARAMETERS
parameter       NR = 4; // Receivers
parameter       NT = 1; // Transmitters
parameter       CLK_FREQ = 76800000;
parameter       UART = 0;
parameter       ATU = 0;
parameter       FAN = 0;    // Generate fan support
parameter       VNA = 0;
parameter       CW = 0; // CW Support
parameter       FAST_LNA = 0; 
parameter       AK4951 = 0; 
parameter       DSIQ_FIFO_DEPTH = 16384;

parameter 		FPGA_TYPE = 2'b10; //CL016 = 2'b01 ; CL025 = 2'b10
localparam      VERSION_MAJOR = 8'd73;
localparam      VERSION_MINOR = 8'd0;


logic   [5:0]   cmd_addr;
logic   [31:0]  cmd_data;
logic           cmd_cnt;
logic           cmd_ptt; 

logic           tx_on, tx_on_iosync;
logic           cw_on, cw_on_iosync;
logic           cw_keydown = 1'b0, cw_keydown_ad9866sync;

logic           bs_tvalid;
logic           bs_tready;
logic [11:0]    bs_tdata;

logic   [5:0]   ds_cmd_addr;
logic   [31:0]  ds_cmd_data;
logic           ds_cmd_cnt;
logic           ds_cmd_resprqst;
logic           ds_cmd_ptt;

logic           cmd_resprqst, cmd_resprqst_iosync;
logic 			cmd_rqst_usopenhpsdr1;
logic 			cmd_rqst_dsopenhpsdr1;

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
logic  [ 1:0]   usiq_tuser;
logic  [10:0]   usiq_tlength;

logic           clk_ad9866;
logic           clk_ad9866_2x;
logic           clk_envelope;
logic			clk_internal;
logic           clk_ad9866_slow;
logic           ad9866up;

logic           cmd_rqst_ad9866;

logic [11:0]    rx_data;
logic [11:0]    tx_data;

logic           rxclip, rxclip_iosync;
logic           rxgoodlvl, rxgoodlvl_iosync;
logic           rxclrstatus, rxclrstatus_ad9866sync;

logic [39:0]    resp;
logic           resp_rqst, resp_rqst_iosync;

logic           qmsec_pulse, qmsec_pulse_ad9866sync;
logic           msec_pulse, msec_pulse_phy;

logic           run, run_sync, run_iosync, run_ad9866sync;
logic           wide_spectrum, wide_spectrum_sync;

logic			ftd_reset, reset, reset_ad9866sync;

logic [7:0] 	data_i, data_o;
logic 			data_en;

logic [7:0] 	ds_stream;
logic 			ds_valid;

logic [7:0] 	us_stream;
logic 			us_valid;
logic 			us_ready;

logic 			ctrl_clk;

//------------------------------------------------------------------------------
//                           Radioberry Software I2C IO
//------------------------------------------------------------------------------
assign scl_i = io_scl;
assign io_scl = scl_t ? 1'bz : scl_o;
assign sda_i = io_sda;
assign io_sda = sda_t ? 1'bz : sda_o;

//------------------------------------------------------------------------------
//                           Radioberry Software Reset Handler
//------------------------------------------------------------------------------
reset_handler reset_handler_inst1(.clock(clk_internal), .reset(reset));
reset_handler reset_handler_inst2(.clock(ftd_clk_60), .reset(ftd_reset));

//------------------------------------------------------------------------------
//                           Radioberry Physical Interface 
//------------------------------------------------------------------------------
assign ftd_data   = data_en ? data_o : 8'hzz;
assign data_i = ftd_data;

radioberry_phy radioberry_phy_inst (
	.ftd_reset(ftd_reset),
	
	.run(run),

	.ftd_clk_60(ftd_clk_60),

	.data_i(data_i), 
	.data_o(data_o), 
	.data_en(data_en), 

	.output_enable_ftd_n(output_enable_ftd_n),  
	.ftd_rx_fifo_empty(ftd_rx_fifo_empty),  
	.read_rx_fifo_ftd_n(read_rx_fifo_ftd_n),

	.ftd_tx_fifo_full(ftd_tx_fifo_full),                  
	.write_tx_fifo_ftd_n(write_tx_fifo_ftd_n),  
	.send_immediately_ftd_n(send_immediately_ftd_n),
	
	.ds_stream(ds_stream),
	.ds_valid(ds_valid),
		
	.us_stream(us_stream),
	.us_valid(us_valid),
	.us_ready(us_ready)
);

//------------------------------------------------------------------------------
//                           Radioberry Down-Stream Handler
//------------------------------------------------------------------------------
assign cmd_addr	= ds_cmd_addr;
assign cmd_data	= ds_cmd_data;
assign cmd_cnt	= ds_cmd_cnt;
assign cmd_ptt	= ds_cmd_ptt;
assign cmd_resprqst = ds_cmd_resprqst;


dsopenhpsdr1 dsopenhpsdr1_i (
  .clk(ftd_clk_60),
  
  .reset(ftd_reset),

  .ds_stream(ds_stream),
  .ds_stream_valid(ds_valid),

  .run(run),
  .wide_spectrum(wide_spectrum),
  .msec_pulse(msec_pulse_phy),
  
  .ds_cmd_addr(ds_cmd_addr),
  .ds_cmd_data(ds_cmd_data),
  .ds_cmd_cnt(ds_cmd_cnt),
  .ds_cmd_resprqst(ds_cmd_resprqst),
  .ds_cmd_ptt(ds_cmd_ptt),

  .dseth_tdata(dseth_tdata),
  .dsethiq_tvalid(dsethiq_tvalid),
  .dsethiq_tlast(dsethiq_tlast),
  .dsethiq_tuser(dsethiq_tuser),
  .dsethlr_tvalid(dsethlr_tvalid),
  .dsethlr_tlast(dsethlr_tlast),

  .cmd_addr(cmd_addr),
  .cmd_data(cmd_data),
  .cmd_rqst(cmd_rqst_dsopenhpsdr1)
);

//------------------------------------------------------------------------------
//                           Radioberry Up-Stream Handler
//------------------------------------------------------------------------------
usopenhpsdr1 usopenhpsdr1_i (
  
	.clk(ftd_clk_60),
	.run(run),
	.wide_spectrum(wide_spectrum),
  
	.us_stream(us_stream),
	.us_stream_ready(us_ready),
	.us_stream_valid(us_valid),

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
	.resp_rqst(resp_rqst)
);

usiq_fifo usiq_fifo_i (
  .wr_clk(clk_ad9866),
  .wr_tdata(rx_tdata), 
  .wr_tvalid(rx_tvalid),
  .wr_tready(rx_tready),
  .wr_tlast(rx_tlast),
  .wr_tuser(rx_tuser),
  .wr_aclr(1'b0),

  .rd_clk(ftd_clk_60), 
  .rd_tdata(usiq_tdata), 
  .rd_tvalid(usiq_tvalid),
  .rd_tready(usiq_tready),  
  .rd_tlast(usiq_tlast),  
  .rd_tuser(usiq_tuser),
  .rd_tlength(usiq_tlength)
);

//------------------------------------------------------------------------------
//                           Radioberry Wide band stream
//------------------------------------------------------------------------------
usbs_fifo usbs_fifo_i (
  .wr_clk(clk_ad9866),
  .wr_tdata(rx_data),
  .wr_tvalid(1'b1),
  .wr_tready(),

  .rd_clk(ftd_clk_60),
  .rd_tdata(bs_tdata),
  .rd_tvalid(bs_tvalid),
  .rd_tready(bs_tready)
);


generate

if (NT != 0) begin

dsiq_fifo #(.depth(DSIQ_FIFO_DEPTH)) dsiq_fifo_i (
  .wr_clk(ftd_clk_60),
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
//                           Radioberry phy Clock Domain Handler
//------------------------------------------------------------------------------

sync_one sync_msec_pulse_eth (
  .clock(ftd_clk_60),
  .sig_in(msec_pulse),
  .sig_out(msec_pulse_phy)
);

assign cmd_rqst_usopenhpsdr1 = cmd_cnt;
assign cmd_rqst_dsopenhpsdr1 = cmd_cnt;

//------------------------------------------------------------------------------
//                           Radioberry AD9866 Clock Domain Handler
//------------------------------------------------------------------------------

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

  .rst_channels(1'b0),
  .rst_all(1'b0),
  .rst_nco(1'b0),
 
  .link_running(1'b0),
  .link_master(1'b0),
  .lm_data(24'hXXXXXX),
  .lm_valid(1'b1),
  .ls_valid(),
  .ls_done(1'b0),

  .ds_cmd_ptt(ds_cmd_ptt), 
  .run(run_ad9866sync),
  .qmsec_pulse(qmsec_pulse_ad9866sync),
  .ext_keydown(cw_keydown_ad9866sync),

  .tx_on(tx_on),
  .cw_on(cw_on),

  // Transmit
  .tx_tdata({dsiq_tdata[7:0],dsiq_tdata[16:9],dsiq_tdata[25:18],dsiq_tdata[34:27]}),
  .tx_tlast(1'b1),
  .tx_tready(dsiq_tready),
  .tx_tvalid(dsiq_tvalid),
  .tx_tuser({dsiq_tdata[8],dsiq_tdata[17],dsiq_tdata[26],dsiq_tdata[35]}),
  
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
logic clk_ctrl;
 
clk_div (clk_internal,reset, clk_ctrl); //divide 4 => 2.5Mhz

sync_pulse #(.DEPTH(2)) syncio_cmd_rqst (
  .clock(clk_ctrl),
  .sig_in(cmd_cnt),
  .sig_out(cmd_rqst_iosync)
);

sync_pulse #(.DEPTH(2)) syncio_resp_rqst (
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

//------------------------------------------------------------------------------
//                           Radioberry Control Handler
//------------------------------------------------------------------------------
control #(
  .VERSION_MAJOR(VERSION_MAJOR),
  .FAN          (FAN          ),
  .CW           (CW           )
) control_i (
	.clk(clk_internal),
	.clk_ctrl(clk_ctrl),
	.clk_slow(clk_ad9866_slow), 
	.reset(reset),
	
	.rxclip(rxclip_iosync),
	.rxgoodlvl(rxgoodlvl_iosync),
	.rxclrstatus(rxclrstatus),
	
	.run(run_iosync),
	
	.cmd_addr(cmd_addr),
	.cmd_data(cmd_data),
	.cmd_rqst(cmd_rqst_iosync),
	
	.cmd_requires_resp(cmd_resprqst),
 
	.tx_on(tx_on),
	.cw_on(cw_on),
	.cw_keydown(cw_keydown),
  
	.io_phone_tip(io_phone_tip),  
	.io_phone_ring(io_phone_ring),  

	.msec_pulse(msec_pulse),
	.qmsec_pulse(qmsec_pulse),
	
	.dsiq_status(dsiq_status),
	.dsiq_sample(dsiq_sample),

	.resp_rqst(resp_rqst_iosync),	
	.resp(resp),
	
	.pa_exttr(io_pa_exttr),
	.pa_inttr(io_pa_inttr),
	
	.fan_pwm(), //not used yet; only shutting down pa if temp too high
	
	.pwr_envpa(io_pwr_envpa), 
	.pwr_envbias(io_pwr_envbias),
	
	  // AD9866
	.rffe_ad9866_rst_n(rffe_ad9866_rst_n),

	.rffe_ad9866_sdio(rffe_ad9866_sdio),
	.rffe_ad9866_sclk(rffe_ad9866_sclk),
	.rffe_ad9866_sen_n(rffe_ad9866_sen_n),
	
	.scl_i(scl_i),
	.scl_o(scl_o),
	.scl_t(scl_t),
	.sda_i(sda_i),
	.sda_o(sda_o),
	.sda_t(sda_t)
	
  );

endmodule

//divide by 4
module clk_div (clk,reset, clk_out);
 
input clk;
input reset;
output clk_out;
 
reg [1:0] r_reg;
wire [1:0] r_nxt;
reg clk_track;
 
always @(posedge clk or posedge reset)
 
begin
  if (reset)
     begin
        r_reg <= 3'b0;
		clk_track <= 1'b0;
     end
 
  else if (r_nxt == 2'b10)
 	   begin
	     r_reg <= 0;
	     clk_track <= ~clk_track;
	   end
 
  else 
      r_reg <= r_nxt;
end
 
 assign r_nxt = r_reg+1;   	      
 assign clk_out = clk_track;
endmodule