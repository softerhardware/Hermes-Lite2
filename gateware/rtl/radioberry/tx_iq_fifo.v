
module tx_iq_fifo (
  wr_clk,
  wr_tdata,
  wr_tvalid,
  wr_allowed,					

  rd_clk,
  rd_tdata,
  rd_tvalid,
  rd_tready
);

input         wr_clk;
input [8:0]   wr_tdata;
input         wr_tvalid;
output 		  wr_allowed;

input         rd_clk;
output [35:0] rd_tdata;
output        rd_tvalid;
input         rd_tready;

parameter     depth   = 8192;

localparam    wrbits  = (depth == 16384) ? 14 : 13;
localparam    wrlimit = (depth == 16384) ? 14'h1000 : 13'h0800;
localparam    rdbits  = (depth == 16384) ? 12 : 11;

logic         rd_tvalidn;

logic [(wrbits-1):0]  wr_tlength;

logic [(rdbits-1):0]  rd_tlength;


assign wr_allowed = (rd_tlength >= wrlimit) ? 1'b0: 1'b1;

dcfifo_mixed_widths #(
  .intended_device_family("Cyclone IV E"),
  .lpm_numwords(depth),
  .lpm_showahead ("ON"),
  .lpm_type("dcfifo_mixed_widths"),
  .lpm_width(9),
  .lpm_widthu(wrbits),
  .lpm_widthu_r(rdbits),
  .lpm_width_r(36),
  .overflow_checking("ON"),
  .rdsync_delaypipe(4),
  .underflow_checking("ON"),
  .use_eab("ON"),
  .wrsync_delaypipe(4)
) fifo_i (
  .wrclk (wr_clk),
  .wrreq (wr_tvalid), 
  .wrfull (),
  .wrempty (),
  .wrusedw (wr_tlength),
  .data (wr_tdata),

  .rdclk (rd_clk),
  .rdreq (rd_tready),
  .rdfull (),
  .rdempty (rd_tvalidn),
  .rdusedw (rd_tlength),
  .q (rd_tdata),

  .aclr (1'b0),
  .eccstatus ()
);

assign rd_tvalid = ~rd_tvalidn;

endmodule
