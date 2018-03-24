//
//  Iambic CW Keyer for Hermes-Lite v1.22 , v2b3
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
// (C) Takashi Komatsumoto, JI1UDD 2016, 2018

`timescale 1 ns/100 ps

module Keyer (
	input				clk,					// IF_clk (48MHz)
	input				rst,					// IF_rst
	input				paddle_dot_n,		// Paddle Dot  (Active "L")
	input				paddle_dash_n,		// Paddle Dash (Active "L")
	output			TxEN_o,				// PTT, relay/PA Bias control (Active "H")
	output			KeyOn_o,				// CW lamp up/down control (Active "H")
	input  [ 9:0]	DotOnTime,			// Dot pulse width (ms)
	input  [ 9:0]	AdjDashTime,		// Dash Weight (ms)
	input  [ 9:0]	BrakeinTime,		// TxEN OFF after Key Off
	input  [ 9:0]	RELAY_DLY,			// TxEN ON before Key On
	output			sidetone,			// Piezo sounder ("L" when no sound)
	input				fastclk,				// AD9866clkX1 (73.528MHz)
	input				fastrst,				// AD9866clkX1 domain reset
	input				LRfall,				// LRCK gen.
	input  [11:0]	ToneFreq, 			// for Sidetone Audio frequency
	input  [ 7:0]  audiovolume,		// for Sidetone Audio volume
	output [15:0]	sidetone_codec,	// to Audio codec
	output         do1k					// 1ms timing
) ;

// -------------------
//  Declare parameter
// -------------------
localparam STATE_RX			= 3'd0 ;	// Iambic Keyer state
localparam STATE_DOT_PRE	= 3'd1 ;
localparam STATE_DOT_ON		= 3'd2 ;
localparam STATE_DOT_OFF	= 3'd3 ;
localparam STATE_DASH_PRE	= 3'd4 ;
localparam STATE_DASH_ON	= 3'd5 ;
localparam STATE_DASH_OFF	= 3'd6 ;
localparam STATE_TR_DLY		= 3'd7 ;

localparam REJECTCNT		= 4'd5	;	// 5ms, Chattering rejection (Max.14)
localparam ADJKEYTIM		= 3'd2	;	// 2ms, Adjust Key capture timing
//localparam RELAY_DLY	= 10'd10 ;	// 10ms, Key On after TxEN ON
//localparam DotOnTime = 10'd50 ;	// 50ms, Dot pulse width
//localparam BrakeinTime = 10'd300 ;// 300ms,TxEN OFF after Key Off
//localparam ToneFreq = 12'd600 ;

// -------------------
//  Declare Reg, Wire
// -------------------
//wire do1k ; 								// 1kHz(1ms) interval
reg [2:0] state ;							// Keyer state
reg [9:0] state_delay ;					// state shift delay counter
reg TxEN ;									// Tx/Rx relay control
reg KeyOn ;									// CW lamp up/down control
assign KeyOn_o = KeyOn ;
assign TxEN_o  = TxEN  ;

// ---------------------------
//  Reset
//	 rst(Pos) => rstb(Neg)
// ---------------------------
wire rstb = ~rst ;
wire fastrstb = ~fastrst ;

// ---------------------------------------
//  Paddle input detection
//           with chattering rejection
//    paddle_dot_n 	=> DotOn
//    paddle_dash_n	=> DashOn
// ---------------------------------------
reg [3:0] dotcnt ;
wire DotOn = (dotcnt == REJECTCNT) ; 
always @(posedge clk or negedge rstb)
  if (!rstb) begin
    dotcnt <= 4'b0 ; 
  end else if (do1k) begin
    if (state==STATE_DOT_ON)
	   dotcnt <= 4'b0 ;
	 else if (!((state==STATE_DOT_OFF)&&(state_delay >= ((DotOnTime>>2)+ADJKEYTIM)))) begin
      if (dotcnt < REJECTCNT)
        if (!paddle_dot_n)
          dotcnt <= dotcnt + 1'b1 ;
		  else
			 dotcnt <= 4'b0 ;
    end
	 if ((state==STATE_DASH_ON) && (state_delay >= DotOnTime)) begin
      dotcnt <= 4'b0 ;
    end
  end

reg [3:0] dashcnt ;
wire DashOn = (dashcnt == REJECTCNT) ;
always @(posedge clk or negedge rstb)
  if (!rstb) begin
    dashcnt <= 4'b0 ; 
  end else if (do1k) begin
    if (state==STATE_DASH_ON)
	   dashcnt <= 4'b0 ;
	 else if (!((state==STATE_DASH_OFF)&&(state_delay >= ((DotOnTime>>2)+ADJKEYTIM)))) begin
      if (dashcnt < REJECTCNT)
        if (!paddle_dash_n)
          dashcnt <= dashcnt + 1'b1 ;
		  else
		    dashcnt <= 4'b0 ;
    end
	 if ((state==STATE_DOT_ON) && (state_delay >= ((DotOnTime>>2)+ADJKEYTIM))) begin
      dashcnt <= 4'b0 ;
    end
  end

// ---------------------
//  Keyer state machine
// ---------------------
always @(posedge clk or negedge rstb)
  if (!rstb) begin
    state <= STATE_RX ;
    state_delay <= 10'd0 ;
  end else if (do1k) begin
    case(state)
      STATE_RX :
        begin
          if (DotOn) begin
            state <= STATE_DOT_PRE ;
            state_delay <= RELAY_DLY ;
          end else if (DashOn) begin
            state <= STATE_DASH_PRE ;
            state_delay <= RELAY_DLY ;
          end 			
        end

      STATE_DOT_PRE :
        begin
          if (state_delay==10'b0) begin
            state <= STATE_DOT_ON ;
            state_delay <= DotOnTime ;       
          end else
            state_delay <= state_delay - 1'b1 ;
        end

      STATE_DOT_ON :
        begin
          if (state_delay==10'b0) begin
            state <= STATE_DOT_OFF ;
            state_delay <= DotOnTime ;       
          end else
            state_delay <= state_delay - 1'b1 ;
        end

      STATE_DOT_OFF :
        begin
          if (state_delay==10'b0) begin
            if (DashOn) begin
              state <= STATE_DASH_ON ;
              state_delay <= ((DotOnTime * 2'd3) + AdjDashTime) ;
            end else if (DotOn) begin
	           state <= STATE_DOT_ON ;
              state_delay <= DotOnTime ;
   	      end else begin
              state <= STATE_TR_DLY ; 
              state_delay <= BrakeinTime ;
            end
          end else
            state_delay <= state_delay - 1'b1 ;
        end

      STATE_DASH_PRE :
        begin
          if (state_delay==10'b0) begin
            state <= STATE_DASH_ON ;
            state_delay <= ((DotOnTime * 2'd3) + AdjDashTime) ;       
          end else
            state_delay <= state_delay - 1'b1 ;
        end

      STATE_DASH_ON :
        begin
          if (state_delay==10'b0) begin
            state <= STATE_DASH_OFF ;
            state_delay <= DotOnTime ;       
          end else
            state_delay <= state_delay - 1'b1 ;
        end

      STATE_DASH_OFF :
        begin
          if (state_delay==10'b0) begin
            if (DotOn) begin
              state <= STATE_DOT_ON ;
              state_delay <= DotOnTime ;
            end else if (DashOn) begin
	           state <= STATE_DASH_ON ;
              state_delay <= ((DotOnTime * 2'd3) + AdjDashTime) ;
  	         end else begin
              state <= STATE_TR_DLY ;
              state_delay <= BrakeinTime ;
            end
          end else
            state_delay <= state_delay - 1'b1 ;
        end

      STATE_TR_DLY :
        begin
          if (state_delay==10'b0) begin
            state <= STATE_RX ;
          end else begin
            if (DotOn) begin
              state <= STATE_DOT_ON ;
              state_delay <=  DotOnTime ; //
            end else if (DashOn) begin
              state <= STATE_DASH_ON ;
              state_delay <=  ((DotOnTime * 2'd3) + AdjDashTime) ; //
            end else begin
              state_delay <= state_delay - 1'b1 ;
            end
          end
        end
    endcase
  end

// --------------
//  Keyer output
// --------------
always @(posedge clk or negedge rstb)
  if (!rstb) begin
    TxEN  <= 1'b0 ;
    KeyOn <= 1'b0 ;
  end else if (do1k) begin
    TxEN  <= ~(state==STATE_RX) ;
    KeyOn <= ((state==STATE_DOT_ON) | (state==STATE_DASH_ON)) ;
  end

// -------------------------------
//  6kHz(0.16mS) timing generator
// -------------------------------
reg  [13:0] div6k ;
wire [13:0] div6k_next = div6k + 1'b1 ;
//wire tim6k = (div6k_next == 13'h1F40) ;	// 0x1F40=48MHz/6kHz
wire tim6k = (div6k_next == 14'h3200) ;	// 0x3200=76.8MHz/6kHz

always @(posedge clk or negedge rstb)
  if (!rstb)
    div6k <= 14'h0 ;
  else if (tim6k)
    div6k <= 14'h0 ;
  else
    div6k <= div6k_next ;

// ----------------------------
//  1kHz(1mS) timing generator
// ----------------------------
reg  [2:0] div1k ;
wire [2:0] div1k_next = div1k + 1'b1 ;
wire tim1k  = (div1k_next == 3'h6) ;		// 6=6kHz/1kHz
assign do1k = tim1k & tim6k ;

always @(posedge clk or negedge rstb)
  if (!rstb)
    div1k <= 3'h0 ;
  else if (do1k)
    div1k <= 3'h0 ;
  else if (tim6k)
    div1k <= div1k_next ;

// --------------------------------------
//		Sin wave generator for Audio Codec
//      (clock : AudioCodec domain)
// --------------------------------------
//		Syncronize
//      KeyOn(clk) -> toneon(fastclk)

reg [1:0] synckeyon ;
always @(posedge fastclk or negedge fastrstb)
  if (!fastrstb)
    synckeyon <= 2'b0;
  else
    synckeyon <= { synckeyon[0], KeyOn } ;

//		Tone on/off control at zero-cross

wire zerocross ;
reg  toneon ;
always @(posedge fastclk or negedge fastrstb)
  if (!fastrstb)
    toneon <= 1'b0 ;
  else if(synckeyon[1])
    toneon <= 1'b1 ;
  else if (zerocross)
    toneon <= 1'b0 ;

//		Generate sin wave data

wire [17:0] tonefreq = (ToneFreq << 6) ;
wire [17:0] DeltaPhase ;
div18_9 frq2phase(
	.clock(clk),
	.denom(9'd375),				// 9bit
	.numer(tonefreq),				// 18bit
	.quotient(DeltaPhase),		// 18bit
	.remain());						// 9bit

reg [12:0] sinptr ;
always @(posedge fastclk or negedge fastrstb )
  if (!fastrstb)
    sinptr <= 13'b0 ;
  else if (!toneon)
    sinptr <= 13'b0 ;
  else if (LRfall)
    sinptr <= sinptr + DeltaPhase[9:0] ;

// Lookup sine table

wire [7:0] sintbl ;
sin8k8r sintbl8k(
  .aclr(fastrst),
  .address(sinptr),			// 13bit address
  .clock(fastclk),			// clock
  .q(sintbl));					// 8bit output

// detect zero coross

reg lastsign ;
assign zerocross = ( lastsign != sintbl[7] ) ;
always @(posedge fastclk or negedge fastrstb )
  if (!fastrstb)
    lastsign <= 1'b0 ;
  else
    lastsign <= sintbl[7] ;

// Volume control

wire [16:0] sinxmag ;
mult8_9	audiovolumectrl (	// signed mult
  .aclr(fastrst||~toneon),	// async reset
  .clock(fastclk),			// clock
  .dataa(sintbl),	   		// signed 8bit input
  .datab({1'b0,audiovolume}),		//  signed 9bit input
  .result(sinxmag)			// 17bit output
);

assign sidetone_codec = sinxmag[16:1] ;

// ------------------------------------------
//		Squar wave generator for piezo sounder
// ------------------------------------------

reg sqwave ;
always @(posedge fastclk or negedge fastrstb)
  if (!fastrstb)
    sqwave <= 1'b0 ;
  else if (~toneon)
    sqwave <= 1'b0 ;
  else if (zerocross) 
    sqwave <= ~lastsign ;

assign sidetone = sqwave ;

endmodule