//
//  HPSDR - High Performance Software Defined Radio
//
//  Metis code. 
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

//  Copyright P Harman VK6APH  2012



// Clock Domain Crossing.  Uses a handshaking method (rdy/ack) to transfer data across a Multi Cycle Path
`timescale 1 ns/100 ps

module cdc_mcp #(parameter SIZE=1, TPD = 0.5)
  (input  wire            a_rst, a_clk,
   input  wire [SIZE-1:0] a_data,
   input  wire            a_data_rdy,
   input  wire            b_rst, b_clk, 
   output reg  [SIZE-1:0] b_data,
   output reg             b_data_ack);

reg  a_rdy;
wire a_data_ack, b_data_rdy;
wire b_data_rdy_pulse;

always @(posedge a_clk)
begin
  if (a_rst)
    a_rdy <= #TPD 1'b0;
  else if (a_data_rdy)   // domain A is ready to send MCP data from domain A
    a_rdy <= #TPD 1'b1;
  else if (a_data_ack)   // data has been received by domain B
    a_rdy <= #TPD 1'b0;  // clear this now so domain B knows handshake has completed
end

cdc_sync rdy (.siga(a_rdy), .rstb(b_rst), .clkb(b_clk), .sigb(b_data_rdy));

pulsegen pls (.sig(b_data_rdy), .rst(b_rst), .clk(b_clk), .pulse(b_data_rdy_pulse));

cdc_sync ack (.siga(b_data_ack), .rstb(a_rst), .clkb(a_clk), .sigb(a_data_ack));


always @(posedge b_clk)
begin
  if (b_rst)
    b_data <= #TPD 1'b0;
  else if (b_data_rdy_pulse)   // domain B is ready to latch the MCP data from domain A
    b_data <= #TPD a_data;

  if (b_rst)
    b_data_ack <= #TPD 1'b0;
  else
    b_data_ack <= #TPD b_data_rdy; // Note: b_data_ack and b_data change at the same b_blk rising edge
end

endmodule
