//
//  Hermes Lite
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

// (C) Steve Haynal KF7O 2014-2018

module ad9866ctrl (
  clk,
  rst,

  rffe_ad9866_sdio,
  rffe_ad9866_sclk,
  rffe_ad9866_sen_n,

  // Command slave interface
  cmd_addr,
  cmd_data,
  cmd_rqst,
  cmd_ack
);

input             clk;
input             rst;

output            rffe_ad9866_sdio;
output            rffe_ad9866_sclk;
output            rffe_ad9866_sen_n;

// Command slave interface
input  [5:0]      cmd_addr;
input  [31:0]     cmd_data;
input             cmd_rqst;
output logic      cmd_ack = 1'b0;

parameter         FAST_LNA = 0;
parameter         BYPASS_VERSA = 0;

`include "cmd_bus.vh"


// SPI
logic   [15:0]    datain;
logic             start;
logic   [3:0]     dut2_bitcount;
logic             dut2_state;
logic   [15:0]    dut2_data;
logic   [5:0]     dut1_pc;
logic             sdo;

logic             cmd_ack_next;
logic             istart;

logic   [8:0]     initarrayv;

// This is a read-only initialization table of compile-time constants. It is
// implemented as a plain combinational lookup (case mux) rather than as a
// memory array read by a variable index: an inferred ROM here would need a
// MIF/initialization file to satisfy the memory-inference checks and its
// write ports would be reported as undriven (Warning 10030). Only entries
// 0..19 are ever accessed (reads are gated by dut1_pc[5:1] <= 6'h13); the
// remaining entries are inert placeholders returning a no-op write.
function [8:0] init_entry;
  input [4:0] a;
  begin
    case (a)
      5'd0:  init_entry = {1'b0,8'h80}; // Address 0x00, enable 4 wire SPI
      5'd1:  init_entry = {1'b0,8'h00}; // Address 0x01,
      5'd2:  init_entry = {1'b0,8'h00}; // Address 0x02,
      5'd3:  init_entry = {1'b0,8'h00}; // Address 0x03,
      // Address 0x04:
      5'd4:  init_entry = (BYPASS_VERSA == 1) ? {1'b1,8'h36} : {1'b0,8'h00};
      5'd5:  init_entry = {1'b0,8'h00}; // Address 0x05,
      5'd6:  init_entry = {1'b1,8'h54}; // Address 0x06, Disable clkout2
      5'd7:  init_entry = {1'b1,8'h30}; // Address 0x07, Initiate DC offset calibration and RX filter on, 21 to 20 to disable RX filter
      5'd8:  init_entry = {1'b0,8'h4b}; // Address 0x08, RX filter f-3db at ~34 MHz after scaling
      5'd9:  init_entry = {1'b0,8'h00}; // Address 0x09,
      5'd10: init_entry = {1'b0,8'h00}; // Address 0x0a,
      // Address 0x0b, Enable RxPGA update via Tx[5:0]
      5'd11: init_entry = {1'b1,((FAST_LNA == 1) ? 8'h04 : 8'h00)};
      5'd12: init_entry = {1'b1,8'h43}; // Address 0x0c, TX twos complement and interpolation factor
      5'd13: init_entry = {1'b1,8'h03}; // Address 0x0d, RX twos complement
      5'd14: init_entry = {1'b1,8'h81}; // Address 0x0e, Enable/Disable IAMP
      5'd15: init_entry = {1'b0,8'h00}; // Address 0x0f,
      5'd16: init_entry = {1'b1,8'h80}; // Address 0x10, Select TX gain
      5'd17: init_entry = {1'b1,8'h00}; // Address 0x11, Select TX gain
      5'd18: init_entry = {1'b1,8'h00}; // Address 0x12,
      5'd19: init_entry = {1'b0,8'h00}; // Address 0x13,
      default: init_entry = {1'b0,8'h00};
    endcase
  end
endfunction

localparam
  CMD_IDLE    = 2'b00,
  CMD_TXGAIN  = 2'b01,
  CMD_RXGAIN  = 2'b11,
  CMD_WRITE   = 2'b10;

// Command slave
logic [1:0]       cmd_state = CMD_IDLE;
logic [1:0]       cmd_state_next;
logic [3:0]       tx_gain = 4'hf;
logic [3:0]       tx_gain_next = 4'hf;
logic [6:0]       rx_gain = 7'b1000000;

logic [12:0]      icmd_data = 12'h000;

// Command Slave State Machine
always @(posedge clk) begin
  cmd_state <= cmd_state_next;
  tx_gain <= tx_gain_next;
  cmd_ack <= cmd_ack_next;
end

always @* begin
  cmd_state_next = cmd_state;
  tx_gain_next = tx_gain;
  cmd_ack_next = cmd_ack;
  istart = 1'b0;

  icmd_data  = {cmd_data[20:16],cmd_data[7:0]};

  case(cmd_state)

    CMD_IDLE: begin
      if (cmd_rqst) begin
        cmd_ack_next = 1'b1; // Assume acknowledge
        // Accept possible write
        case (cmd_addr)
          // Hermes TX Gain Setting
          CMDA_VNA_TXGAIN: begin
            if (tx_gain != cmd_data[31:28]) begin
              // Must update
              if (rffe_ad9866_sen_n) begin
                tx_gain_next = cmd_data[31:28];
                cmd_state_next = CMD_TXGAIN;
              end else begin
                cmd_ack_next = 1'b0;
              end
            end
          end

          // Hermes RX Gain Setting
          CMDA_RXGAIN_PURESIG: begin
            // Rely on synthesis to prune
            if (FAST_LNA != 1) begin
              if (rx_gain != cmd_data[6:0]) begin
                // Must update
                if (rffe_ad9866_sen_n) begin
                  cmd_state_next = CMD_RXGAIN;
                end else begin
                  cmd_ack_next = 1'b0;
                end
              end
            end else begin
              cmd_state_next = CMD_RXGAIN;
            end
          end

          // Generic AD9866 write
          CMDA_AD9866_WRITE: begin
            if (cmd_data[31:24] == 8'h06) begin
              // Must write
              if (rffe_ad9866_sen_n) cmd_state_next = CMD_WRITE;
              else cmd_ack_next = 1'b0;
            end
          end

          default: cmd_state_next = cmd_state;

        endcase
      end
    end

    CMD_TXGAIN: begin
      istart     = 1'b1;
      icmd_data  = {5'h0a,4'b0100,tx_gain};
      cmd_state_next = CMD_IDLE;
    end

    CMD_RXGAIN: begin
      // Rely on synthesis to prune
      if (FAST_LNA != 1) begin
        istart          = 1'b1;
        icmd_data[12:6] = {5'h09,2'b01};
        icmd_data[5:0]  = rx_gain[6] ? rx_gain[5:0] : (rx_gain[5] ? ~rx_gain[5:0] : {1'b1,rx_gain[4:0]});
        cmd_state_next  = CMD_IDLE;
      end else begin
        cmd_state_next  = CMD_IDLE;
      end
    end

    CMD_WRITE: begin
      istart          = 1'b1;
      icmd_data       = {cmd_data[20:16],cmd_data[7:0]};
      cmd_state_next  = CMD_IDLE;
    end

  endcase
end

// SPI interface
assign sdo       = 1'b0;

// Init program counter
always @(posedge clk) begin: AD9866_DUT1_FSM
    if (rst) begin
        dut1_pc <= 6'h00;
    end
    else begin
        if ((dut1_pc != 6'h3f) & rffe_ad9866_sen_n) begin
            dut1_pc <= (dut1_pc + 6'h01);
        end
        // Toggle LSB
        else if ((dut1_pc == 6'h3f) & rffe_ad9866_sen_n) begin
            dut1_pc <= 6'h3e;
        end
    end
end

always @* begin
    initarrayv = init_entry(dut1_pc[5:1]);
    datain = {3'b000,icmd_data};
    start = 1'b0;
    if (rffe_ad9866_sen_n) begin
        if (dut1_pc[5:1] <= 6'h13) begin
            if (dut1_pc[0] == 1'b0) begin

                datain = {3'h0,dut1_pc[5:1],initarrayv[7:0]};
                start = initarrayv[8];
            end
        end else begin
            start = istart;
        end
    end
end

//assign dataout = dut2_data[8-1:0];
assign rffe_ad9866_sdio = dut2_data[15];

// SPI state machine
always @(posedge clk) begin: AD9866_DUT2_FSM
  if (rst) begin
    rffe_ad9866_sen_n <= 1;
    rffe_ad9866_sclk <= 0;
    dut2_state <= 1'b0;
    dut2_data <= 0;
    dut2_bitcount <= 0;
  end
  else begin
    case (dut2_state)
      1'b0: begin
        rffe_ad9866_sclk <= 0;
        dut2_bitcount <= 15;
        if (start) begin
          dut2_data <= datain;
          rffe_ad9866_sen_n <= 0;
          dut2_state <= 1'b1;
        end
        else begin
          rffe_ad9866_sen_n <= 1;
        end
      end
      1'b1: begin
        dut2_state <= 1'b1;
        if ((!rffe_ad9866_sclk)) begin
          rffe_ad9866_sclk <= 1;
        end
        else begin
          dut2_data <= {dut2_data[15-1:0], sdo};
          dut2_bitcount <= (dut2_bitcount - 4'h1);
          rffe_ad9866_sclk <= 0;
          if ((dut2_bitcount == 0)) begin
            dut2_state <= 1'b0;
          end
        end
      end
    endcase
  end
end

endmodule // ad9866ctrl

