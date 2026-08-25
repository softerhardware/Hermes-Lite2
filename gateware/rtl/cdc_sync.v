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




// Simple Clock Domain Crossing module that double buffers data.
//
// NOTE: currently uninstantiated in all builds; it is kept as a reference
// CDC primitive for future work (see Refactor-Plan R4).  The previous
// SIMULATION model attempted a randomized-delay metastability injector but
// its DLY register never toggled, leaving that logic inert; it has been
// replaced by the plain behavioral model below.

`timescale 1 ns/100 ps

module cdc_sync #(parameter SIZE=1)
  (input  wire [SIZE-1:0] siga,
   input  wire            rstb, clkb, 
   output reg  [SIZE-1:0] sigb);

`ifdef SIMULATION
reg [SIZE-1:0] q1;

always @(posedge clkb)
begin
  if (rstb)
    {sigb,q1} <= '0;
  else
    {sigb,q1} <= {q1,siga};
end
`else // synthesis
reg [SIZE-1:0] q1;

always @(posedge clkb)
begin
  if (rstb)
    {sigb,q1} <= 2'b00;
  else
    {sigb,q1} <= {q1,siga};
end
`endif
endmodule