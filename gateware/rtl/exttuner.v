//
//  External ATU Control for Hermes-Lite v2
//    ATU Type: ICOM AH-4
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
// (C) Takashi Komatsumoto, JI1UDD 2018

`timescale 1 ns/100 ps

module exttuner (
  input  clk,
  input  auto_tune,
  input  ATU_Status,
  output ATU_Start,
  input  mox_in,
  output mox_out
);

// -------------------
//  Declare parameter
// -------------------
localparam PS_init = 76800000/1000 -1 ; // 1ms
localparam TuneDelay   =  100 -1;       // 100ms
localparam TuneWidth   =  500 -1;       // 500ms
localparam LDetectLimit = 1000 -1;      // 1s
localparam HDetectLimit = 9000 -1;      // 9s

// -----------------
//  PreScaler (1ms)
// -----------------
reg [16:0] ps = 17'b0;
wire ps1ms = (ps==17'b0);
always @(posedge clk)
  if (ps1ms)
    ps <= PS_init;
  else
    ps <= ps - 1'b1;

// ------------------------
//   ATU Control Sequencer
// ------------------------
reg [15:0] timer = 16'b0;
reg  [3:0] state = 4'd0;
reg        tune  = 1'b0;
reg        mox_inhibit = 1'b0;

always @(posedge clk) begin
  if (ps1ms) begin
    if (!auto_tune) begin
      state <= 4'd0;
      tune  <= 1'b0;
      mox_inhibit <= 1'b0;
    end else begin

      case (state)
        4'd0: begin
                state <= 4'd1;
                timer <= TuneDelay;
              end

        4'd1: if (timer==16'b0) begin
                state <= 4'd2;
                timer <= TuneWidth;
                tune  <= 1'b1;                      // send ATU Tune start pulse
              end else
                timer <= timer - 1'b1;

        4'd2: if (timer==16'b0) begin
                state <= 4'd3;
                timer <= LDetectLimit;
                tune  <= 1'b0;
              end else
                timer <= timer - 1'b1;

        4'd3: if (timer==16'b0) begin
                state <= 4'd5;                      // TimeOut, ATU no response
                mox_inhibit <= 1'b1;                // stop transmittion
              end else if (ATU_Status==1'b1) begin
                state <= 4'd4;
                timer <= HDetectLimit;
              end else
                timer <= timer -1'b1;

        4'd4: if ((timer==16'b0)||(ATU_Status==1'b0)) begin
                state <= 4'd5;                      // TimeOut or ATU finished tuning
                mox_inhibit <= 1'b1;                // stop transmittion
              end else
                timer <= timer -1'b1;

        4'd5: begin
              end

        default : state <= 4'd0;
      endcase
    end
  end
end

// ---------
//   Output
// ---------
assign ATU_Start = tune;
assign mox_out = mox_in & ~mox_inhibit;

endmodule