// V1.1 22 November 2009
//
// Copyright 2007, 2008, 2009 Phil Harman VK6APH
//
//  HPSDR - High Performance Software Defined Radio
//
//
//  ADC module for driving ADC78H90 
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

//  SCI inteface to ADC78H90 

//  Hermes uses inputs AIN1 to AIN6
//  SCLK can run at 8MHz max and is = clock/4 
//  Note: AINx data can be latched using nCS
//  IMPORTANT:  When using multiple addresses the data returned while the current address is 
//       	    being sent is from the PREVIOUS address.

//  

module Hermes_ADC(clock, SCLK, nCS, MISO, MOSI, AIN1, AIN2, AIN3, AIN4, AIN5, AIN6);

input  wire       clock;
output reg        SCLK;
output reg        nCS;
input  wire       MISO;
output reg        MOSI;
output reg [11:0] AIN1; // 
output reg [11:0] AIN2; // 
output reg [11:0] AIN3; // 
output reg [11:0] AIN4; // 
output reg [11:0] AIN5; // holds VFWD volts
output reg [11:0] AIN6; // holds 13.8v supply voltage

reg  [15:0] ADC_address;
reg   [2:0] ADC_state;
reg   [3:0] bit_cnt;
reg  [11:0] temp_1;	
reg  [11:0] temp_2;
reg  [11:0] temp_3;
reg  [11:0] temp_4;
reg  [11:0] temp_5;
reg  [11:0] temp_6; 

// NOTE: this code generates the SCLK clock for the ADC
always @ (posedge clock)
begin
  case (ADC_state)
  0:
	begin
    nCS       <= 1'b1;          // set nCS high
    bit_cnt   <= 4'd15;         // set bit counter
    if (ADC_address[13:11] == 3'd5)
		ADC_address <= 16'b0;		// reset ADC address
	else ADC_address <= ADC_address + 16'b0000_1000_0000_0000;  // increment ADC address
    ADC_state <= 1;
	end
	
  1:
	begin
    nCS       <= 0;             		// select ADC
    MOSI      <= ADC_address[bit_cnt];	// shift data out to MOSI
    ADC_state <= 2;
	end
	
  2:
	begin
    SCLK      <= 1'b1;          // SCLK high
    ADC_state <= 3;
	end
	
  3:
	begin
    SCLK      <= 1'b0;          // SCLK low
    ADC_state <= 4;
	end

  4:
	begin
		if (bit_cnt == 0)           // restart
		  ADC_state <= 0;
		else
		begin
		  bit_cnt   <= bit_cnt - 1'b1; // do all again
		  ADC_state <= 1;
		end
	end 
	
  default:
    ADC_state <= 0;
  endcase
end 

always @ (posedge clock)
begin
  if (ADC_state == 0) begin 		// latch data when not shifting
	AIN1 <= temp_1;
	AIN2 <= temp_2;
	AIN3 <= temp_3;
	AIN4 <= temp_4;
	AIN5 <= temp_5;
	AIN6 <= temp_6;	
  end 		    
// NOTE: data is from previous address sent! 
  if (SCLK && (bit_cnt <= 11)) begin 	// start capturing data at bit counter = 11
	case (ADC_address[13:11])
		0: 	   	temp_6[bit_cnt] <= MISO;   	// capture incoming data
		1:		temp_1[bit_cnt] <= MISO;
		2:		temp_2[bit_cnt] <= MISO;
		3:		temp_3[bit_cnt] <= MISO;
		4:		temp_4[bit_cnt] <= MISO;
		5:		temp_5[bit_cnt] <= MISO;
	//default: ADC_address = 0;
	endcase	
  end
end 
	
endmodule 

