//-----------------------------------------------------------------------------
//                          old protocol TX send
//-----------------------------------------------------------------------------

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

//  Metis code copyright 2010, 2011, 2012, 2013, 2014, 2015 Phil Harman VK6(A)PH
// 2015 Steve Haynal KF7O

module Tx_send (
	input tx_clock,
	input Tx_reset,
	input run,
	input wide_spectrum,
	input IP_valid,
	input [7:0] Hermes_serialno,
	input IDHermesLite,
	input  [8:0]AssignNR,

	input [7:0] PHY_Tx_data,
	input [10:0] PHY_Tx_rdused,
	output reg Tx_fifo_rdreq,

	input [47:0] This_MAC,
	input discovery,

	input [7:0] sp_fifo_rddata,
	input have_sp_data,
	output reg sp_fifo_rdreq,

	input udp_tx_enable,
	input udp_tx_active,
	output reg udp_tx_request,
	output [7:0] udp_tx_data,
	output reg [10:0] udp_tx_length
);


// HPSDR specific			
parameter HPSDR_frame = 8'h01;  	// HPSDR Frame type
parameter Type_1 = 8'hEF;	    	// Ethernet Frame type
parameter Type_2 = 8'hFE;

localparam
	START = 0,
	UDP1  = 1,
	UDP2  = 2,
	WIDE1 = 3,
	WIDE2 = 4,
	DISCOVER1 = 5,
	DISCOVER2 = 6;

reg [31:0] sequence_number = 0;
reg [31:0] spec_seq_number = 0;

reg [2:0] state;             	

reg [10:0] byte_no;

reg [7:0] tx_data;

assign udp_tx_data = tx_data;

wire [7:0] emuID [0:9];
assign emuID[0]  = IDHermesLite ? 8'h06 : 8'h01;
// emuID for SkimSrv / aka CW Skimmer HERMESLT
assign emuID[1]  = "H";
assign emuID[2]  = "E";
assign emuID[3]  = "R";
assign emuID[4]  = "M";
assign emuID[5]  = "E";
assign emuID[6]  = "S";
assign emuID[7]  = "L";
assign emuID[8]  = "T";
assign emuID[9]  = AssignNR;

always @ (posedge tx_clock)	
begin
case(state)

START:
	begin
		byte_no <= 11'd0;
		udp_tx_request <= 1'b0;
		udp_tx_length <= 11'd0;

		if (run == 1'b0) begin
			sequence_number <= 32'd0;  		// reset sequence numbers when not running.
			spec_seq_number <= 32'd0;
		end 
		if (discovery && IP_valid) begin		// only respond if we have a valid IP address
			udp_tx_request <= 1'b1;
			udp_tx_length <= 11'd60;
			state <= DISCOVER1;
		end 		
		else if (PHY_Tx_rdused > 11'd1023  && !Tx_reset && run) begin	// wait until we have at least 1024 bytes in Tx fifo													
			udp_tx_request <= 1'b1;
			udp_tx_length <= 11'd1032;
			state <= UDP1;
		end	
		else if (have_sp_data && wide_spectrum) begin		// Spectrum fifo has data available
			udp_tx_request <= 1'b1;
			udp_tx_length <= 11'd1032;
			state <= WIDE1;
		end
   end

// start sending UDP/IP data   
UDP1:
	begin
		udp_tx_request <= 1'b1;
		if (udp_tx_enable) begin
			tx_data <= Type_1;
			state <= UDP2;
		end
	end

UDP2:
	begin
		if (byte_no < 11'd1031) begin // Total-1 	
			if (udp_tx_active) begin
				case (byte_no)
					 11'd0: tx_data <= Type_2;					
					 11'd1: tx_data <= HPSDR_frame; 
					 11'd2: tx_data <= 8'h06;
					 11'd3: tx_data <= sequence_number[31:24];
					 11'd4: tx_data <= sequence_number[23:16];
					 11'd5: begin tx_data <= sequence_number[15:8]; Tx_fifo_rdreq <= 1'b1; end
					 11'd6: begin tx_data <= sequence_number[7:0]; Tx_fifo_rdreq <= 1'b1; end  	
					 11'd1029: Tx_fifo_rdreq <= 1'b0; // Total-3
					 default: tx_data <= PHY_Tx_data;		 
				endcase				
				byte_no <= byte_no + 11'd1;
			end 
		end
		else begin
			sequence_number <= sequence_number + 1'b1;
			state <= START;
		end
	end

// start sending UDP/IP data   
WIDE1:
	begin
		udp_tx_request <= 1'b1;
		if (udp_tx_enable) begin
			tx_data <= Type_1;
			state <= WIDE2;
		end
	end

WIDE2:
	begin
		if (byte_no < 11'd1031) begin // Total-1 	
			if (udp_tx_active) begin
				case (byte_no)
					 11'd0: tx_data <= Type_2;					
					 11'd1: tx_data <= HPSDR_frame; 
					 11'd2: tx_data <= 8'h04;
					 11'd3: tx_data <= spec_seq_number[31:24];
					 11'd4: tx_data <= spec_seq_number[23:16];
					 11'd5: begin tx_data <= spec_seq_number[15:8]; sp_fifo_rdreq <= 1'b1; end
					 11'd6: begin tx_data <= spec_seq_number[7:0]; sp_fifo_rdreq <= 1'b1; end  	
					 11'd1029: sp_fifo_rdreq <= 1'b0; // Total-3
					 default: tx_data <= sp_fifo_rddata;		 
				endcase				
				byte_no <= byte_no + 11'd1;
			end 
		end
		else begin
			spec_seq_number <= spec_seq_number + 1'b1; 
			state <= START;
		end
	end

DISCOVER1:
	begin
		udp_tx_request <= 1'b1;
		if (udp_tx_enable) begin
			tx_data <= Type_1;
			state <= DISCOVER2;
		end
	end

DISCOVER2:
	begin
		if (byte_no < 11'd59) begin // Total-1
			if (udp_tx_active) begin
				case (byte_no)
					 11'd0: tx_data <= Type_2;					
					 11'd1: tx_data <= run ? 8'h03 : 8'h02;
					 11'd2: tx_data <= This_MAC[47:40];
					 11'd3: tx_data <= This_MAC[39:32];
					 11'd4: tx_data <= This_MAC[31:24];
					 11'd5: tx_data <= This_MAC[23:16];
					 11'd6: tx_data <= This_MAC[15:8];
					 11'd7: tx_data <= This_MAC[7:0];
					 11'd8: tx_data <= Hermes_serialno;
					 11'd9: tx_data <= emuID[0]; // IDHermesLite ? 8'h06 : 8'h01;
					 11'd10: tx_data <= emuID[1]; // "H"
					 11'd11: tx_data <= emuID[2]; // "E"
					 11'd12: tx_data <= emuID[3]; // "R"
					 11'd13: tx_data <= emuID[4]; // "M"
					 11'd14: tx_data <= emuID[5]; // "E"
					 11'd15: tx_data <= emuID[6]; // "S"
					 11'd16: tx_data <= emuID[7]; // "L"
					 11'd17: tx_data <= emuID[8]; // "T"
					 11'd18: tx_data <= emuID[9]; // NR
					 default: tx_data <= emuID[0];
				endcase				
				byte_no <= byte_no + 11'd1;
			end
		end
		else begin
			state <= START;
		end
	end
endcase
end

endmodule
