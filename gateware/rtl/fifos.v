//-----------------------------------------------------------------------------
// Hermes-Lite FIFO library.
//
// All cross-domain sample/stream FIFOs are built on one shared shell,
// stream_fifo below, which is the single point of configuration for the
// Altera dcfifo / dcfifo_mixed_widths cells:
//
//   * Write-side and read-side occupancy are SEPARATE outputs (wr_count /
//     rd_count), each valid in its own clock domain.  Flow control must use
//     the count from the same domain as the signal being generated.
//
//   * SHOWAHEAD "ON": rd_data is valid while ~rd_empty, rd_req pops the
//     current word.  SHOWAHEAD "OFF": rd_data follows rd_req by one cycle.
//
// Each named wrapper preserves its historical external interface (they are
// instantiated by hermeslite_core.v and the radioberry cores) and adds its
// protocol-specific flow-control policy on top of the shared shell:
//
//   dsiq_fifo - TX I/Q: drop-on-full, restart after tlast below threshold,
//               recovery/occupancy status to host.
//   dslr_fifo - audio/predistortion upload: pass-through.
//   usiq_fifo - RX I/Q: near-full backpressure from WRITE-side occupancy,
//               read-side length reported separately.
//   usbs_fifo - bandscope: fill-to-full then drain-to-empty burst gate.
//   asmi_fifo - firmware programming stream: pass-through, registered read.
//
// icmp_fifo.v (ethernet echo payload) uses the same shell.
//-----------------------------------------------------------------------------

module stream_fifo #(
  // WIDTH_R != WIDTH_W selects dcfifo_mixed_widths, else dcfifo
  parameter WIDTH_W           = 8,
  parameter WIDTH_R           = 8,
  parameter NUMWORDS          = 1024,
  parameter WIDTHU_W          = 10,      // bits of wr_count
  parameter WIDTHU_R          = 10,      // bits of rd_count
  parameter SHOWAHEAD         = "ON",
  parameter ADD_USEDW_MSB     = "OFF",   // dcfifo (same-width) branch only
  parameter WRITE_ACLR_SYNCH  = "OFF",   // dcfifo (same-width) branch only
  parameter USE_EAB           = "ON",
  parameter LPM_HINT          = "UNUSED",
  parameter DEVICE_FAMILY     = "Cyclone IV E"
)(
  input                      wr_clk,
  input                      wr_req,
  input      [WIDTH_W-1:0]   wr_data,
  output                     wr_full,
  output                     wr_empty,
  output     [WIDTHU_W-1:0]  wr_count,

  input                      rd_clk,
  input                      rd_req,
  output     [WIDTH_R-1:0]   rd_data,
  output                     rd_empty,
  output                     rd_full,
  output     [WIDTHU_R-1:0]  rd_count,

  input                      aclr
);

  generate if (WIDTH_W == WIDTH_R) begin : SAME_WIDTH

    dcfifo #(
      .add_usedw_msb_bit      (ADD_USEDW_MSB),
      .intended_device_family (DEVICE_FAMILY),
      .lpm_hint               (LPM_HINT),
      .lpm_numwords           (NUMWORDS),
      .lpm_showahead          (SHOWAHEAD),
      .lpm_type               ("dcfifo"),
      .lpm_width              (WIDTH_W),
      .lpm_widthu             (WIDTHU_W),
      .overflow_checking      ("ON"),
      .rdsync_delaypipe       (4),
      .underflow_checking     ("ON"),
      .use_eab                (USE_EAB),
      .wrsync_delaypipe       (4),
      .write_aclr_synch       (WRITE_ACLR_SYNCH)
    ) dcfifo_i (
      .wrclk   (wr_clk),
      .wrreq   (wr_req),
      .wrfull  (wr_full),
      .wrempty (wr_empty),
      .wrusedw (wr_count),
      .data    (wr_data),

      .rdclk   (rd_clk),
      .rdreq   (rd_req),
      .rdfull  (rd_full),
      .rdempty (rd_empty),
      .rdusedw (rd_count),
      .q       (rd_data),

      .aclr      (aclr),
      .eccstatus ()
    );

  end else begin : MIXED_WIDTH

    dcfifo_mixed_widths #(
      .intended_device_family (DEVICE_FAMILY),
      .lpm_numwords           (NUMWORDS),
      .lpm_showahead          (SHOWAHEAD),
      .lpm_type               ("dcfifo_mixed_widths"),
      .lpm_width              (WIDTH_W),
      .lpm_widthu             (WIDTHU_W),
      .lpm_width_r            (WIDTH_R),
      .lpm_widthu_r           (WIDTHU_R),
      .overflow_checking      ("ON"),
      .rdsync_delaypipe       (4),
      .underflow_checking     ("ON"),
      .use_eab                (USE_EAB),
      .wrsync_delaypipe       (4)
    ) dcfifo_i (
      .wrclk   (wr_clk),
      .wrreq   (wr_req),
      .wrfull  (wr_full),
      .wrempty (wr_empty),
      .wrusedw (wr_count),
      .data    (wr_data),

      .rdclk   (rd_clk),
      .rdreq   (rd_req),
      .rdfull  (rd_full),
      .rdempty (rd_empty),
      .rdusedw (rd_count),
      .q       (rd_data),

      .aclr      (aclr),
      .eccstatus ()
    );

  end
  endgenerate

endmodule


//-----------------------------------------------------------------------------
// TX I/Q downstream FIFO: 9-bit ethernet bytes to 36-bit I/Q groups.
// Drop-on-full with hysteresis: pushing stops while full and resumes only
// at a group boundary (wr_tlast) once occupancy falls to 1/4 full (~10ms).
//-----------------------------------------------------------------------------

module dsiq_fifo (
  wr_clk,
  wr_tdata,
  wr_tvalid,
  wr_tready,
  wr_tlast,

  rd_clk,
  rd_tdata,
  rd_tvalid,
  rd_tready,
  rd_sample,
  rd_status
);

input         wr_clk;
input [8:0]   wr_tdata;
input         wr_tvalid;
output        wr_tready;
input         wr_tlast;

input         rd_clk;
output [35:0] rd_tdata;
output        rd_tvalid;
input         rd_tready;
input         rd_sample;
output [7:0]  rd_status;

parameter     depth   = 8192;

// Write and read limited at 8 ms
localparam    wrbits  = (depth == 16384) ? 14 : 13;
// Restart pushing at 1/4 full (10ms) to accommodate software
// that sends 20ms at a time
localparam    wrlimit = (depth == 16384) ? 14'h1000 : 13'h0800;
localparam    rdbits  = (depth == 16384) ? 12 : 11;

logic         wr_full_n;
logic         rd_empty_n;

logic         allow_push = 1'b1;
logic [wrbits-1:0]    wr_occ;
logic [rdbits-1:0]    rd_occ;

logic   [6:0] rd_occ_latch = 7'h00;
logic         recovery_flag, recovery_flag_d1;

// If FIFO fills, drop write data until it drains to wrlimit
always @ (posedge wr_clk) begin
  if (wr_full_n) begin
    allow_push <= 1'b0;
  end else if (wr_tlast & (wr_occ <= wrlimit)) begin
    allow_push <= 1'b1;
  end
end

stream_fifo #(
  .WIDTH_W  (9),
  .WIDTH_R  (36),
  .NUMWORDS (depth),
  .WIDTHU_W (wrbits),
  .WIDTHU_R (rdbits)
) stream_fifo_i (
  .wr_clk   (wr_clk),
  .wr_req   (wr_tvalid & allow_push),
  .wr_data  (wr_tdata),
  .wr_full  (wr_full_n),
  .wr_empty (),
  .wr_count (wr_occ),

  .rd_clk   (rd_clk),
  .rd_req   (rd_tready),
  .rd_data  (rd_tdata),
  .rd_empty (rd_empty_n),
  .rd_full  (),
  .rd_count (rd_occ),

  .aclr     (1'b0)
);

assign wr_tready = ~wr_full_n & allow_push;
assign rd_tvalid = ~rd_empty_n;

// Occupancy snapshot and stall/recovery flag reported to the host.
always @ (posedge rd_clk) begin
  if (rd_sample) begin
    rd_occ_latch <= rd_occ[(rdbits-1) -: 7];
    recovery_flag <= 1'b0;
    recovery_flag_d1 <= recovery_flag;
  end else if (rd_empty_n | ~allow_push) begin
    // Known CDC with allow_push, but okay since just status
    recovery_flag <= 1'b1;
  end
end

assign rd_status = {recovery_flag_d1,rd_occ_latch};

endmodule



//-----------------------------------------------------------------------------
// Audio / predistortion-table downstream FIFO: 8-bit bytes to 32-bit words.
//-----------------------------------------------------------------------------

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

logic         wr_full_n;
logic         rd_empty_n;

stream_fifo #(
  .WIDTH_W  (8),
  .WIDTH_R  (32),
  .NUMWORDS (8192),
  .WIDTHU_W (13),
  .WIDTHU_R (11)
) stream_fifo_i (
  .wr_clk   (wr_clk),
  .wr_req   (wr_tvalid),
  .wr_data  (wr_tdata),
  .wr_full  (wr_full_n),
  .wr_empty (),
  .wr_count (),

  .rd_clk   (rd_clk),
  .rd_req   (rd_tready),
  .rd_data  (rd_tdata),
  .rd_empty (rd_empty_n),
  .rd_full  (),
  .rd_count (),

  .aclr     (1'b0)
);

assign wr_tready = ~wr_full_n;
assign rd_tvalid = ~rd_empty_n;

endmodule

//-----------------------------------------------------------------------------
// Upstream RX I/Q FIFO: 24-bit data + user bits + last flag per word.
// Backpressure asserts from WRITE-side occupancy near full; the READ-side
// occupancy is exported separately as rd_tlength for packet sizing.
//-----------------------------------------------------------------------------

module usiq_fifo (
  wr_clk,
  wr_tdata,
  wr_tvalid,
  wr_tready,
  wr_tlast,
  wr_tuser,
  wr_aclr,

  rd_clk,
  rd_tdata,
  rd_tvalid,
  rd_tready,
  rd_tlast,
  rd_tuser,
  rd_tlength
);

parameter AK4951 = 0;

localparam TUSERWIDTH = (AK4951 == 1) ? 16 : 2;

input                       wr_clk;
input [23:0]                wr_tdata;
input                       wr_tvalid;
output                      wr_tready;
input                       wr_tlast;
input [TUSERWIDTH-1:0]      wr_tuser;
input                       wr_aclr;

input                       rd_clk;
output [23:0]               rd_tdata;
output                      rd_tvalid;
input                       rd_tready;
output                      rd_tlast;
output [TUSERWIDTH-1:0]     rd_tuser;
output [10:0]               rd_tlength;

localparam DATAW = TUSERWIDTH+24+1;

logic                       wr_full_n;
logic                       rd_empty_n;
logic [10:0]                wr_occ;
logic [DATAW-1:0]           rd_word;

stream_fifo #(
  .WIDTH_W           (DATAW),
  .WIDTH_R           (DATAW),
  .NUMWORDS          (1024),
  .WIDTHU_W          (11),
  .WIDTHU_R          (11),
  .ADD_USEDW_MSB     ("ON"),
  .WRITE_ACLR_SYNCH  ("ON")
) stream_fifo_i (
  .wr_clk   (wr_clk),
  .wr_req   (wr_tvalid),
  .wr_data  ({wr_tuser,wr_tlast,wr_tdata}),
  .wr_full  (wr_full_n),
  .wr_empty (),
  .wr_count (wr_occ),

  .rd_clk   (rd_clk),
  .rd_req   (rd_tready),
  .rd_data  (rd_word),
  .rd_empty (rd_empty_n),
  .rd_full  (),
  .rd_count (rd_tlength),

  .aclr     (wr_aclr)
);

assign wr_tready = (wr_occ > 11'd1012) ? 1'b0: 1'b1;
assign rd_tvalid = ~rd_empty_n;
assign rd_tlast  = rd_word[24];
assign rd_tdata  = rd_word[23:0];
assign rd_tuser  = rd_word[TUSERWIDTH+24:25];

endmodule



//-----------------------------------------------------------------------------
// Bandscope (raw ADC) upstream FIFO.  Fill-then-drain burst gate: samples
// accumulate silently until the FIFO is full, then the accumulated burst is
// presented continuously until it is drained.
//-----------------------------------------------------------------------------

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
input         wr_tvalid;   // Not used: samples pushed whenever allowed
output        wr_tready;

input         rd_clk;
output [11:0] rd_tdata;
output logic  rd_tvalid = 1'b0;
input         rd_tready;

logic         wr_full_n, wr_empty;
logic         rd_full, rd_empty;

logic         bs_ad9866_push = 1'b0;

// BS AD9866 State
always @ (posedge wr_clk) begin
  if (wr_empty) begin
    bs_ad9866_push <= 1'b1;
  end else if (wr_full_n) begin
    bs_ad9866_push <= 1'b0;
  end
end

assign wr_tready = bs_ad9866_push & ~wr_full_n;

stream_fifo #(
  .WIDTH_W  (12),
  .WIDTH_R  (12),
  .NUMWORDS (2048),
  .WIDTHU_W (11),
  .WIDTHU_R (11)
) stream_fifo_i (
  .wr_clk   (wr_clk),
  .wr_req   (bs_ad9866_push & ~wr_full_n),
  .wr_data  (wr_tdata),
  .wr_full  (wr_full_n),
  .wr_empty (wr_empty),
  .wr_count (),

  .rd_clk   (rd_clk),
  .rd_req   (rd_tready),
  .rd_data  (rd_tdata),
  .rd_empty (rd_empty),
  .rd_full  (rd_full),
  .rd_count (),

  .aclr     (1'b0)
);

// BS State
always @ (posedge rd_clk) begin
  if (rd_full) begin
    rd_tvalid <= 1'b1;
  end else if (rd_empty) begin
    rd_tvalid <= 1'b0;
  end
end

endmodule



//-----------------------------------------------------------------------------
// Firmware programming stream: 8-bit bytes, non-showahead (registered read).
//-----------------------------------------------------------------------------

module asmi_fifo (
  aclr,
  data,
  rdclk,
  rdreq,
  wrclk,
  wrreq,
  q,
  rdusedw);

  input        aclr;
  input [7:0]  data;
  input        rdclk;
  input        rdreq;
  input        wrclk;
  input        wrreq;
  output [7:0] q;
  output [9:0] rdusedw;

  stream_fifo #(
    .WIDTH_W   (8),
    .WIDTH_R   (8),
    .NUMWORDS  (1024),
    .WIDTHU_W  (10),
    .WIDTHU_R  (10),
    .SHOWAHEAD ("OFF")
  ) stream_fifo_i (
    .wr_clk   (wrclk),
    .wr_req   (wrreq),
    .wr_data  (data),
    .wr_full  (),
    .wr_empty (),
    .wr_count (),

    .rd_clk   (rdclk),
    .rd_req   (rdreq),
    .rd_data  (q),
    .rd_empty (),
    .rd_full  (),
    .rd_count (rdusedw),

    .aclr     (aclr)
  );

endmodule
