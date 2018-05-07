
module ioblock(
  // Internal
  input           clk,
  input           rst,

  input           rxclipp,
  input           rxclipn,
  input           this_MAC,
  input           run_sync,

  input  [5:0]    cmd_addr,
  input  [31:0]   cmd_data,
  input           cmd_rqst,
  input           cmd_resprqst,
  input           cmd_ack_ext,

  input           clock_2_5MHz,
  input           clk_i2c_rst,
  input           clk_i2c_start,

  output          ext_ptt,
  output          ext_cwkey,
  output          ext_txinhibit,

  input           cmd_ptt,

  input           resp_rqst,
  output [39:0]   resp,

  // External
  output          rffe_rfsw_sel,

  // Power
  output          pwr_clk3p3,
  output          pwr_clk1p2,
  output          pwr_envpa, 

`ifdef BETA2
  output          pwr_clkvpa,
`else
  output          pwr_envop,
  output          pwr_envbias,
`endif

  // Clock
  output          clk_recovered,

  input           sda1_i,
  output          sda1_o,
  output          sda1_t,
  input           scl1_i,
  output          scl1_o,
  output          scl1_t,

  input           sda2_i,
  output          sda2_o,
  output          sda2_t,
  input           scl2_i,
  output          scl2_o,
  output          scl2_t,

  input           sda3_i,
  output          sda3_o,
  output          sda3_t,
  input           scl3_i,
  output          scl3_o,
  output          scl3_t,

  // IO
  output          io_led_d2,
  output          io_led_d3,
  output          io_led_d4,
  output          io_led_d5,
  input           io_lvds_rxn,
  input           io_lvds_rxp,
  input           io_lvds_txn,
  input           io_lvds_txp,
  input           io_cn8,
  input           io_cn9,
  input           io_cn10,

  input           io_db1_2,       // BETA2,BETA3: io_db24
  input           io_db1_3,       // BETA2,BETA3: io_db22_3
  input           io_db1_4,       // BETA2,BETA3: io_db22_2
  output          io_db1_5,       // BETA2,BETA3: io_cn4_6
  input           io_db1_6,       // BETA2,BETA3: io_cn4_7    
  input           io_phone_tip,   // BETA2,BETA3: io_cn4_2
  input           io_phone_ring,  // BETA2,BETA3: io_cn4_3
  input           io_tp2,
  
`ifndef BETA2
  input           io_tp7,
  input           io_tp8,  
  input           io_tp9,
`endif

  // PA
`ifdef BETA2
  output          pa_tr,
  output          pa_en
`else
  output          pa_inttr,
  output          pa_exttr
`endif
);

parameter     HERMES_SERIALNO = 8'h0;


logic         vna = 1'b0;                    // Selects vna mode when set.
logic         pa_enable = 1'b0;
logic         tr_disable = 1'b0;

logic [11:0]  fwd_pwr;
logic [11:0]  rev_pwr;
logic [11:0]  bias_current;
logic [11:0]  temperature;  

logic         cmd_ack_i2c;
logic         ptt;

logic [39:0]  iresp = {8'h00, 8'b00011110, 8'h00, 8'h00, HERMES_SERIALNO};
logic [ 1:0]  resp_addr = 2'b00;

logic         cmd_resp_rqst = 1'b0;

logic         cmd_ack;
logic [ 5:0]  cmd_addr_resp;
logic [31:0]  cmd_data_resp;

always @(posedge clk) begin   
  if (cmd_rqst & (cmd_addr == 6'h09)) begin
    vna             <= cmd_data[23];      // 1 = enable vna mode
    pa_enable    <= cmd_data[19];
    tr_disable   <= cmd_data[18];
  end
end


i2c i2c_i (
  .clk(clock_2_5MHz),
  .clock_76p8_mhz(clk),
  .rst(clk_i2c_rst),
  .init_start(clk_i2c_start),

  .cmd_addr(cmd_addr),
  .cmd_data(cmd_data),
  .cmd_rqst(cmd_rqst),
  .cmd_ack(cmd_ack_i2c),

  .scl1_i(scl1_i),
  .scl1_o(scl1_o),
  .scl1_t(scl1_t),
  .sda1_i(sda1_i),
  .sda1_o(sda1_o),
  .sda1_t(sda1_t),
  .scl2_i(scl2_i),
  .scl2_o(scl2_o),
  .scl2_t(scl2_t),
  .sda2_i(sda2_i),
  .sda2_o(sda2_o),
  .sda2_t(sda2_t)
);

slow_adc slow_adc_i (
  .clk(clk),
  .rst(rst),
  .ain0(fwd_pwr),
  .ain1(temperature),
  .ain2(bias_current),
  .ain3(rev_pwr),
  .scl_i(scl3_i),
  .scl_o(scl3_o),
  .scl_t(scl3_t),
  .sda_i(sda3_i),
  .sda_o(sda3_o),
  .sda_t(sda3_t)
);



// 5 ms debounce with 48 MHz clock
debounce de_cwkey(.clean_pb(ext_cwkey), .pb(~io_phone_tip), .clk(clk));
assign io_db1_5 = ext_cwkey;

// 5 ms debounce with 48 MHz clock, different clock frequency
debounce de_ptt(.clean_pb(ext_ptt), .pb(~io_phone_ring), .clk(clk));

debounce de_txinhibit(.clean_pb(ext_txinhibit), .pb(~io_cn8), .clk(clk));


assign ptt = (cmd_ptt | ext_cwkey | ext_ptt) & ~ext_txinhibit;

// Really 0.16 seconds at Hermes-Lite 61.44 MHz clock
localparam half_second = 24'd10000000; // at 48MHz clock rate

Led_flash Flash_LED0(.clock(clk), .signal(rxclipp), .LED(io_led_d4), .period(half_second));
Led_flash Flash_LED1(.clock(clk), .signal(rxclipn), .LED(io_led_d5), .period(half_second));
Led_flash Flash_LED2(.clock(clk), .signal(this_MAC), .LED(io_led_d2), .period(half_second));
Led_flash Flash_LED3(.clock(clk), .signal(run_sync), .LED(io_led_d3), .period(half_second));


// FIXME: Sequence power
// FIXME: External TR won't work in low power mode
`ifdef BETA2
assign pa_tr = ptt & (pa_enable | ~tr_disable);
assign pa_en = ptt & pa_enable;
assign pwr_envpa = ptt | (vna & ~ext_txinhibit);
`else
assign pwr_envbias = ptt & pa_enable;
assign pwr_envop = ptt | (vna & ~ext_txinhibit);
assign pa_exttr = ptt;
assign pa_inttr = ptt & (pa_enable | ~tr_disable);
assign pwr_envpa = ptt & pa_enable;
`endif

assign rffe_rfsw_sel = pa_enable;

assign pwr_clk3p3 = 1'b0;
assign pwr_clk1p2 = 1'b0;

`ifdef BETA2
assign pwr_clkvpa = 1'b0;
`endif

assign clk_recovered = 1'b0;



assign cmd_ack = cmd_resprqst & (cmd_ack_i2c | cmd_ack_ext);

always @(posedge clk) begin
  if (cmd_ack) begin
    cmd_resp_rqst <= 1'b1;
    cmd_addr_resp <= cmd_addr;
    cmd_data_resp <= cmd_data;
  end else if (resp_rqst) begin
    cmd_resp_rqst <= 1'b0;
  end
end

// Resp request occurs relatively infrequently
// Output register iresp is updated on resp_rqst
// Output register iresp will be stable before required in any other clock domain
always @(posedge clk) begin
  if (resp_rqst) begin
    resp_addr <= resp_addr + 2'b01; // Slot will be skipped if command response
    if (cmd_resp_rqst) begin
      // Command response
      iresp <= {1'b1,cmd_addr_resp,ptt, cmd_data_resp}; // Queue size is 1
    end else begin
      case( resp_addr) 
        2'b00: iresp <= {3'b000,resp_addr,2'b00,ptt, 7'b0001111,(~io_led_d4 | ~io_led_d5), 8'h00, 8'h00, HERMES_SERIALNO};
        2'b01: iresp <= {3'b000,resp_addr,2'b00,ptt, 4'h0,temperature, 4'h0,fwd_pwr};
        2'b10: iresp <= {3'b000,resp_addr,2'b00,ptt, 4'h0,rev_pwr, 4'h0,bias_current};
        2'b11: iresp <= {3'b000,resp_addr,2'b00,ptt, 32'h0}; // Unused in HL
      endcase 
    end
  end 
end

assign resp = iresp;

endmodule // ioblock
