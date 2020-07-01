//
//  CW sidetone
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
// (C) Takashi Komatsumoto, JI1UDD 2020

`timescale 1 ns/100 ps

module cw_sidetone (
  input          clk,               // 76.3MHz
  input          rst,               //

  input          sidetone_req,      // sideton request
  input          next_data_req,     // next sideton data request

  input  [11:0]  ToneFreq,          // for sidetone audio frequency
  input  [ 7:0]  audiovolume,       // for sidetone audio volume

  output [15:0]  sidetone           // to audio codec
) ;

//localparam ToneFreq = 12'd600 ;   // 600Hz
//localparam audiovolume = 8'd255 ; // Max

  wire rstb = ~rst ;

  // Tone on/off control at zero-cross

  wire zerocross ;
  reg  toneon ;
  always @(posedge clk or negedge rstb)
    if (!rstb)
      toneon <= 1'b0 ;
    else if(sidetone_req)
      toneon <= 1'b1 ;
    else if (zerocross)
      toneon <= 1'b0 ;

  // Generate sin wave data

  wire [17:0] tonefreq = (ToneFreq << 6) ;
  wire [17:0] DeltaPhase ;
  div18_9 frq2phase(
    .clock(clk),
    .denom(9'd375),           //  9bit
    .numer(tonefreq),         // 18bit
    .quotient(DeltaPhase),    // 18bit
    .remain());               //  9bit

  reg [12:0] sinptr ;
  always @(posedge clk or negedge rstb )
    if (!rstb)
      sinptr <= 13'b0 ;
    else if (!toneon)
      sinptr <= 13'b0 ;
    else if (next_data_req)
      sinptr <= sinptr + DeltaPhase[9:0] ;

  // Lookup sine table

  wire [7:0] sintbl ;
  sin8k8r sintbl8k(
    .aclr(rst),
    .address(sinptr),        // 13bit address
    .clock(clk),             // clock
    .q(sintbl));             // 8bit output

  // detect zero coross

  reg lastsign ;
  assign zerocross = ( lastsign != sintbl[7] ) ;
  always @(posedge clk or negedge rstb )
    if (!rstb)
      lastsign <= 1'b0 ;
    else
      lastsign <= sintbl[7] ;

  // Volume control

  wire [16:0] sinxmag ;
  mult8_9 audiovolumectrl (   // signed mult
    .aclr(rst||~toneon),        // async reset
    .clock(clk),                // clock
    .dataa(sintbl),             // signed 8bit input
    .datab({1'b0,audiovolume}), // signed 9bit input
    .result(sinxmag)            // 17bit output
  );

assign sidetone = sinxmag[16]? sinxmag[16:1]+sinxmag[0] : sinxmag[16:1] ;

endmodule