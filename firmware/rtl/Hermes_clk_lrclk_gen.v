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

// (C) Phil Harman VK6APH, Kirk Weedman KD7IRS 20019, 2012



// Created by Kirk Weedman KD7IRS - Feb 15, 2009
//
// Modified by Phil Harman VK6APH - 11 Nov 2009 to be fixed at 48kHz
//
// BCLK and LRCLK are all generated synchronously to CLK_IN.

`timescale 1 ns/100 ps

module Hermes_clk_lrclk_gen (reset, CLK_IN, BCLK, Brise, Bfall, LRCLK, LRrise, LRfall);


localparam BCLK_DIV = (CLK_FREQ/48000/64);
localparam BCLK_00 = 32;

parameter CLK_FREQ  = 122880000;   // frequency of incoming clock

input   wire          reset;       // reset
input   wire          CLK_IN;
output  reg           BCLK;
output  reg           Brise;
output  reg           Bfall;
output  reg           LRCLK;
output  reg           LRrise;
output  reg           LRfall;

localparam LS = clogb2 (32-1); // 0 to (BCLK_10-1)

// internal signals
reg    [15:0] BCLK_cnt;
//reg    [15:0] BCLK_DIV;
reg  [LS-1:0] LRCLK_cnt;

localparam TPD = 1;



// CLK_IN gets divided down to create BCLK
always @ (posedge CLK_IN)
begin
  if (reset)
    BCLK_cnt <= #TPD 0;
  else if (BCLK_cnt == (BCLK_DIV-1))
    BCLK_cnt <= #TPD 0;
  else
    BCLK_cnt <= #TPD BCLK_cnt + 1'b1; // 0, 1, ...(BCLK_DIV-1), 0, ...

  if (reset)
    Brise <= 1'b0;
  else
    Brise <= (BCLK_cnt == (BCLK_DIV/2));

  if (reset)
    Bfall <= 1'b0;
  else
    Bfall <= (BCLK_cnt == 1'b0); // may not be a 50/50 duty cycle

  if (Brise)
    BCLK  <= #TPD 1'b1;
  else if (Bfall)
    BCLK  <= #TPD 1'b0;

  if (reset)
    LRCLK_cnt <= #TPD 0;
  else 
  begin
    if ((LRCLK_cnt == 0) && Bfall)
    begin
        LRCLK_cnt <= #TPD BCLK_00-1;
    end
    else if (Bfall)
      LRCLK_cnt <= #TPD LRCLK_cnt - 1'b1;
  end

  if (reset)
    LRCLK  <= #TPD 1'b1;
  else if ((LRCLK_cnt == 0) && Bfall)
    LRCLK  <= #TPD ~LRCLK;  

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