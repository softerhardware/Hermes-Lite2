`timescale 1ns / 1ps

module cmd_wbm #
(
    parameter WB_DATA_WIDTH = 32,                    // width of data bus in bits (8, 16, 32, or 64)
    parameter WB_ADDR_WIDTH = 6                      // width of address bus in bits
    //parameter WB_SELECT_WIDTH = (WB_DATA_WIDTH/8),   // width of word select bus (1, 2, 4, or 8)
)
(
	input  logic  clk,
  input  logic  rst,

  // Wishbone master interface
  output logic [WB_ADDR_WIDTH-1:0]   wbm_adr_o,   // ADR_O() address
  //input  logic [WB_DATA_WIDTH-1:0]   wbm_dat_i,   // DAT_I() data in
  output logic [WB_DATA_WIDTH-1:0]   wbm_dat_o,   // DAT_O() data out
  output logic                       wbm_we_o,    // WE_O write enable output
  //output logic [WB_SELECT_WIDTH-1:0] wbm_sel_o,   // SEL_O() select output
  output logic                       wbm_stb_o,   // STB_O strobe output
  input  logic                       wbm_ack_i,   // ACK_I acknowledge input
  //input  logic                       wbm_err_i,   // ERR_I error input
  output logic                       wbm_cyc_o,   // CYC_O cycle output
  output logic                       wbm_tga_o,

  // Command interface
  input logic                        cmd_resp_rqst,
  input logic                        cmd_write,  // Command write enable
  input logic [WB_ADDR_WIDTH-1:0]    cmd_addr,   // Command address
  input logic [WB_DATA_WIDTH-1:0]    cmd_data
);

logic         state = 1'b0;
logic         next_state;
logic [3:0]   timer = 4'h0;

assign wbm_adr_o = cmd_addr;
assign wbm_dat_o = cmd_data;
assign wbm_tga_o = cmd_resp_rqst;

// Control
localparam 
  WAIT0  = 1'b0,
  WAIT1  = 1'b1;

always @(posedge clk) begin
  if (rst) begin
    state <= WAIT0;
  end else begin
    state <= next_state;
  end
end

always @* begin
  next_state = state;

  case(state)

    WAIT0: begin
      if (cmd_write) next_state = WAIT1;
      wbm_we_o = 1'b0;
      wbm_stb_o = 1'b0;
      wbm_cyc_o = 1'b0;
    end

    WAIT1: begin
      if (wbm_ack_i | &timer) next_state = WAIT0;
      wbm_we_o = 1'b1;
      wbm_stb_o = 1'b1;
      wbm_cyc_o = 1'b1;
    end

  endcase
end

always @(posedge clk) begin
  if (rst | ~wbm_stb_o) timer <= 4'h0;
  else if (wbm_stb_o) timer <= timer + 1'b1;
end

endmodule