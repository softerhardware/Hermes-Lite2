//
//  HPSDR - High Performance Software Defined Radio
//
//  Metis code. 
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


//  Metis code copyright 2010, 2011, 2012, 2013 Alex Shovkoplyas, VE3NEA.


// 2021 Updated to support KSZ9021RN and KSZ9031RN on Hermes-Lite 2.0, KF7O.

//-----------------------------------------------------------------------------
// initialize the PHY device on startup
// by writing config data to its MDIO registers; 
// continuously read PHY status from the MDIO registers
//-----------------------------------------------------------------------------

module phy_cfg(
  //input
  input clock,        //2.5 MHZ
  input init_request,
  
  //output
  output reg [1:0] speed,
  output reg duplex,
  output reg is_ksz9021,
  
  //hardware pins
  inout mdio_pin,
  output mdc_pin  
);



//mdio register values
wire [15:0] values [7:0];



assign values[7] = 16'h8104; // RX clk to other skew of 1.2ns to match ksz9031rn, RGMII 2.0
assign values[6] = {8'hc2, 8'h77};
assign values[5] = 16'h8105;
assign values[4] = 16'h2222; 

assign values[3] = 16'h0200; // Allow 1GB but don't advertise half duplex in 1000BASET
assign values[2] = 16'h1300; // Restart autonegotiation

assign values[1] = 16'hxxxx;
assign values[0] = 16'hxxxx;

//mdio register addresses 
wire [4:0] addresses [7:0];


assign addresses[7] = 5'h0b;
assign addresses[6] = 5'h0c;
assign addresses[5] = 5'h0b;
assign addresses[4] = 5'h0c;

assign addresses[3] = 5'h09;
assign addresses[2] = 5'h00;

assign addresses[1] = 5'h03; // PHY identifier 2
assign addresses[0] = 5'h1f; // PHY Control 

reg [2:0] word_no = 3'h0;


//-----------------------------------------------------------------------------
//                            state machine
//-----------------------------------------------------------------------------

reg init_required;
wire ready;
wire [15:0] rd_data;
reg rd_request, wr_request;


//state machine  
localparam READING = 1'b0, WRITING = 1'b1;  
reg state = READING;  


always @(posedge clock) begin
  if (init_request) init_required <= 1'b1;
  
  if (ready)
    case (state)
      READING: begin
        if (word_no[0]) begin
          is_ksz9021 <= (rd_data[5:4] == 2'b01);
        end else begin
          speed <= rd_data[6:5];
          duplex <= rd_data[3];
        end
        
        if (init_required & word_no[0]) begin
          wr_request <= 1'b1;
          if (rd_data[5:4] == 2'b01) word_no <= 3'h7;
          else word_no <= 3'h3;
          state <= WRITING;
          init_required <= 1'b0;
        end else begin
          rd_request <= 1'b1;
          word_no <= {2'b00,~word_no[0]};
          state <= READING;
        end
      end

      WRITING: begin
        if (word_no == 3'h2) state <= READING;
        else wr_request <= 1'b1;
        //if ((word_no == 3'h7) & (~is_ksz9021)) word_no <= 3'h2;
        //else
        word_no <= word_no - 3'h1;		  
      end
    endcase
		
  else begin //!ready
    rd_request <= 0;
    wr_request <= 0;
  end
end

        
        
        
        
//-----------------------------------------------------------------------------
//                        MDIO interface to PHY
//-----------------------------------------------------------------------------


mdio mdio_inst (
  .clock(clock), 
  .addr(addresses[word_no]), 
  .rd_request(rd_request),
  .wr_request(wr_request),
  .ready(ready),
  .rd_data(rd_data),
  .wr_data(values[word_no]),
  .mdio_pin(mdio_pin),
  .mdc_pin(mdc_pin)
  );  
  



  
  
endmodule
