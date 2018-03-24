//
//  HPSDR - High Performance Software Defined Radio
//
//  Hermes code. 
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
// (C) Phil Harman VK6APH, Kirk Weedman KD7IRS 20019, 2012
//
// Created by Kirk Weedman KD7IRS - Feb 15, 2009
//
// Modified by Phil Harman VK6APH - 11 Nov 2009 to be fixed at 48kHz
// BCLK and LRCLK are all generated synchronously to CLK_IN.
//
// Modified for Hermes-Lite v1.22,  by JI1UDD - 20 July, 2016
//  Add MCLK that is generated synchronously.
`timescale 1 ns/100 ps

module Hermes_clk_lrclk_gen (reset, CLK_IN, BCLK, Brise, Bfall, LRCLK, LRrise, LRfall, MCLK, MCLKrise);

input   wire          reset;		// reset
input   wire          CLK_IN;		// clock
output  reg           BCLK;		// 3.072MHz
output  reg           Brise;
output  reg           Bfall;
output  reg           LRCLK;		// 48kHz
output  reg           LRrise;
output  reg           LRfall;
output  reg           MCLK;		// 12.288MHz@H-L
output  wire			 MCLKrise;

parameter  CLK_FREQ = 73728000;			// frequency of incoming clock
localparam BCLK_DIV = (CLK_FREQ/48000/64);	// 24 @73.728M
localparam MCLK_DIV = (CLK_FREQ/48000/512);	//  3 @73.728M
localparam BCLK_00  = 32;
localparam LS = clogb2 (32-1);			// 0 to (BCLK_10-1)

// internal signals
reg    [15:0] BCLK_cnt;
reg  [LS-1:0] LRCLK_cnt;
reg     [1:0] MCLK_cnt;
assign MCLKrise = ( ~MCLK && (MCLK_cnt == (MCLK_DIV-1))) ;

// CLK_IN gets divided down to create BCLK/MCLK
always @ (posedge CLK_IN)
begin
  if (reset) begin
    MCLK_cnt <= 2'b0;
    MCLK     <= 1'b0;
  end else if (MCLK_cnt == (MCLK_DIV-1)) begin
    MCLK_cnt <= 2'b0;
    MCLK     <= ~MCLK;
  end else
    MCLK_cnt <= MCLK_cnt + 1'b1;		// 0, 1, ...(MCLK_DIV-1), 0, ...

  if (reset)
    BCLK_cnt <= 16'b0;
  else if (BCLK_cnt == (BCLK_DIV-1))
    BCLK_cnt <= 16'b0;
  else
    BCLK_cnt <= BCLK_cnt + 1'b1;		// 0, 1, ...(BCLK_DIV-1), 0, ...

  if (reset)
    Brise <= 1'b0;
  else
    Brise <= (BCLK_cnt == (BCLK_DIV/2));

  if (reset)
    Bfall <= 1'b0;
  else
    Bfall <= (BCLK_cnt == 1'b0);		// may not be a 50/50 duty cycle

  if (Brise)
    BCLK  <= 1'b1;
  else if (Bfall)
    BCLK  <= 1'b0;

  if (reset)
    LRCLK_cnt <= 0;
  else 
  begin
    if ((LRCLK_cnt == 0) && Bfall)
      LRCLK_cnt <= BCLK_00 - 1'b1;
    else if (Bfall)
      LRCLK_cnt <= LRCLK_cnt - 1'b1;
  end

  if (reset)
    LRCLK  <= 1'b1;
  else if ((LRCLK_cnt == 0) && Bfall)
    LRCLK  <= ~LRCLK;  

  if (reset)
    LRrise <= 1'b0;
  else
    LRrise <= (LRCLK_cnt == 0) && Bfall && !LRCLK;

  if (reset)
    LRfall <= 1'b0;
  else
    LRfall <= (LRCLK_cnt == 0) && Bfall && LRCLK; // may not be a 50/50 duty cycle
end

function integer clogb2;
input [31:0] depth;
begin
  for(clogb2=0; depth>0; clogb2=clogb2+1)
  depth = depth >> 1;
end
endfunction
endmodule