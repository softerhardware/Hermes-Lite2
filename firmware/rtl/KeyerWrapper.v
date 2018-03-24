//
//  Iambic CW Keyer Wrapper for Hermes-Lite v1.22 
//    ( Tested on BeMicro CVA9 )
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
//
// (C) Takashi Komatsumoto, JI1UDD 2016

`timescale 1 ns/100 ps

module KeyerWrapper (
	input				IF_clk,					// IF_clk (48MHz)
	input				IF_rst,					// IF_rst
	input				AD9866clkX1,			// AD9866clkX1 (73.528MHz)
	input				C122_rst,				// AD9866clkX1 domain reset	
	input				C122_LRfall,			// LRCK gen.
	input				paddle_dot_n,			// Paddle Dot  (Active "L")
	input				paddle_dash_n,			// Paddle Dash (Active "L")
   input   [1:0]	IF_Keyer_Mode,			// Ctrl, 00:straight, 01:Mode A, 10:Mode B
	input				IF_CW_keys_reversed,	// Ctrl, 0:disable, 1:enable
   input   [5:0]	IF_Keyer_speed,		// Ctrl, 1 - 60 WPM 
   input   [6:0]	IF_Keyer_Weight,		// Ctrl, 0 - 100, 
   input   [9:0]	IF_CW_Hang_Time,		// Ctrl, 0 - 1023 ms
   input  [11:0]	IF_CW_Tone_Freq,		// Ctrl, 200 - 2250Hz
   input   [7:0]	IF_CW_Sidetone_Vol,	// Ctrl, 0 - 127
   input   [7:0]	IF_CW_PTT_delay,		// Ctrl, 0 - 255  ms
	input  [31:0]	C122_LR_data,			// Audio hook in
	output [31:0]	i2s_tx_data,			// Audio hook out
	input				FPGA_PTT,				// PTT hook in
   output			exp_ptt_n,				// PTT hook out
	output			clean_cwkey,			// CW lamp up/down control (Active "H")
	output			sidetone					// Piezo sounder ("L" when no sound)
) ;

// Paddle input
wire paddle_dot_n_x  = (IF_CW_keys_reversed==1'b1)? paddle_dash_n : paddle_dot_n ;
wire paddle_dash_n_x = (IF_CW_keys_reversed==1'b1)? paddle_dot_n : paddle_dash_n ;
wire paddle_dot_n_b  = (IF_Keyer_Mode==2'd0) | paddle_dot_n_x  ;
wire paddle_dash_n_b = (IF_Keyer_Mode==2'd0) | paddle_dash_n_x ;

// Debounce for Straight Key (5ms)
wire do1k ;
wire rstb = ~IF_rst ;
reg [3:0] chatcnt ;
always @(posedge IF_clk or negedge rstb)
  if (!rstb) begin
    chatcnt <= 4'b0 ; 
  end else if (do1k) begin
    if (paddle_dot_n_x)
      chatcnt <= 4'b0 ;
    else if (chatcnt < 4'd5)	
      chatcnt <= chatcnt + 1'b1 ;
  end
wire debounced_cwkey_i = (chatcnt == 4'd5) ; 

// Convert WPM -> Dot On time(ms)
wire [10:0] DotOnTime ;
div11_8	wpm2ms (.clock(IF_clk), .denom(IF_Keyer_speed),
         .numer(11'd1200), .quotient(DotOnTime), .remain ( ) );

// Keyer output
wire KeyOn_o ;
wire TxEN_o  ;
assign clean_cwkey =   (IF_Keyer_Mode==2'd0)? debounced_cwkey_i :
                       ((IF_Keyer_Mode==2'd1)? KeyOn_o : 1'b0 ) ;
assign exp_ptt_n =     ((IF_Keyer_Mode==2'd1)& TxEN_o) | FPGA_PTT ;
wire   [15:0] sidetone_codec ;
//assign i2s_tx_data =	{(C122_LR_data[31:16] + sidetone_codec),
//                      (C122_LR_data[15:0]  + sidetone_codec)} ;
assign i2s_tx_data =	  TxEN_o && (IF_CW_Sidetone_Vol != 8'b0) ?
                        {sidetone_codec, sidetone_codec} :
                        C122_LR_data[31:0] ;

Keyer keyer(
	.clk(IF_clk),								// IF_clk (48MHz)
	.rst(IF_rst),								// IF_rst
	.paddle_dot_n(paddle_dot_n_b),		// Dot  Key , active "L"
	.paddle_dash_n(paddle_dash_n_b),		// Dash Key , active "L"
	.TxEN_o(TxEN_o),							// Tx/Rx relay control
	.KeyOn_o(KeyOn_o),						// Lamp up/down carrier
	.DotOnTime(DotOnTime[9:0]),			// Dot pulse width (ms)
	.AdjDashTime(IF_Keyer_Weight-7'd50),// Dash Weight (ms)
	.BrakeinTime(IF_CW_Hang_Time),		// TxEN OFF after Key Off
	.RELAY_DLY({2'b0,IF_CW_PTT_delay}),	// TxEN ON before Key On
	.sidetone(sidetone),						// Piezo sounder ("L" when sound off)
	.fastclk(AD9866clkX1),					// LRCK clock generator
	.fastrst(C122_rst),						// LRCK clock generator
	.LRfall(C122_LRfall),					// LRCK clock generator
	.ToneFreq(IF_CW_Tone_Freq), 			// for Sidetone Audio frequency
	.audiovolume(IF_CW_Sidetone_Vol),	// Audio volume
	.sidetone_codec(sidetone_codec),		// Audio codec
	.do1k(do1k)									// 1ms timing
) ;
endmodule 
