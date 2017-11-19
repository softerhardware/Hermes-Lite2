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
// (C) Takashi Komatsumoto, JI1UDD 2017

`timescale 1 ns/100 ps

module cdc_sync_rst (
  input  wire rsta,
  input  wire clkb,
  output wire rstb
);

wire rstn = ~rsta ;
reg q ;
reg [1:0] sync ;

always @(posedge clkb or negedge rstn) begin
  if (!rstn)
    q <= 1'b1 ;
  else
    q <= 1'b0 ;
end

always @(posedge clkb) begin
  sync <= {sync[0],q};
end


assign rstb = rsta | sync[1] ;

endmodule