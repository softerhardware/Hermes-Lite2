// Copyright 2009  Kirk Weedman KD7IRS 
//
//  HPSDR - High Performance Software Defined Radio
//
//  Mercury to Atlas bus interface.
//
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
// Change log:
//
// 25 Jan 2009 - first version
//
// This is a parameterized module
//
// xLData and xRData are all generated synchronously to xclk.
// Since BCLK and LRCLK are not synchronous to xclk they will be double buffered to
// to the xclk domain
//
// 21 Jul 2017 - Modified for AK4951, i2s word width is 24bits. - ji1udd
//
`timescale 1 ns/100 ps

module I2S_rcv_24b (xrst, xclk, xlrclk, xBrise, xBfall, xLRrise, xLRfall,
                xData, xData_rdy, BCLK, LRCLK, din);
parameter DATA_BITS = 32;           // size of left plus right data - MUST be EVEN number!
parameter BCNT      = 1;            // which b_clk, after lr_clk goes low, to start using
parameter DSTRB     = 0;            // which position in b_clk to grab data
// BCNT and DS can fine tune where we capture

localparam XS = DATA_BITS;
localparam DS = DATA_BITS/2;        // size of left/right data
localparam SS = clogb2(DS+BCNT+1);  // number of bits to hold range from 0 - ((DS+BCNT+1)-1)
localparam WW = 24;                 // i2s word width 24bit

input   wire          xrst;         // reset
input   wire          xclk;
output  reg           xlrclk;
output  wire          xBrise;
output  wire          xBfall;
output  wire          xLRrise;
output  wire          xLRfall;
output  reg  [XS-1:0] xData;        // {Left,Righ} data
output  reg           xData_rdy;    // one xclk wide pulse
input   wire          BCLK;         // not in xclk domain
input   wire          LRCLK;        // not in xclk domain
input   wire          din;          // data synchronous to BCLK/LRCLK

// internal signals
reg  [SS-1:0] shift_cnt;          // shift counter
reg  [WW-1:0] temp_data;          // holds DOUT
wire [WW-1:0] temp_data_round = (&{~temp_data[WW-1],temp_data[WW-2 -:DS]})? 24'h7FFFFF : temp_data+8'h80 ;
reg           b_clk;              // in the "xclk" domain
reg           bc1, bc0, lr1, lr0; // used in getting BCLK/LRCLK into "xclk" domain
reg     [9:0] b_clk_cnt;          // how many xclk's after rising edge of b_clk to grab din
reg           d2, d1, d0;

localparam IF_TPD = 1;
localparam I2S_IDLE  = 0,
           I2S_LEFT  = 1,
           I2S_RIGHT = 2;

assign xBrise  =  bc1 & !b_clk;
assign xBfall  = !bc1 &  b_clk;
assign xLRrise =  lr1 & !xlrclk;
assign xLRfall = !lr1 &  xlrclk;

always @ (posedge xclk)
begin
  if (xrst)
    b_clk_cnt <= #IF_TPD 0;
  else if (xBrise)
    b_clk_cnt <= #IF_TPD 0; // rising edge - reset position
  else
    b_clk_cnt <= #IF_TPD b_clk_cnt + 1'b1; // 0, 1, ...

  if (b_clk_cnt == DSTRB) // DSTRB should be small enough so this happens once every BCLK cycle
    temp_data[WW-1:0] <= {temp_data[WW-2:0], d2};

  {d2, d1, d0}        <= #IF_TPD {d1, d0, din};
  {b_clk,  bc1, bc0}  <= #IF_TPD {bc1, bc0, BCLK};
  {xlrclk, lr1, lr0}  <= #IF_TPD {lr1, lr0, LRCLK};

  if (xrst)
    shift_cnt <= #IF_TPD 0;
  else if (xLRfall || xLRrise)
    shift_cnt <= #IF_TPD 0;
  else if (shift_cnt != {SS{1'b1}}) // wait here so we dont accidentally reload xLData & xRData
  begin
    if (xBrise)
      shift_cnt <= #IF_TPD shift_cnt + 1'b1;
  end

  if ((shift_cnt == (WW+BCNT)) && (b_clk_cnt == DSTRB) && !xlrclk)
    xData[XS-1:DS]  <= #IF_TPD temp_data_round[WW-1 -: DS] ;

  if ((shift_cnt == (WW+BCNT)) && (b_clk_cnt == DSTRB) && xlrclk)
    xData[DS-1:0]   <= #IF_TPD temp_data_round[WW-1 -: DS] ;

  if ((shift_cnt == (WW+BCNT)) && (b_clk_cnt == DSTRB) && xlrclk)
    xData_rdy <= 1'b1;
  else
    xData_rdy <= 1'b0;
end

function integer clogb2;
input [31:0] depth;
begin
  for(clogb2=0; depth>0; clogb2=clogb2+1)
  depth = depth >> 1;
end
endfunction

endmodule