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


//  Led_flash - Copyright 2009, 2010, 2011  Phil Harman VK6APH

//////////////////////////////////////////////////////////////
//
//   Flash LED  
//
//////////////////////////////////////////////////////////////

//  Turn  LED on  whenever signal is high and then remain on
//  for 'period' seconds when it goes low


module Led_flash (clock, signal, LED, period);

input clock;
input signal;
output LED;
input [23:0]period;

reg [23:0]counter;
reg LED;

always @ (posedge clock)
begin
	if (signal) begin
		counter <= 0;
		LED <= 1'b0; 			// turn LED on whilst signal is high
		end
	else begin
	if (counter == period) begin
		LED <= 1'b1; 			// turn LED off when signal low after time period
		end
	else counter <= counter + 1'b1;
	end
end
endmodule