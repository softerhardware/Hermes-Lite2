//
//  External Amplifier Band Control for Hermes-Lite v2
//    Send Elecraft FA(VFO A Frequency) command (UART)
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
//
// (C) Takashi Komatsumoto, JI1UDD 2018, 2019

`timescale 1 ns/100 ps

module extamp (
  input        clk,
  input [31:0] freq,       // less than 100,000,000Hz
  input        ptt,
  output       uart_txd    // data1: High, data0: Low
);

// -------------------
//  Declare parameter
// -------------------
localparam CLKFREQ  = 2500000 ; // Hz
localparam BAUDRATE = 9600 ;     // bps

// ---------------------
//  Baud Rate Generator
// ---------------------
reg        uart_tx_start = 1'b0 ;
reg [8:0] uart_br_cnt   = 9'b0;
wire       uart_shift = (uart_br_cnt==9'b0);

always @ (posedge clk) 
  if (uart_tx_start | uart_shift)
    uart_br_cnt <= (CLKFREQ / BAUDRATE) -1 ;
  else
    uart_br_cnt <= uart_br_cnt - 1'b1 ;

// -------------------------
//  UART 1 byte transmitter
// -------------------------
reg [7:0] uart_tx_data   = 8'b0 ;
reg [8:0] uart_shift_reg = 9'b1;
reg [3:0] uart_shift_cnt = 4'b0;
wire uart_shift_end = (uart_shift_cnt==4'b0) ;

always @ (posedge clk) begin
  if (uart_tx_start) begin
    uart_shift_cnt <= 4'd9 ;
    uart_shift_reg <= {uart_tx_data,1'b0} ;
  end else if (uart_shift & (!uart_shift_end)) begin
    uart_shift_cnt <= uart_shift_cnt - 1'b1;
    uart_shift_reg <= {1'b1,uart_shift_reg[8:1]};
  end
end

assign uart_txd = ~uart_shift_reg[0] ;
wire   uart_tx_end = uart_shift_end & uart_shift ;

// -----------------------
//  Convert Binary to BCD
// ------------------------
reg        cv_start = 1'b0 ;
reg [31:0] freq_bin = 32'b0;
reg [31:0] bcd;
reg [31:0] bin;
reg  [7:0] cvcnt    = 8'd0;
wire cv_end = (cvcnt==8'd65);

always @ (posedge clk) begin
  if (cvcnt==8'd0) begin
    if (cv_start) begin
      cvcnt <= 8'd1;
      bcd   <= 12'b0 ;
      bin   <= freq_bin;
    end
  end else if (cv_end) begin
    cvcnt <= 8'd0 ;
  end else begin
    if (cvcnt[0]==1'b1) begin
      if (bcd[31:28] >= 4'd5) bcd[31:28] <= bcd[31:28] + 2'd3 ;
      if (bcd[27:24] >= 4'd5) bcd[27:24] <= bcd[27:24] + 2'd3 ;
      if (bcd[23:20] >= 4'd5) bcd[23:20] <= bcd[23:20] + 2'd3 ;
      if (bcd[19:16] >= 4'd5) bcd[19:16] <= bcd[19:16] + 2'd3 ;
      if (bcd[15:12] >= 4'd5) bcd[15:12] <= bcd[15:12] + 2'd3 ;
      if (bcd[11: 8] >= 4'd5) bcd[11: 8] <= bcd[11: 8] + 2'd3 ;
      if (bcd[ 7: 4] >= 4'd5) bcd[ 7: 4] <= bcd[ 7: 4] + 2'd3 ;
      if (bcd[ 3: 0] >= 4'd5) bcd[ 3: 0] <= bcd[ 3: 0] + 2'd3 ;
    end else begin
      {bcd,bin} <= {bcd[30:0],bin,1'b0};
    end
    cvcnt <= cvcnt + 1'd1;
  end
end

// ---------------------
//   Command Sequencer
// ---------------------
wire [111:0] cmd = {8'h46,8'h41,8'h30,8'h30,8'h30,      // FA000
                    4'h3, bcd[31:28], 4'h3, bcd[27:24],
                    4'h3, bcd[23:20], 4'h3, bcd[19:16],
                    4'h3, bcd[15:12], 4'h3, bcd[11: 8],
                    4'h3, bcd[ 7: 4], 4'h3, bcd[ 3: 0],
                    8'h3b};                             // ;
reg cmd_pending = 1'b0 ;
reg [31:0] freq_prev = 32'd0 ;

always @ (posedge clk) begin
  if (!cmd_pending)
    freq_prev <= freq ;
end
wire cmd_start = (freq_prev != freq) ;

reg [3:0]  cmd_cnt = 4'd0;
wire [6:0] cmd_pos = 7'd111 - ((cmd_cnt - 1'b1) << 3) ;
reg detect_ptt = 1'b0 ;
reg cmd_start_2nd = 1'b0 ;

always @ (posedge clk) begin
  if (cmd_cnt==4'd0) begin
    cmd_pending <= 1'b0 ;
    if (ptt) begin
      detect_ptt <= 1'b1;
    end
    if (cmd_start | cmd_start_2nd) begin
      cmd_start_2nd <= 1'b0;
      freq_bin <= freq ;
      cv_start <= 1'b1 ;
      cmd_cnt <= cmd_cnt + 1'b1 ;
    end
  end else if (cmd_cnt==4'd1) begin
    cmd_pending <= 1'b1 ;
    if (cv_end) begin
      cv_start <= 1'b0 ;
      uart_tx_data <= cmd [cmd_pos -: 8] ;
      uart_tx_start <= 1'b1 ;
      cmd_cnt <= cmd_cnt + 1'b1 ;
    end
  end else begin
    if (uart_tx_end) begin
	   if (cmd_cnt==4'd15) begin
		  cmd_cnt <= 4'd0;
          if (detect_ptt) begin
            cmd_start_2nd <= 1'b1;
            detect_ptt <= 1'b0;
          end
		end else begin
        uart_tx_data <= cmd [cmd_pos -: 8] ;
        uart_tx_start <= 1'b1 ;
        cmd_cnt <= cmd_cnt + 1'b1 ;
		end
    end else begin
      uart_tx_start <= 1'b0 ;
    end
  end
end

endmodule
