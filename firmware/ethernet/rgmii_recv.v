//-----------------------------------------------------------------------------
//                    Copyright (c) 2012 HPSDR Team
//-----------------------------------------------------------------------------


//-----------------------------------------------------------------------------
// demultiplex phy nibbles, produce clock signal depending on speed
//-----------------------------------------------------------------------------


module rgmii_recv (
  input reset, 
  input speed_1Gbit, 

  //receive: data and active are valid at posedge of clock
  output clock, 
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



//PHY_RX_CLOCK must be delayed by ~2 ns in respect to PHY_RX and PHY_DV
//by programming the skew registers in phy 






//-----------------------------------------------------------------------------
//                                  clock
//-----------------------------------------------------------------------------
//reg slow_rx_clock;
//reg old_PHY_DV; 
 
 
//slow clock for the 100MBit mode 
//always @(posedge PHY_RX_CLOCK)
//  begin
//  slow_rx_clock <= ~slow_rx_clock | (PHY_DV && !old_PHY_DV);
//  old_PHY_DV <= PHY_DV;
//  end
 
 
assign clock = PHY_RX_CLOCK; // 1000T speed only...speed_1Gbit? PHY_RX_CLOCK : slow_rx_clock; 



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
  
  




//-----------------------------------------------------------------------------
//                 register rx data and control signals
//-----------------------------------------------------------------------------
reg data_coming = 0;


always @(posedge clock) 
  begin    
  data <= data_wire;
  data_coming <= rxdv_wire & !reset;
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
  