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
// (C) Takashi Komatsumoto, JI1UDD 2018, 2019
//   Jun 8,2019 : revised for HL2 refactored firmware
//   2020: rewritten by kf7o, matches protocol as decsribed in
//   https://hamoperator.com/HF/AH-4_Design_and_Operation.pdf

`timescale 1 ns/100 ps

module exttuner (
  input               clk           ,
  input        [ 5:0] cmd_addr      ,
  input        [31:0] cmd_data      ,
  input               cmd_rqst      ,
  input               millisec_pulse,
  input               int_ptt       ,
  input               key           ,
  output logic        start         ,
  output logic        txinhibit
);


localparam
  IDLE    = 3'b000,
  DELAY   = 3'b001,
  TRY     = 3'b011,
  HANG    = 3'b111,
  TX      = 3'b110,
  SUCCESS = 3'b100,
  PASS    = 3'b101,
  FAIL    = 3'b010;

// Picked to have similar binary patterns
localparam HANG_TIME    = 12'd311 ;
localparam RESET_TIME   = 12'd71  ;
localparam DELAY_TIME   = 12'd71  ;
localparam SUCCESS_TIME = 12'd71  ;
localparam TRY_TIME     = 12'd511 ;
localparam TX_TIME      = 12'd4095;

logic [11:0] timer_next, timer = DELAY_TIME;
logic [ 2:0] state_next, state = IDLE;

logic enable = 1'b0;
logic reset  = 1'b0;

always @(posedge clk) begin
  if (cmd_rqst & (cmd_addr == 6'h09)) begin
    // enable tune if
    // PA on and not disable TR in low power mode
    // PA off and disable TR in low power mode
    enable <= cmd_data[20] & cmd_data[19];
    reset  <= cmd_data[18];
  end
end


always @(posedge clk) begin
  if (millisec_pulse) begin
    state <= state_next;
    timer <= timer_next;
  end
end

always @* begin

  state_next = state;
  timer_next = timer - 12'd1;

  start     = 1'b1;
  txinhibit = 1'b0;

  case (state)
    IDLE: begin
      timer_next = DELAY_TIME;
      if (enable) state_next = DELAY;
    end

    DELAY: begin
      txinhibit = 1'b1;
      if (timer == 12'd0) begin
        state_next = TRY;
        if (reset) timer_next = RESET_TIME;
        else timer_next = TRY_TIME;
      end
    end

    TRY: begin
      txinhibit = 1'b1;
      start = 1'b0;
      if (timer == 12'd0) begin
        timer_next = SUCCESS_TIME;
        // Always go to success in case no ATU connected so tune still works
        state_next = SUCCESS;
      end else if (~key) begin
        state_next = HANG;
        timer_next = HANG_TIME;
      end
    end

    HANG: begin
      txinhibit = 1'b1;
      start = 1'b0;
      if (timer == 12'd0) begin
        state_next = TX;
        timer_next = TX_TIME;
      end
    end

    TX: begin
      if (timer == 12'd0) begin
        state_next = FAIL;
      end else if (key) begin
        state_next = SUCCESS;
        timer_next = SUCCESS_TIME;
      end
    end

    SUCCESS: begin
      txinhibit = 1'b1;
      if (timer == 12'd0) begin
        if (key) state_next = PASS;
        else state_next = FAIL;
      end
    end

    PASS: begin
      if (~enable) state_next = IDLE;
    end

    FAIL: begin
      txinhibit = 1'b1;
      if (~enable) state_next = IDLE;
    end
  endcase
end

endmodule