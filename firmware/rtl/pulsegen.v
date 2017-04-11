
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

// (C) Kirk Weedman KD7IRS  2006, 2007, 2008, 2009, 2010, 2011, 2012 



// create a pulse for the rising edge of a signal

/*

          +--+  +--+  +--+  +--+  +--+  +--+  +--+  +--+  +--+  +--+  +--+  +--+
clk 	  --+  +--+  +--+  +--+  +--+  +--+  +--+  +--+  +--+  +--+  +--+  +--+

                            +-----------------------------------------------------
sig     --------------------+

										    +------------------------------------------------
p1      --------------------------+

		  --------------------------+
!p1     					             +------------------------------------------------

							       +-----+
pulse   --------------------+     +------------------------------------------------


*/


`timescale 1 ns/100 ps

module pulsegen (
input wire sig,
input wire rst,
input wire clk,
output wire pulse);

parameter TPD = 0.7;

reg p1;
always @(posedge clk)
begin
  if (rst)
    p1 <= #TPD 1'b0;
  else
    p1 <= #TPD sig; // sig must be synchronous to clk
end

assign pulse = sig & !p1; // one clk wide signal at the rising edge of sig

endmodule