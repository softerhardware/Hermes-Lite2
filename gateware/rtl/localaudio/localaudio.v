//
//  AK4951 local audio interface with CW sidetone generator
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

module localaudio (
  input          clk,             // 76.3MHz
  input          rst,
  input          clk_i2c_rst,

  input  [31:0]  au_tdata,        // audio L/R tx data (16bit * 2)
  output         au_tready,       // next tx data request
  output [15:0]  au_rdata,        // audio L rx data (16bit)
  output         au_rvalid,       // audio rx data valid

  input          sidetone_sel,    // select sideton as audio output
  input          sidetone_req,    // sideton on/off

  input   [5:0]  cmd_addr,        // Command slave interface
  input  [31:0]  cmd_data,
  input          cmd_rqst,

  output         i2s_pdn,         // AK4951 i/o pins (I2S)
  output         i2s_bck,
  output         i2s_lrck,
  output         i2s_mosi,
  input          i2s_miso
) ;

//localparam sidetone_freq = 12'd600 ; // 600Hz
//localparam sidetone_vol  = 8'd255 ;  // Max

  wire [15:0] sidetone ;
  wire [31:0] audio_tx_data ;

  // -------------------------
  //  Command slave interface
  // -------------------------
  reg [ 7:0] sidetone_vol ;
  reg [11:0] sidetone_freq ;

  always @(posedge clk) begin
    if (cmd_rqst) begin
      case (cmd_addr)
        6'h0f: begin
          sidetone_vol <= cmd_data[23:16] ;
        end

        6'h10: begin
          sidetone_freq <= {cmd_data[15:8],cmd_data[3:0]} ;
        end
      endcase
    end
  end

  // ----------------------
  //  CW sideton generator
  // ----------------------
  cw_sidetone cw_sidetone_i (
    .clk(clk),                    // 76.3MHz
    .rst(rst),
    .sidetone_req(sidetone_req),  // sideton on/off
    .next_data_req(au_tready),    // next sideton data request
    .ToneFreq(sidetone_freq),     // sidetone audio frequency
    .audiovolume(sidetone_vol),   // sidetone audio volume
    .sidetone(sidetone)           // to audio codec
  ) ;


  // -----------------------
  //  audio output selector
  // -----------------------
  assign audio_tx_data = (sidetone_sel && (sidetone_vol != 8'b0)) ? {sidetone, sidetone} :
                         {au_tdata[7:0],au_tdata[15:8],au_tdata[23:16],au_tdata[31:24]} ;

  // -----------------------
  //  AK4951 interface
  // -----------------------
  assign i2s_pdn  = ~clk_i2c_rst;   // AK4951 PDN ; active "L"

  i2s_ak4951 i2s_i (
    .clk(clk),
    .tx_data(audio_tx_data),      // audio L/R tx data (16bit * 2)
    .tx_data_req(au_tready),      // next tx data request
    .rx_data(au_rdata),           // audio L rx data (16bit)
    .rx_data_valid(au_rvalid),    // audio rx data valid
    .i2s_bck(i2s_bck),
    .i2s_lrck(i2s_lrck),
    .i2s_mosi(i2s_mosi),
    .i2s_miso(i2s_miso)
 ) ;

endmodule