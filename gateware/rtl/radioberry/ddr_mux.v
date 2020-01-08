//------------------------------------------------------------------------------
//           Copyright (c) 2019 Johan Maas, PA3GSB
//
//			With special thanks to Rene Meerman PA3GUQ! 
//
//	The input data (24 bits) is requested from the FIFO ; after each edge controlled
//  by the firmware the data (4 bits) is provided to the output.
//------------------------------------------------------------------------------


module ddr_mux(
	 clk, 
	 reset,
	 rd_req,
	 in_last,
	 out_last,
	 in_data,
	 out_data);

	input clk;
	input reset;
	output rd_req;
	input in_last;
	output out_last;
	input [23:0] in_data;
	output [3:0] out_data;
	
	reg llast;
	reg[23:0] data;
	reg[7:0] mux8;	
	reg[1:0] mux_sel;
	reg[3:0] data_p;
	reg[3:0] data_n;					
								
	always @(negedge clk)
	begin
	  if (reset) begin
		mux_sel <= 0;
		rd_req <= 0;
		llast <= 0;
	  end else begin
		rd_req <= 0;
		mux_sel <= mux_sel +1;
		if (mux_sel == 2) begin
		  mux_sel <= 0;
		  rd_req <= 1;
		  data <= in_data;
		  llast <= in_last;
		end;
	  end
	end

	always @(mux_sel)
	begin
	  case (mux_sel)
		0: begin mux8 <= data[23:16]; end 
		1: begin mux8 <= data[15:8]; end 
		2: begin mux8 <= data[7: 0]; end 
		default:
		  mux8 <= 0;
	  endcase
	end

	always @(posedge clk)
	begin
	  if (reset) begin
		data_p <= 0;
		out_last <=0;
	  end else begin
		data_p <= mux8[7:4];
		out_last <= llast;
	  end
	end

	always @(negedge clk)
	begin
	  if (reset) begin
		data_n <= 0;
	  end else begin
		data_n <= mux8[3:0];
	  end
	end

	assign out_data = (clk == 1) ? data_p : data_n; 
	
endmodule