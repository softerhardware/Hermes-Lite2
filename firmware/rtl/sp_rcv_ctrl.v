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


//  SP_fifo receive control  - Copyright 2009, 2010, 2011, 2012  Phil Harman VK6APH

/*
	The SP_fifo is filled with 16k consecutive samples from the ADC. The code loops
	until the fifo is empty then fills again.	
*/




module sp_rcv_ctrl (clk, reset, sp_fifo_wrempty, sp_fifo_wrfull, write, have_sp_data );

input wire clk;
input wire sp_fifo_wrempty;
input wire sp_fifo_wrfull;
input wire reset;

output wire write;
output wire have_sp_data;

reg state;
reg wrenable;

always @(posedge clk)
begin
  if (reset) begin 
    wrenable <= 1'b0;
  end 
 
// load SP_fifo with 16k raw 16 bit ADC samples every time it is empty    
case(state)
0: begin 
	if (sp_fifo_wrempty) begin  		// enable write to SP_fifo
		wrenable <= 1'b1;
		state <= 1'b1;
	end 
   end 
   
1: begin 
	if (sp_fifo_wrfull) begin			// disable write to SP_fifo
	   wrenable <= 1'b0;
	   state <= 1'b0;
	end
   end 
default: state <= 1'b0;
endcase
end

assign write = wrenable;   
assign have_sp_data = !wrenable;	 	// indicate data is availble to be read


endmodule
