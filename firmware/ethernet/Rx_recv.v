//-----------------------------------------------------------------------------
//                          old protocol RX recv
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

module Rx_recv (
	input rx_clk,
	output reg run,
	output reg wide_spectrum,
	output discovery_reply,
	input [15:0] to_port,
	input broadcast,
	input rx_valid,
	input [7:0] rx_data,
	output [7:0] rx_fifo_data,
	output reg rx_fifo_enable,
        input dst_unreachable
);

// Receive states
localparam	START = 3'h0,
			PREAMBLE1 = 3'h1,
			PREAMBLE2 = 3'h2,
			METIS_DISCOVERY = 3'h3,
			WRITEIP= 3'h4,
			RUN = 3'h5,
			SEND_TO_FIFO = 3'h6;

reg [2:0] rx_state;
reg [10:0] byte_cnt;

assign discovery_reply = (rx_state == METIS_DISCOVERY);

always @ (posedge rx_clk)						

case (rx_state)

START:
	begin
		rx_fifo_enable <= 1'b0;
		if (rx_valid && rx_data == 8'hef && to_port == 1024) rx_state <= PREAMBLE1;
                else if (dst_unreachable) begin
                   run <= 1'b0;
                   wide_spectrum <= 1'b0;
                   rx_state <= START;
                end
		else rx_state <= START;
	end

PREAMBLE1:
	begin
		if (rx_valid && rx_data == 8'hfe && to_port == 1024) rx_state <= PREAMBLE2;
		else rx_state <= START;
	end

// byte_cnt is 1 starting in PREAMBLE2
PREAMBLE2:
	begin
		if (rx_valid && rx_data == 8'h01) rx_state <= SEND_TO_FIFO;
		else if (rx_valid && rx_data == 8'h04) rx_state <= RUN;	
		else if (rx_valid && broadcast && rx_data == 8'h02) rx_state <= METIS_DISCOVERY;
		else if (rx_valid && broadcast && !run && rx_data == 8'h03) rx_state <= WRITEIP;
		else rx_state <= START;
	end

METIS_DISCOVERY:
	begin
		rx_state <= START;
	end

WRITEIP:
	begin
		rx_state <= START;
	end

RUN:
	begin
		run <= rx_data[0];
		wide_spectrum <= rx_data[1];
		rx_state <= START;
	end

SEND_TO_FIFO:
	begin
		if (byte_cnt == 11'h02 && rx_data != 8'h02) rx_state <= START;
		else if (byte_cnt == 11'h406) begin
			rx_fifo_enable <= 1'b0;
			rx_state <= START;
		// Wait until sequence numbers (3,4,5,6) are done as ignored in Hermes-Lite
		end else if (byte_cnt >= 11'h006) rx_fifo_enable <= 1'b1; 
	end

endcase

always @ (posedge rx_clk)
	if (rx_state == START) byte_cnt <= 11'h000;
	else byte_cnt <= byte_cnt + 11'h001;

// Add pipestage to match rx_fifo_enable
//always @ (posedge rx_clk) rx_fifo_data <= rx_data;
assign rx_fifo_data = rx_data;

endmodule
