// ICMP echo payload FIFO.
//
// Historically a wizard-generated dcfifo (8-bit x 1024, showahead).  Now a
// thin wrapper over the shared stream_fifo shell in rtl/fifos.v, preserving
// the original port interface consumed by ethernet/icmp.v.

module icmp_fifo (
	aclr,
	data,
	rdclk,
	rdreq,
	wrclk,
	wrreq,
	q,
	rdempty,
	wrfull);

	input	     aclr;
	input	[7:0]  data;
	input	     rdclk;
	input	     rdreq;
	input	     wrclk;
	input	     wrreq;
	output	[7:0]  q;
	output	     rdempty;
	output	     wrfull;

	stream_fifo #(
		.WIDTH_W   (8),
		.WIDTH_R   (8),
		.NUMWORDS  (1024),
		.WIDTHU_W  (10),
		.WIDTHU_R  (10),
		.SHOWAHEAD ("ON"),
		.LPM_HINT  ("RAM_BLOCK_TYPE=M9K")
	) stream_fifo_i (
		.wr_clk   (wrclk),
		.wr_req   (wrreq),
		.wr_data  (data),
		.wr_full  (wrfull),
		.wr_empty (),
		.wr_count (),

		.rd_clk   (rdclk),
		.rd_req   (rdreq),
		.rd_data  (q),
		.rd_empty (rdempty),
		.rd_full  (),
		.rd_count (),

		.aclr     (aclr)
	);

endmodule
