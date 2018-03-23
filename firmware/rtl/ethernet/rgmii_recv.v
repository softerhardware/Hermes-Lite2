//-----------------------------------------------------------------------------
//                    Copyright (c) 2012 HPSDR Team
//-----------------------------------------------------------------------------


//-----------------------------------------------------------------------------
// demultiplex phy nibbles, produce clock signal depending on speed
//-----------------------------------------------------------------------------


module rgmii_recv (
  input reset, 

  //receive: data and active are valid at posedge of clock
  input  clock, 
  input  speed_1gb,
  output reg [7:0] data,
  output active,
  
  //hardware pins
  input  [3:0]PHY_RX,     
  input  PHY_DV,
  input  PHY_RX_CLOCK
  );
  
  
  
  
//-----------------------------------------------------------------------------
//Altera application note AN 477: Designing RGMII Interfaces with FPGAs and HardCopy ASICs
// http://www.altera.com/literature/an/AN477.pdf
//
//Reduced Gigabit Media Independent Interface: (RGMII) 12/10/2000 Version 1.3 
// http://www.hp.com/rnd/pdfs/RGMIIv1_3.pdf
//
//KSZ9021RL/RN Gigabit Ethernet Transceiver with RGMII Support 
//http://www.micrel.com/_PDF/Ethernet/datasheets/ksz9021rl-rn_ds.pdf
//-----------------------------------------------------------------------------





//-----------------------------------------------------------------------------
//          de-multiplex nibbles presented at both clock edges
//-----------------------------------------------------------------------------
wire rxdv_wire, error;
wire [7:0] data_wire;


ddio_in  ddio_in_inst (      
  .datain({PHY_DV, PHY_RX}),
  .inclock(clock),
  .dataout_l({rxdv_wire, data_wire[3:0]}),
  .dataout_h({error, data_wire[7:4]})
  );  
  
  

// Realign data for two cases of divided clock when 100 Mbs

reg   [4:0] realigned_l = 'h0;
reg         data_coming = 'b0;
reg         realign     = 'b0;

always @(posedge clock) begin
  realigned_l <= {error, data_wire[7:4]};
  if (realign) {data_coming,data} <= {realigned_l[4] & ~reset,data_wire[3:0],realigned_l[3:0]};
  else {data_coming,data} <= {rxdv_wire & ~reset,data_wire};
end

always @(posedge clock) begin
  if (~speed_1gb) begin
    if (~realign & error & ~rxdv_wire) realign <= 1'b1;
    else if (realign & rxdv_wire & ~realigned_l[4]) realign <= 1'b0;
  end else
    realign <= 1'b0;
end
  
  
//-----------------------------------------------------------------------------
//                          preamble detector
//-----------------------------------------------------------------------------
localparam MIN_PREAMBLE_LENGTH = 3'd5;


reg [2:0] preamble_cnt;
reg payload_coming = 0;


always @(posedge clock) 
  //RX-DV low, nothing is being received
  if (!data_coming) begin payload_coming <= 1'b0; preamble_cnt <= MIN_PREAMBLE_LENGTH; end
  //RX-DV high, but payload is not being received yet
  else if (!payload_coming) 
    //count preamble bytes
    if (data == 8'h55) begin if (preamble_cnt != 0) preamble_cnt <= preamble_cnt - 3'd1; end
    //enough preamble bytes plus SFD, payload follows
    else if ((preamble_cnt == 0) && (data == 8'hD5)) payload_coming <= 1'b1;
    //wrong byte received, reset preamble byte count
    else preamble_cnt <= MIN_PREAMBLE_LENGTH;
      
      
assign active = data_coming & payload_coming;
      

  
endmodule
  