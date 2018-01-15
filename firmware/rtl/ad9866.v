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

module ad9866 (
  clk_ad9866,
  clk_ad9866_2x,
  rst_n,

  tx_data,
  rx_data,
  tx_en,

  rffe_ad9866_rst_n,
  rffe_ad9866_tx,
  rffe_ad9866_rx,
  rffe_ad9866_rxsync,
  rffe_ad9866_rxclk,  
  rffe_ad9866_txquiet_n,
  rffe_ad9866_txsync,
  rffe_ad9866_sdio,
  rffe_ad9866_sclk,
  rffe_ad9866_sen_n,

`ifdef BETA2
  rffe_ad9866_pga,
`else
  rffe_ad9866_pga5,
`endif

  rffe_ad9866_mode,

  // Wishbone slave interface
  wbs_adr_i,
  wbs_dat_i,
  wbs_we_i,
  wbs_stb_i,
  wbs_ack_o,
  wbs_cyc_i
);

parameter         WB_DATA_WIDTH = 32;
parameter         WB_ADDR_WIDTH = 6;

input             clk_ad9866;
input             clk_ad9866_2x;
input             rst_n;

input   [11:0]    tx_data;
output  [11:0]    rx_data;
input             tx_en;

output            rffe_ad9866_rst_n;
`ifdef HALFDUPLEX
inout   [5:0]     rffe_ad9866_tx;
inout   [5:0]     rffe_ad9866_rx;
output            rffe_ad9866_rxsync;
output            rffe_ad9866_rxclk; 
`else
output  [5:0]     rffe_ad9866_tx;
input   [5:0]     rffe_ad9866_rx;
input             rffe_ad9866_rxsync;
input             rffe_ad9866_rxclk; 
`endif
output            rffe_ad9866_txquiet_n;
output            rffe_ad9866_txsync;
output            rffe_ad9866_sdio;
output            rffe_ad9866_sclk;
output            rffe_ad9866_sen_n;

`ifdef BETA2
output  [5:0]     rffe_ad9866_pga;
`else
output            rffe_ad9866_pga5;
`endif

output            rffe_ad9866_mode;


// Wishbone slave interface
input  [WB_ADDR_WIDTH-1:0]  wbs_adr_i;
input  [WB_DATA_WIDTH-1:0]  wbs_dat_i;
input                       wbs_we_i;
input                       wbs_stb_i;
output                      wbs_ack_o;   
input                       wbs_cyc_i;

// TX Path
logic   [11:0]    tx_data_d1;
logic             tx_sync;
logic             tx_en_d1;

// RX Path
logic   [11:0]    rx_data_assemble;
logic    [5:0]    rffe_ad9866_rx_d1, rffe_ad9866_rx_d2;
logic             rffe_ad9866_rxsync_d1;

// SPI
logic   [15:0]    datain;
logic             start;
logic   [3:0]     dut2_bitcount;
logic   [1:0]     dut2_state;
logic   [15:0]    dut2_data;
logic   [5:0]     dut1_pc;
logic             sdo;

logic   [8:0]     initarrayv;
// Tool problems if below is logic
reg     [8:0]     initarray [19:0];


// Wishbone slave
logic [1:0]       wbs_state = 1'b0;
logic [1:0]       wbs_state_next;
logic [3:0]       tx_gain = 4'h0;
logic [3:0]       tx_gain_next;
logic [6:0]       rx_gain = 7'b1000000;
logic [6:0]       rx_gain_next;

logic             cmd_ack; 
logic [12:0]      cmd_data;

initial begin
  // First bit is 1'b1 for write enable to that address
  initarray[0] = {1'b0,8'h80}; // Address 0x00, enable 4 wire SPI
  initarray[1] = {1'b0,8'h00}; // Address 0x01,
  initarray[2] = {1'b0,8'h00}; // Address 0x02,
  initarray[3] = {1'b0,8'h00}; // Address 0x03,
  initarray[4] = {1'b0,8'h00}; // Address 0x04,
  initarray[5] = {1'b0,8'h00}; // Address 0x05,
  initarray[6] = {1'b1,8'h54}; // Address 0x06, Disable clkout2
  initarray[7] = {1'b1,8'h20}; // Address 0x07, Initiate DC offset calibration and RX filter on, 21 to 20 to disable RX filter
  initarray[8] = {1'b0,8'h4b}; // Address 0x08, RX filter f-3db at ~34 MHz after scaling
  initarray[9] = {1'b0,8'h00}; // Address 0x09,
  initarray[10] = {1'b0,8'h00}; // Address 0x0a,
  initarray[11] = {1'b1,8'h00}; // Address 0x0b, No RX gain on PGA
  initarray[12] = {1'b1,8'h43}; // Address 0x0c, TX twos complement and interpolation factor
  initarray[13] = {1'b1,8'h03}; // Address 0x0d, RX twos complement
  initarray[14] = {1'b1,8'h81}; // Address 0x0e, Enable/Disable IAMP
  initarray[15] = {1'b0,8'h00}; // Address 0x0f,
  initarray[16] = {1'b1,8'h80}; // Address 0x10, Select TX gain
  initarray[17] = {1'b1,8'h00}; // Address 0x11, Select TX gain
  initarray[18] = {1'b1,8'h00}; // Address 0x12,
  initarray[19] = {1'b0,8'h00}; // Address 0x13,
end

localparam 
  WBS_IDLE    = 2'b00,
  WBS_TXGAIN  = 2'b01,
  WBS_RXGAIN  = 2'b11,
  WBS_WRITE   = 2'b10;


assign rffe_ad9866_rst_n = rst_n;

`ifdef BETA2
assign rffe_ad9866_pga = 6'b000000;
`else
assign rffe_ad9866_pga5 = 1'b0;
`endif



// TX Path

always @(posedge clk_ad9866) tx_en_d1 <= tx_en;

`ifdef HALFDUPLEX
always @(posedge clk_ad9866) tx_data_d1 <= tx_data;
assign rffe_ad9866_tx = tx_en_d1 ? tx_data_d1[11:6] : 6'bZ;
assign rffe_ad9866_rx = tx_en_d1 ? tx_data_d1[5:0]  : 6'bZ;
assign rffe_ad9866_txsync = tx_en_d1;
assign rffe_ad9866_txquiet_n = clk_ad9866;

`else
always @(posedge clk_ad9866_2x) begin
  tx_sync <= ~tx_sync;
  if (tx_sync) begin 
    tx_data_d1 <= tx_en_d1 ? tx_data : 'h0;
    rffe_ad9866_tx <= tx_data_d1[5:0];
  end else begin
    rffe_ad9866_tx <= tx_data_d1[11:6];
  end
  rffe_ad9866_txsync <= tx_en_d1 ? tx_sync : 1'b0;
end

assign rffe_ad9866_txquiet_n = tx_en_d1; 

`endif



// RX Path

`ifdef HALFDUPLEX
always @(posedge clk_ad9866) rx_data_assemble <= {rffe_ad9866_tx,rffe_ad9866_rx};
assign rffe_ad9866_rxsync = ~tx_en_d1;
assign rffe_ad9866_rxclk = clk_ad9866;
assign rffe_ad9866_mode = 1'b0;

`else
// Assume that ad9866_rxclk is synchronous to ad9866clk
// Don't know the phase relation
always @(posedge clk_ad9866_2x) begin
  rffe_ad9866_rx_d1 <= rffe_ad9866_rx;
  rffe_ad9866_rx_d2 <= rffe_ad9866_rx_d1;
  rffe_ad9866_rxsync_d1 <= rffe_ad9866_rxsync;
  if (rffe_ad9866_rxsync_d1) rx_data_assemble <= {rffe_ad9866_rx_d2,rffe_ad9866_rx_d1};
end
assign rffe_ad9866_mode = 1'b1;
`endif

always @ (posedge clk_ad9866) rx_data <= rx_data_assemble;


// Wishbone Slave State Machine
always @(posedge clk_ad9866) begin
  if (~rst_n) begin
    wbs_state <= WBS_IDLE;
    tx_gain <= 4'h0;
    rx_gain <= 7'b1000000;
  end else begin
    wbs_state <= wbs_state_next;
    tx_gain <= tx_gain_next;
    rx_gain <= rx_gain_next;
  end
end

always @* begin
  wbs_state_next = wbs_state;
  tx_gain_next = tx_gain;
  rx_gain_next = rx_gain;
  cmd_ack = 1'b0;
  cmd_data  = {wbs_dat_i[20:16],wbs_dat_i[7:0]};

  case(wbs_state)

    WBS_IDLE: begin
      if (wbs_we_i & wbs_stb_i & rffe_ad9866_sen_n) begin
        // Accept possible write
        case (wbs_adr_i)

          // Hermes TX Gain Setting
          6'h09: begin
            tx_gain_next = wbs_dat_i[31:28];
            if (tx_gain != wbs_dat_i[31:28]) wbs_state_next = WBS_TXGAIN;
          end

          // Hermes RX Gain Setting
          6'h0a: begin
            rx_gain_next = wbs_dat_i[6:0];
            if (rx_gain != wbs_dat_i[6:0]) wbs_state_next = WBS_RXGAIN;
          end

          // Generic AD9866 write
          6'h3b: begin
            if (wbs_dat_i[31:24] == 8'h06) wbs_state_next = WBS_WRITE;
          end

          default: wbs_state_next = wbs_state;

        endcase 
      end        
    end

    WBS_TXGAIN: begin
      cmd_ack   = 1'b1;
      cmd_data  = {5'h0a,4'b0100,tx_gain};
      wbs_state_next = WBS_IDLE;
    end
    
    WBS_RXGAIN: begin
      cmd_ack   = 1'b1;
      cmd_data[12:6]  = {5'h09,2'b01};
      cmd_data[5:0]   = rx_gain[6] ? rx_gain[5:0] : (rx_gain[5] ? ~rx_gain[5:0] : {1'b1,rx_gain[4:0]});
      wbs_state_next = WBS_IDLE;
    end

    WBS_WRITE: begin
      cmd_ack   = 1'b1;
      cmd_data  = {wbs_dat_i[20:16],wbs_dat_i[7:0]};
      wbs_state_next = WBS_IDLE;
    end

  endcase
end

assign wbs_ack_o = cmd_ack;


// SPI interface
assign sdo       = 1'b0;

// Init program counter
always @(posedge clk_ad9866) begin: AD9866_DUT1_FSM
    if (~rst_n) begin
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
    initarrayv = initarray[dut1_pc[5:1]];
    datain = {3'b000,cmd_data};   
    start = 1'b0;
    if (rffe_ad9866_sen_n) begin
        if (dut1_pc[5:1] <= 6'h13) begin
            if (dut1_pc[0] == 1'b0) begin
                
                datain = {3'h0,dut1_pc[5:1],initarrayv[7:0]};
                start = initarrayv[8];
            end
        end else begin
            start = cmd_ack;
        end
    end
end

//assign dataout = dut2_data[8-1:0];
assign rffe_ad9866_sdio = dut2_data[15];

// SPI state machine
always @(posedge clk_ad9866) begin: AD9866_DUT2_FSM
  if (~rst_n) begin
    rffe_ad9866_sen_n <= 1;
    rffe_ad9866_sclk <= 0;
    dut2_state <= 2'b00;
    dut2_data <= 0;
    dut2_bitcount <= 0;
  end
  else begin
    case (dut2_state)
      2'b00: begin
        rffe_ad9866_sclk <= 0;
        dut2_bitcount <= 15;
        if (start) begin
          dut2_data <= datain;
          rffe_ad9866_sen_n <= 0;
          dut2_state <= 2'b01;
        end
        else begin
          rffe_ad9866_sen_n <= 1;
        end
      end
      2'b01: begin
        dut2_state <= 2'b11;
        if ((!rffe_ad9866_sclk)) begin
          rffe_ad9866_sclk <= 1;
        end
        else begin
          dut2_data <= {dut2_data[15-1:0], sdo};
          dut2_bitcount <= (dut2_bitcount - 1);
          rffe_ad9866_sclk <= 0;
          if ((dut2_bitcount == 0)) begin
            dut2_state <= 2'b00;
          end
        end
      end
      2'b11: begin
        dut2_state <= 2'b01;
      end
    endcase
  end
end

endmodule // ad9866

