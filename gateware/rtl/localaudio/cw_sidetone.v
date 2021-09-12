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
//  (C) Takashi Komatsumoto, JI1UDD 2020, 2021

`timescale 1 ns/100 ps

module cw_sidetone (
  input                clk,          // 76.8MHz
  input                tone_enb,     // sidetone enable
  input         [11:0] tonefreq,     // sidetone audio frequency ; 200 to 2250
  input         [ 6:0] profile,      // sidetone profile (7bit) ; 0 to 4dh
  input         [ 7:0] audiovolume,  // sidetone audio volume ; 0 to 127
  output signed [15:0] sidetone      // to audio codec
) ;

  parameter TONE1HZ = 17'd75000;     // 76.8M/1024

  reg   [9:0] period;
  reg  [20:0] acc;
  reg  [11:0] freq;
  reg   [3:0] cnt = 4'b0;
  wire [12:0] sub = {1'b0,acc[20:9]} - freq;
  always @(posedge clk)
    if ( cnt==4'd10 ) begin
      cnt <= 4'd0;
      acc <= {4'b0,TONE1HZ};
      freq <= tonefreq;
      period <= acc[9:0];
    end else begin
      cnt <= cnt + 1'b1;
      acc <= sub[12]? {acc[19:0], 1'b0} : {sub[10:0], acc[8:0], 1'b1}; 
    end

  reg [9:0] scaler;
  wire update = ( scaler == (period - 1'b1) );
  always @ (posedge clk)
    if (update)
      scaler <= 10'b0;
    else
      scaler <= scaler + 1'b1;

  reg [9:0] tblptr;
  always @(posedge clk)
    if (!tone_enb)
      tblptr <= 10'b0;
    else if (update)
      tblptr <= tblptr + 1'b1;

  wire signed [8:0] sintbl;
  sin1k9r sintbl1k(
    .clock(clk),
    .address(tblptr),                // 10bit address
    .q(sintbl)                       // signed 9bit data (-256 to 255)
  );

  wire signed [15:0] sin_profile;
  mult_s9_s8_s16 mult_p (            // signed mult
    .clock(clk),
    .dataa(sintbl),                  // signed  9bit input
    .datab({1'b0,profile}),          // signed  8bit input
    .result(sin_profile)             // signed 16bit output
  );

  mult_s16_s8_s16 mult16_v (         // signed mult
    .clock(clk),
    .dataa(sin_profile),             // signed 16bit input
    .datab(audiovolume),             // signed  8bit input
    .result(sidetone)                // signed 16bit output
  );

endmodule
