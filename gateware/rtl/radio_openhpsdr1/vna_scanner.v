/*
--------------------------------------------------------------------------------
This library is free software; you can redistribute it and/or
modify it under the terms of the GNU Library General Public
License as published by the Free Software Foundation; either
version 2 of the License, or (at your option) any later version.
This library is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
Library General Public License for more details.
You should have received a copy of the GNU Library General Public
License along with this library; if not, write to the
Free Software Foundation, Inc., 51 Franklin St, Fifth Floor,
Boston, MA  02110-1301, USA.
--------------------------------------------------------------------------------
*/


//------------------------------------------------------------------------------
//           Copyright (c) 2016 James C. Ahlstrom, N2ADR
//------------------------------------------------------------------------------

// 2016 Nov 26 - new VNA logic James Ahlstrom N2ADR

// This module scans a set of vna_count frequencies starting from tx_freq_in and adding freq_delta for each point.  Each
// point is the average of 1024 cordic I/Q outputs.  For each point, the frequency is changed, then there is a pause to allow things
// to stabilize, then the average is taken and returned with the output_strobe.  The PC receives the points as normal I/Q samples
// at a rate of 8000 sps.  A zero sample is output at the start of the scan and the next sample is for the first frequency.

// This module also sets the Tx frequency for the original VNA method in which the PC scans the frequencies.

module vna_scanner (
  input                      clk          ,
  input               [31:0] freq_delta   ,
  output logic               output_strobe,
  input        signed [17:0] cordic_data_I,
  input        signed [17:0] cordic_data_Q,
  output logic signed [23:0] out_data_I   ,
  output logic signed [23:0] out_data_Q   ,
  // VNA modes are PC-scan and FPGA-scan
  input                      vna          , // True for either scanning by the FPGA or PC
  input               [31:0] tx_freq_in   ,
  output logic        [31:0] tx_freq      ,
  output logic        [ 1:0] tx_zero      ,
  output logic        [31:0] rx0_phase    ,
  input               [15:0] vna_count
);

parameter CICRATE;
parameter RATE48;   // The decimation for 48000 sps

localparam DECIMATION = (RATE48 * CICRATE * 8) * 6; // The decimation; the number of clocks per output sample

localparam VNA_STARTUP        = 3'd0; // States in the state machine
localparam VNA_PC_SCAN        = 3'd1;
localparam VNA_TAKE_DATA      = 3'd2;
localparam VNA_ZERO_DATA      = 3'd3;
localparam VNA_RETURN_DATUM1  = 3'd4;
localparam VNA_RETURN_DATUM2  = 3'd5;
localparam VNA_CHANGE_FREQ    = 3'd6;
localparam VNA_WAIT_STABILIZE = 3'd7;

logic [2:0] vna_state_next, vna_state = VNA_STARTUP; // state machine for both VNA modes
logic        [13:0] vna_decimation_next, vna_decimation; // count up DECIMATION clocks, and then output a sample; increase bits for clock > 131 MHz
logic        [15:0] vna_counter_next, vna_counter; // count the number of scan points until we get to vna_count desired points
logic        [ 9:0] data_counter_next, data_counter; // Add up 1024 cordic samples per output sample ; 2**10 = 1024
logic signed [27:0] vna_I_next, vna_I, vna_Q_next, vna_Q; // accumulator for I/Q cordic samples: 18 bit cordic * 10-bits = 28 bits
logic               output_strobe_next ;
logic signed [23:0] out_data_I_next    ;
logic signed [23:0] out_data_Q_next    ;
logic        [31:0] tx_freq_next       ;
//logic               tx_zero_next       ;

always @(posedge clk) begin
  if (!vna) begin // Not in VNA mode; operate as a regular receiver
    tx_freq   <= tx_freq_in;
    rx0_phase <= freq_delta;
    vna_state <= VNA_STARTUP;
    tx_zero   <= 2'b00;
  end else begin
    vna_state      <= vna_state_next;
    tx_freq        <= tx_freq_next;
    rx0_phase      <= tx_freq_next;
    tx_zero        <= {(tx_freq_next[31:16] == 16'h0), (tx_freq_next[15:0] == 16'h0)};
    vna_counter    <= vna_counter_next;
    vna_decimation <= vna_decimation_next;
    output_strobe  <= output_strobe_next;
    vna_I          <= vna_I_next;
    vna_Q          <= vna_Q_next;
    out_data_I     <= out_data_I_next;
    out_data_Q     <= out_data_Q_next;
    data_counter   <= data_counter_next;
  end
end

always @* begin
  tx_freq_next        = tx_freq;
  //tx_zero_next        = tx_zero;
  vna_state_next      = vna_state;
  vna_counter_next    = vna_counter;
  vna_decimation_next = vna_decimation;
  output_strobe_next  = output_strobe;
  vna_I_next          = vna_I;
  vna_Q_next          = vna_Q;
  out_data_I_next     = out_data_I;
  out_data_Q_next     = out_data_Q;
  data_counter_next   = data_counter;

  case (vna_state)
    VNA_STARTUP : begin    // Start VNA mode; zero the Rx and Tx frequencies to synchronize the cordics to zero phase
      tx_freq_next        = 32'h0000;
      //tx_zero_next        = 1'b0;
      vna_counter_next    = 1'd1;
      vna_decimation_next = DECIMATION;
      output_strobe_next  = 1'b0;
      if (vna_count == 1'd0)
        vna_state_next = VNA_PC_SCAN;
      else
        vna_state_next = VNA_CHANGE_FREQ;
    end

    VNA_PC_SCAN : begin    // stay in this VNA state when the PC scans the VNA points
      tx_freq_next = tx_freq_in;
      //tx_zero_next = (tx_freq_in == 32'h0);
      if (vna_count != 1'd0)    // change to vna_count
        vna_state_next <= VNA_STARTUP;
    end

    VNA_TAKE_DATA : begin  // add up points to produce a sample
      vna_decimation_next = vna_decimation - 1'd1;
      vna_I_next          = vna_I + cordic_data_I;
      vna_Q_next          = vna_Q + cordic_data_Q;
      if (data_counter == 1'b0)
        vna_state_next = VNA_RETURN_DATUM1;
      else
        data_counter_next <= data_counter - 1'd1;
    end

    VNA_ZERO_DATA : begin // make a zero sample
      vna_decimation_next = vna_decimation - 1'd1;
      if (data_counter == 1'b0)
        vna_state_next = VNA_RETURN_DATUM1;
      else
        data_counter_next = data_counter - 1'd1;
    end

    VNA_RETURN_DATUM1 : begin  // Return the sample
      vna_decimation_next = vna_decimation - 1'd1;
      out_data_I_next     = vna_I[27:4];
      out_data_Q_next     = vna_Q[27:4];
      vna_state_next      = VNA_RETURN_DATUM2;
    end

    VNA_RETURN_DATUM2 : begin  // Return the sample
      vna_decimation_next = vna_decimation - 1'd1;
      if (vna_count == 1'd0)    // change to vna_count
        vna_state_next = VNA_STARTUP;
      else begin
        output_strobe_next = 1'b1;
        vna_state_next     = VNA_CHANGE_FREQ;
      end
    end

    VNA_CHANGE_FREQ : begin  // done with samples; change frequency
      vna_decimation_next = vna_decimation - 1'd1;
      output_strobe_next  = 1'b0;
      if (vna_counter == 1'd1) begin
        tx_freq_next     = tx_freq_in;  // starting frequency for scan
        //tx_zero_next     = (tx_freq_in == 32'h0);
        vna_counter_next = 1'd0;
      end else if (vna_counter == 1'd0) begin
        vna_counter_next = vna_count;
      end else begin
        vna_counter_next = vna_counter - 1'd1;
        tx_freq_next     = tx_freq + freq_delta;  // freq_delta is the frequency to add for each point
        //tx_zero_next     = 1'b0;
      end
      vna_state_next = VNA_WAIT_STABILIZE;
    end

    VNA_WAIT_STABILIZE : begin // Output samples at 8000 sps.  Allow time for output to stabilize after a frequency change.
      if (vna_decimation == 1'b0) begin
        vna_I_next          = 1'd0;
        vna_Q_next          = 1'd0;
        vna_decimation_next = DECIMATION - 1;
        data_counter_next   = 10'd1023;
        if (vna_counter == 0)
          vna_state_next = VNA_ZERO_DATA;
        else
          vna_state_next = VNA_TAKE_DATA;
      end else begin
        vna_decimation_next = vna_decimation - 1'd1;
      end
    end
  endcase
end


endmodule
