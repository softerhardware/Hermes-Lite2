
module dsiq_fifo (
  wr_clk,
  wr_tdata,
  wr_tvalid,
  wr_tready,

  rd_clk,
  rd_tdata,
  rd_tvalid,
  rd_tready
);

input         wr_clk;
input [7:0]   wr_tdata;
input         wr_tvalid;
output        wr_tready;

input         rd_clk;
output [31:0] rd_tdata;
output        rd_tvalid;
input         rd_tready;

logic         wr_treadyn;
logic         rd_tvalidn;

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
) fifo_i (
  .wrclk (wr_clk),
  .wrreq (wr_tvalid),  
  .wrfull (wr_treadyn),
  .wrempty (),
  .wrusedw (),
  .data (wr_tdata),

  .rdclk (rd_clk),
  .rdreq (rd_tready),
  .rdfull (),
  .rdempty (rd_tvalidn),
  .rdusedw (),
  .q (rd_tdata),

  .aclr (1'b0),
  .eccstatus ()
);

assign wr_tready = ~wr_treadyn;
assign rd_tvalid = ~rd_tvalidn;

endmodule 



module dslr_fifo (
  wr_clk,
  wr_tdata,
  wr_tvalid,
  wr_tready,

  rd_clk,
  rd_tdata,
  rd_tvalid,
  rd_tready
);

input         wr_clk;
input [7:0]   wr_tdata;
input         wr_tvalid;
output        wr_tready;

input         rd_clk;
output [31:0] rd_tdata;
output        rd_tvalid;
input         rd_tready;

logic         wr_treadyn;
logic         rd_tvalidn;

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
) fifo_i (
  .wrclk (wr_clk),
  .wrreq (wr_tvalid),  
  .wrfull (wr_treadyn),
  .wrempty (),
  .wrusedw (),
  .data (wr_tdata),

  .rdclk (rd_clk),
  .rdreq (rd_tready),
  .rdfull (),
  .rdempty (rd_tvalidn),
  .rdusedw (),
  .q (rd_tdata),

  .aclr (1'b0),
  .eccstatus ()
);

assign wr_tready = ~wr_treadyn;
assign rd_tvalid = ~rd_tvalidn;

endmodule 



module usiq_fifo (
  wr_clk,
  wr_tdata,
  wr_tvalid,
  wr_tready,
  wr_tlast,

  rd_clk,
  rd_tdata,
  rd_tvalid,
  rd_tready,
  rd_tlast,
  rd_tlength
);

input         wr_clk;
input [23:0]  wr_tdata;
input         wr_tvalid;
output        wr_tready;
input         wr_tlast;

input         rd_clk;
output [23:0] rd_tdata;
output        rd_tvalid;
input         rd_tready;
output        rd_tlast;
output [10:0] rd_tlength;

logic         wr_treadyn;
logic         rd_tvalidn;
logic  [24:0] rd_data;

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
) fifo_i (
  .wrclk (wr_clk),
  .wrreq (wr_tvalid),
  .wrfull (wr_treadyn),
  .wrempty (),
  .wrusedw (),
  .data ({wr_tlast,wr_tdata}),

  .rdclk (rd_clk),
  .rdreq (rd_tready),
  .rdfull (),
  .rdempty (rd_tvalidn),
  .rdusedw (rd_tlength),
  .q (rd_data),

  .aclr (1'b0),
  .eccstatus ()  
);

assign wr_tready = ~wr_treadyn;
assign rd_tvalid = ~rd_tvalidn;
assign rd_tlast  = rd_data[24];
assign rd_tdata  = rd_data[23:0];

endmodule 



module usbs_fifo (
  wr_clk,
  wr_tdata,
  wr_tvalid,
  wr_tready,

  rd_clk,
  rd_tdata,
  rd_tvalid,
  rd_tready
);

input         wr_clk;
input [11:0]  wr_tdata;
input         wr_tvalid;
output        wr_tready;

input         rd_clk;
output [11:0] rd_tdata;
output logic  rd_tvalid = 1'b0;
input         rd_tready;

logic         rd_tvalidn;

logic         bs_ad9866_full, bs_ad9866_empty;
logic         bs_ad9866_push = 1'b0;

logic         bs_full, bs_empty;


// BS AD9866 State
always @ (posedge wr_clk) begin
  if (bs_ad9866_empty) begin
    bs_ad9866_push <= 1'b1;
  end else if (bs_ad9866_full) begin
    bs_ad9866_push <= 1'b0;
  end 
end 

assign wr_tready = bs_ad9866_push & ~bs_ad9866_full;

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
) fifo_i (
  .wrclk (wr_clk),
  .wrreq (bs_ad9866_push & ~bs_ad9866_full),
  .wrfull (bs_ad9866_full),
  .wrempty (bs_ad9866_empty),
  .wrusedw (),
  .data (wr_tdata),

  .rdclk (rd_clk),
  .rdreq (rd_tready),
  .rdfull (bs_full),
  .rdempty (bs_empty),
  .rdusedw (),
  .q (rd_tdata),

  .aclr (1'b0),
  .eccstatus ()  
);

// BS State
always @ (posedge rd_clk) begin
  if (bs_full) begin
    rd_tvalid <= 1'b1;
  end else if (bs_empty) begin
    rd_tvalid <= 1'b0;
  end 
end 

endmodule 

