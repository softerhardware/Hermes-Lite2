//
//  I2S interface for AK4951
//    Tx : Send L/R 16bit data to AK4951
//    Rx : Receive L(or R) 24bit data from AK4958 and rounding 16bit data to zero
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

module i2s_ak4951 (
  input             clk,

  input      [31:0] tx_data,
  output reg        tx_data_req, // request next LR data 

  output reg [15:0] rx_data,
  output reg        rx_data_valid,

  output reg        i2s_bck,
  output reg        i2s_lrck,
  output reg        i2s_mosi,
  input             i2s_miso
) ;

  // BCLK
  reg [4:0] bcnt ;
  wire bcnt_full = ( bcnt == 5'd24 ) ; // 76.8MHz setting
  wire bcnt_half = ( bcnt == 5'd12 ) ; // 76.8MHz setting
  wire bcnt_load = ( bcnt == 5'd23 ) ; // 76.8MHz setting
  
  always @(posedge clk)
    if ( bcnt_full )
      bcnt <= 5'd0 ;
    else
      bcnt <= bcnt + 1'b1 ;

  always @(posedge clk)
    if ( bcnt_full )
      i2s_bck <= 1'b0 ;
    else if ( bcnt_half )
      i2s_bck <= 1'b1 ;

  // LRCK
  reg [5:0] wcnt ;
  always @(posedge clk)
    if ( bcnt_full )
      wcnt <= wcnt + 1'b1 ;

  wire wcnt_full = ( wcnt == 6'd63 ) ;
  wire wcnt_half = ( wcnt == 6'd31 ) ;
  wire wcnt_zero = ( wcnt == 6'd0  ) ;
  wire wcnt_comm = (( wcnt >= 6'd0 ) & ( wcnt < 6'd17 )) | (( wcnt >= 6'd32 ) & ( wcnt < 6'd49 )) ;
  wire lrck_fall = wcnt_full & bcnt_full ;
  wire lrck_rise = wcnt_half & bcnt_full ;

  always @(posedge clk)
    if ( lrck_fall )
      i2s_lrck <= 1'b0 ;
    else if ( lrck_rise )
      i2s_lrck <= 1'b1 ;

  reg wcnt_sft ;
  always @(posedge clk)
    if ( bcnt_full )
      wcnt_sft <= wcnt_comm ;


  // MISO sync
  reg i2s_miso_d ;
  always @(posedge clk)
    i2s_miso_d <= i2s_miso ;

  // shift register
  reg [16:0] sfr ;  // 17bit for receiver

  wire sfr_load_lch = wcnt_zero & bcnt_load ;
  wire sfr_load_rch = wcnt_half & bcnt_load ;
  wire sfr_shift    = wcnt_sft  & bcnt_half ;

  always @(posedge clk)
    if ( sfr_load_lch )
      sfr <= {tx_data[31:16], 1'b0} ;  // load tx-L data
    else if ( sfr_load_rch ) begin
      sfr <= {tx_data[15:0], 1'b0} ;   // load tx-R data
      tx_data_req <= 1'b1 ;
    end else if ( sfr_shift )
      sfr <= {sfr[15:0], i2s_miso_d} ;
    else
      tx_data_req <= 1'b0 ;

  // MOSI
  always @(posedge clk)
    if ( bcnt_full ) begin
      if ( wcnt_comm ) begin
        i2s_mosi <= sfr[16] ;
      end else begin
        i2s_mosi <= 1'b0 ;
      end
    end

  // receive data (microphone)
  // output Left Channel data to FIFO at the halfway of audio frame
  always @(posedge clk) begin
    if ( wcnt_half & bcnt_half ) begin // Left  Channel
      rx_data <= sfr[16] ? sfr[16:1]+sfr[0] : sfr[16:1] ; // round to zero
      rx_data_valid <= 1'b1 ;
    end else begin
      rx_data_valid <= 1'b0 ;
    end
  end

// output Left Channel data to FIFO at the end of audio frame
//  reg [15:0] rx_data_temp ;
//  always @(posedge clk) begin
//    if ( wcnt_half & bcnt_half ) begin // Left  Channel
//      rx_data_temp <= sfr[16] ? sfr[16:1]+sfr[0] : sfr[16:1] ;
//    end
// 
//    if ( wcnt_zero & bcnt_half ) begin // Right Channel
//      rx_data <= rx_data_temp ;
//      rx_data_valid <= 1'b1 ;
//    end else begin
//      rx_data_valid <= 1'b0 ;
//    end
//  end

endmodule
