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

// (C) Steve Haynal KF7O 2018

module ad9866 (
  clk_ad9866,
  clk_ad9866_2x,

  tx_data,
  rx_data,
  tx_en,

  //rffe_ad9866_rst_n,
  rffe_ad9866_tx,
  rffe_ad9866_rx,
  rffe_ad9866_rxsync,
  rffe_ad9866_rxclk,  
  rffe_ad9866_txquiet_n,
  rffe_ad9866_txsync,
  //rffe_ad9866_sdio,
  //rffe_ad9866_sclk,
  //rffe_ad9866_sen_n,
  //rffe_ad9866_pga,
  rffe_ad9866_mode
);

input             clk_ad9866;
input             clk_ad9866_2x;

input   [11:0]    tx_data;
output  [11:0]    rx_data;
input             tx_en;

//output          rffe_ad9866_rst_n;
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
//output          rffe_ad9866_sdio;
//output          rffe_ad9866_sclk;
//output          rffe_ad9866_sen_n;

//`ifdef BETA2
//output  [5:0]   rffe_ad9866_pga;
//`else
//output          rffe_ad9866_pga5;
//`endif

output            rffe_ad9866_mode;


logic   [11:0]    rx_data_assemble;
logic    [5:0]    rffe_ad9866_rx_d1, rffe_ad9866_rx_d2;
logic             rffe_ad9866_rxsync_d1;

logic   [11:0]    tx_data_d1;
logic             tx_sync;
logic             tx_en_d1;


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


endmodule // ad9866

