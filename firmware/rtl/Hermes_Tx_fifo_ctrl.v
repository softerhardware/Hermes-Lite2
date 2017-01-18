//////////////////////////////////////////////////////////////
//
//      Read A/D converter, send sync and C&C to Tx FIFO
//
//////////////////////////////////////////////////////////////


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

// (C) Phil Harman VK6APH, Kirk Weedman KD7IRS  2006, 2007, 2008, 2009, 2010, 2011, 2012 




/*
        The following code sends the sync bytes, control bytes and A/D samples.

        The code is structured around watching transitions of LRCLK which will
        be as fast or faster than CLRCLK (48kHz). 
        
        At each state we determine what data needs to to be latched into a TX_FIFO_SZ word Tx FIFO.

        Each frame is 512 bytes long. Initially 8 bytes of sync & control bytes are sent,
        followed by 512-8 bytes of AK5394A and TLV320 data.  The initial 8 bytes are
        comprised of 3 sync bytes and 5 control bytes. The 504 bytes are comprised of
        NUM_LOOPS *(3 AK539A left bytes, 3 AK5394A right bytes and 2 TLV320 microphone/line
        bytes.

        Each frame is 512 bytes long = 8 initial bytes + NUM_LOOPS*8 - where NUM_LOOPS = 63

        If PTT_in, dot or dash inputs are acitve they are sent in C&C
        
        22 Nov 2009 	- Renamed to Hermes_Tx_fifo_ctrl 
							- Added AIN1,2,3,4,6 increased MAX_ADDR to 3 
		  10 Dec 2009  - Added IO3,2,1. 
		  13 Jun 2011  - Modified for Ethernet Hermes
		  14 Apr 2012  - Added IO8
*/

`timescale 1 ns/100 ps

module Hermes_Tx_fifo_ctrl(IF_reset, IF_clk, Tx_fifo_wdata, Tx_fifo_wreq, Tx_fifo_full, Tx_fifo_used,
                    Tx_fifo_clr, Tx_IQ_mic_rdy,
                    Tx_IQ_mic_data, IF_chan, IF_last_chan, clean_dash, clean_dot, clean_PTT_in, ADC_OVERLOAD,
                    Penny_serialno, Merc_serialno, Hermes_serialno, Penny_ALC, AIN1, AIN2, AIN3, 
                    AIN4, AIN6, IO4, IO5, IO6, IO8, VNA_start, VNA);
                    
parameter RX_FIFO_SZ = 2048;
parameter TX_FIFO_SZ = 1024;
parameter IF_TPD = 1;

localparam RFSZ = clogb2(RX_FIFO_SZ-1);  // number of bits needed to hold 0 - (RX_FIFO_SZ-1)
localparam TFSZ = clogb2(TX_FIFO_SZ-1);  // number of bits needed to hold 0 - (TX_FIFO_SZ-1)

input  wire            IF_reset;
input  wire            IF_clk;
output reg      [15:0] Tx_fifo_wdata;    // AK5394A A/D uses this to send its data to Tx FIFO
output reg             Tx_fifo_wreq;     // set when we want to send data to the Tx FIFO
input  wire            Tx_fifo_full;
input  wire [TFSZ-1:0] Tx_fifo_used;
output reg             Tx_fifo_clr;

input  wire            Tx_IQ_mic_rdy;
input  wire     [63:0] Tx_IQ_mic_data;

output reg       [4:0] IF_chan; // which IF_mic_IQ_Data is needed
input  wire      [4:0] IF_last_chan;

input  wire            clean_dash;       // debounced dash
input  wire            clean_dot;        // debounced dot
input  wire            clean_PTT_in;     // debounced button

input  wire            ADC_OVERLOAD;

input  wire      [7:0] Penny_serialno;
input  wire      [7:0] Merc_serialno;
input  wire      [7:0] Hermes_serialno;

input  wire     [11:0] Penny_ALC;		// Analog inputs
input  wire     [11:0] AIN1;
input  wire     [11:0] AIN2;
input  wire     [11:0] AIN3;
input  wire     [11:0] AIN4;
input  wire     [11:0] AIN6;

input  wire            IO4;				// user digital inputs
input  wire            IO5;
input  wire            IO6;
input  wire 			  IO8;

input  wire 				VNA_start;
input  wire             VNA; 				// set when in VNA mode

reg VNA_start_reg = 0;


// internal signals
reg       [5:0] loop_counter;     // counts number of times round loop

reg       [3:0] AD_state;
reg       [3:0] AD_state_next;
reg       [5:0] AD_timer;

localparam  MAX_ADDR = 3; 
reg       [4:0] tx_addr; // round robin address from 0 to MAX_ADDR
reg       [7:0] C1_DATA, C2_DATA, C3_DATA, C4_DATA;

localparam  AD_IDLE               = 0,
            AD_SEND_SYNC1         = 1,
            AD_SEND_SYNC2         = 2,
            AD_SEND_CTL1_2        = 3,
            AD_SEND_CTL3_4        = 4,
            AD_SEND_MJ_RDY        = 5,
            AD_SEND_MJ1           = 6,
            AD_SEND_MJ2           = 7,
            AD_SEND_MJ3           = 8,
            AD_SEND_PJ            = 9,
            AD_WAIT               = 10,
            AD_LOOP_CHK           = 11,
            AD_PAD_CHK            = 12,
            AD_ERR                = 13;

reg [6:0] loop_cnt, num_loops;
reg [6:0] pad_cnt, pad_loops;

always @*
begin
  case (IF_last_chan)
    0: num_loops = 62; //(512 - 8)bytes/8 - 1 = 62
    1: num_loops = 35; //(512 - 8)bytes/14 - 1 = 35
    2: num_loops = 24; //(512 - 8)bytes/20 - 1 = 24.2
    3: num_loops = 18; //(512 - 8)bytes/26 - 1 = 18.38
    4: num_loops = 14; //(512 - 8)bytes/32 - 1 = 14.75
    5: num_loops = 12;
    6: num_loops = 10;
    7: num_loops = 9;
    8: num_loops = 8;
    9: num_loops = 7;
   10: num_loops = 6;
   11: num_loops = 5;
   12: num_loops = 5;
   13: num_loops = 4;
   14: num_loops = 4;
   15: num_loops = 4;
   16: num_loops = 3;
   17: num_loops = 3;
   18: num_loops = 3;
   19: num_loops = 3;
   20: num_loops = 2;
   21: num_loops = 2;
   22: num_loops = 2;
   23: num_loops = 2;
   24: num_loops = 2;
   25: num_loops = 2;
   26: num_loops = 2;
   27: num_loops = 1;
   28: num_loops = 1;
   29: num_loops = 1;
   30: num_loops = 1;
   31: num_loops = 1;
   default: num_loops = 1;
  endcase
end

always @*
begin
  case (IF_last_chan)
    0: pad_loops = 0;
    1: pad_loops = 0;
    2: pad_loops = 2;
    3: pad_loops = 5;
	  4: pad_loops = 12;
    5: pad_loops = 5;
    6: pad_loops = 10;
    7: pad_loops = 2;
    8: pad_loops = 0;
    9: pad_loops = 4;
   10: pad_loops = 14;
   11: pad_loops = 30;
   12: pad_loops = 12;
   13: pad_loops = 37;
   14: pad_loops = 22;
   15: pad_loops = 7;
   16: pad_loops = 44;
   17: pad_loops = 32;
   18: pad_loops = 20;
   19: pad_loops = 8;
   20: pad_loops = 60;
   21: pad_loops = 51;
   22: pad_loops = 42;
   23: pad_loops = 33;
   24: pad_loops = 24;
   25: pad_loops = 15;
   26: pad_loops = 6;
   27: pad_loops = 82;
   28: pad_loops = 76;
   29: pad_loops = 70;
   30: pad_loops = 64;
   31: pad_loops = 58;
   default: pad_loops = 0;
  endcase
end

wire Tx_IQ_mic_ack = (AD_state == AD_WAIT);

always @ (posedge IF_clk)
begin
  if ((AD_state == AD_IDLE) || (AD_state == AD_SEND_SYNC1))
    loop_cnt  <= #IF_TPD 1'b0;
  else if (AD_state == AD_LOOP_CHK)
    loop_cnt  <= #IF_TPD loop_cnt + 1'b1; // at end of loop so increment loop counter

  if ((AD_state == AD_IDLE) || (AD_state == AD_SEND_SYNC1))
    pad_cnt  <= #IF_TPD 1'b0;
  else if (AD_state == AD_PAD_CHK)
    pad_cnt  <= #IF_TPD pad_cnt + 1'b1; // at end of loop so increment loop counter

  if (IF_reset)
    AD_state <= #IF_TPD AD_IDLE;
  else
    AD_state <= #IF_TPD AD_state_next;

  if (IF_reset)
    tx_addr <= #IF_TPD 1'b0;
  else if (AD_state == AD_SEND_CTL3_4) // toggle it for each frame
  begin
    if (tx_addr != MAX_ADDR)
      tx_addr <= #IF_TPD tx_addr + 1'b1;
    else
      tx_addr <= #IF_TPD 1'b0;
  end

  if (IF_reset)
    AD_timer <= #IF_TPD 0;
  else if (AD_state == AD_ERR)
    AD_timer <= #IF_TPD 0;
  else if (!AD_timer[5])
    AD_timer <= #IF_TPD AD_timer + 1'b1;

  Tx_fifo_clr <= #IF_TPD (AD_state == AD_ERR);

  if (IF_reset)
    IF_chan <= #IF_TPD 1'b0;
  else if (AD_state == AD_SEND_MJ_RDY)
    IF_chan <= #IF_TPD 1'b0;
  else if (AD_state == AD_SEND_MJ3)
    IF_chan <= #IF_TPD IF_chan + 1'b1;
	 
  if (VNA_start) VNA_start_reg <= 1'b1;
  else if (AD_state == AD_LOOP_CHK) VNA_start_reg <= 1'b0;  // in VNA mode indicate new frequency
	 
end

always @*
begin 
  case (tx_addr)
    0:
    begin
      C1_DATA = {4'b0,IO8,IO6,IO5,IO4,ADC_OVERLOAD};
      C2_DATA = Merc_serialno;
      C3_DATA = Penny_serialno;
      C4_DATA = Hermes_serialno;
    end

    1:
    begin
      C1_DATA = {4'b0,Penny_ALC[11:8]};
      C2_DATA = Penny_ALC[7:0];
      C3_DATA = {4'b0, AIN1[11:8]};
      C4_DATA = AIN1[7:0];
    end
    
    2:
    begin
      C1_DATA = {4'b0, AIN2[11:8]};
      C2_DATA = AIN2[7:0];
      C3_DATA = {4'b0, AIN3[11:8]};
      C4_DATA = AIN3[7:0];
    end
    
    3:
    begin
      C1_DATA = {4'b0, AIN4[11:8]};
      C2_DATA = AIN4[7:0];
      C3_DATA = {4'b0, AIN6[11:8]};
      C4_DATA = AIN6[7:0];
    end
   
    default:
    begin
      C1_DATA = 8'b0;
      C2_DATA = 8'b0;
      C3_DATA = 8'b0; 
      C4_DATA = 8'b0; 
    end   
  endcase
end

always @*
begin 
  case (AD_state)
    AD_IDLE:
    begin
      Tx_fifo_wdata   = {16{1'bx}};
      Tx_fifo_wreq    = 1'b0;
      if (IF_reset || !AD_timer[5])
        AD_state_next = AD_IDLE;
      else // Tx_fifo can't immediately take data after reset
        AD_state_next = AD_SEND_SYNC1;
    end

    AD_SEND_SYNC1:
    begin
      Tx_fifo_wdata   = 16'h7F7F;
      Tx_fifo_wreq  = 1'b1;      // strobe sync (7F7F) into Tx FIFO
      if (Tx_fifo_full)          // Oops! buffer overflow!  Hate it when that happens...
        AD_state_next = AD_ERR;  // error handling will need to clear the fifo
      else
        AD_state_next = AD_SEND_SYNC2;
    end

    AD_SEND_SYNC2:
    begin  
      Tx_fifo_wdata   = {8'h7F, tx_addr, clean_dot, clean_dash, clean_PTT_in};
      Tx_fifo_wreq    = 1'b1;
      AD_state_next   = AD_SEND_CTL1_2;
    end

    AD_SEND_CTL1_2:
    begin
      Tx_fifo_wdata   = {C1_DATA, C2_DATA};
      Tx_fifo_wreq    = 1'b1;
      AD_state_next   = AD_SEND_CTL3_4;
    end

    AD_SEND_CTL3_4:
    begin 
      Tx_fifo_wdata   = {C3_DATA, C4_DATA};
      Tx_fifo_wreq    = 1'b1;
      AD_state_next   = AD_SEND_MJ_RDY;
    end


    AD_SEND_MJ_RDY:
    begin
      Tx_fifo_wdata   = {16{1'bx}};
      Tx_fifo_wreq    = 1'b0;
      if (!Tx_IQ_mic_rdy)
        AD_state_next = AD_SEND_MJ_RDY;
      else
        AD_state_next = AD_SEND_MJ1;
    end
  
    AD_SEND_MJ1:
    begin
      Tx_fifo_wdata   = Tx_IQ_mic_data[63:48];
      Tx_fifo_wreq    = 1'b1;
      AD_state_next   = AD_SEND_MJ2;
    end

    AD_SEND_MJ2:
    begin
      Tx_fifo_wdata   = Tx_IQ_mic_data[47:32];
      Tx_fifo_wreq    = 1'b1;
      AD_state_next   = AD_SEND_MJ3;
    end

    AD_SEND_MJ3:
    begin 
      Tx_fifo_wdata   = Tx_IQ_mic_data[31:16];
      Tx_fifo_wreq    = 1'b1;
      if (IF_chan != IF_last_chan)
        AD_state_next   = AD_SEND_MJ1;
      else
        AD_state_next   = AD_SEND_PJ;
    end

    AD_SEND_PJ:
    begin 
      Tx_fifo_wdata   = VNA ? {Tx_IQ_mic_data[15:1], VNA_start_reg} : Tx_IQ_mic_data[15:0]; // In VNA mode LSB indicates new frequency
      Tx_fifo_wreq    = 1'b1;
      AD_state_next   = AD_WAIT;
    end

    AD_WAIT:
    begin 
      Tx_fifo_wdata   = {16{1'bx}};
      Tx_fifo_wreq    = 1'b0;
      if (Tx_IQ_mic_rdy)
        AD_state_next = AD_WAIT; // wait here till Tx_IQ_mic_rdy goes back low
      else
        AD_state_next = AD_LOOP_CHK;
    end

    AD_LOOP_CHK:
    begin 
      Tx_fifo_wdata   = {16{1'bx}};
      Tx_fifo_wreq    = 1'b0;
      if (loop_cnt != num_loops)
        AD_state_next = AD_SEND_MJ_RDY;
      else
        AD_state_next = AD_PAD_CHK;
    end

    AD_PAD_CHK:
    begin 
      Tx_fifo_wdata   = 16'b0;
      Tx_fifo_wreq    = (pad_cnt != pad_loops);
      if (pad_cnt != pad_loops)
        AD_state_next = AD_PAD_CHK;
      else
        AD_state_next = AD_SEND_SYNC1;
    end

    AD_ERR:
    begin
      Tx_fifo_wdata   = {16{1'bx}};
      Tx_fifo_wreq    = 1'b0;
      AD_state_next   = AD_IDLE; // wait for TX FIFO to reset
    end

    default:
    begin
      Tx_fifo_wdata   = {16{1'bx}};
      Tx_fifo_wreq    = 1'b0;
      AD_state_next   = AD_IDLE;
    end
  endcase
end

function integer clogb2;
input [31:0] depth;
begin
  for(clogb2=0; depth>0; clogb2=clogb2+1)
  depth = depth >> 1;
end
endfunction

endmodule
