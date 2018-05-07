
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
  output          cmd_ack,   

  input           clock_2_5MHz,
  input           clk_i2c_rst,
  input           clk_i2c_start,

  output          ext_ptt,
  output          ext_cwkey,
  output          ext_txinhibit,

  input           cmd_ptt,

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


logic         vna = 1'b0;                    // Selects vna mode when set.
logic         pa_enable = 1'b0;
logic         tr_disable = 1'b0;

logic [11:0]  AIN1;
logic [11:0]  AIN2;
logic [11:0]  AIN3;
logic [11:0]  AIN5;  // holds 12 bit ADC value of Forward Power detector.

logic         cmd_ack_i2c;
logic         ptt;


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
  .ain0(AIN1),
  .ain1(AIN5),
  .ain2(AIN3),
  .ain3(AIN2),
  .scl_i(scl3_i),
  .scl_o(scl3_o),
  .scl_t(scl3_t),
  .sda_i(sda3_i),
  .sda_o(sda3_o),
  .sda_t(sda3_t)
);


//---------------------------------------------------------
//  Debounce CWKEY input - active low
//---------------------------------------------------------

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

//wire vna_start = vna && cmd_rqst_io && (cmd_addr == 6'h01);  // indicates a frequency change for the vna.
//wire OVERFLOW;
//allow overflow message during tx to set pure signal feedback level
//assign OVERFLOW = (~leds[0] | ~leds[3]) ;

//assign cmd_ack = response_inp_tready & cmd_resprqst & (cmd_ack_i2c | cmd_ack_radio | cmd_ack_ad9866);

//axis_fifo #(.ADDR_WIDTH(1), .DATA_WIDTH(38)) response_fifo (
//  .clk(clk),
//  .rst(rst),
//  .input_axis_tdata({cmd_addr,cmd_data}),
//  .input_axis_tvalid(cmd_ack),
// .input_axis_tready(response_inp_tready),
//  .input_axis_tlast(1'b0),
//  .input_axis_tuser(1'b0),

//  .output_axis_tdata(response_out_tdata),
//  .output_axis_tvalid(response_out_tvalid),
//  .output_axis_tready(response_out_tready),
//  .output_axis_tlast(),
//  .output_axis_tuser()
//);

endmodule // ioblock
