
module led_flash (
  clk,
  cnt,
  sig,
  led
);
input       clk;
input       cnt;
input       sig;
output      led;

localparam  STATE_CLR   = 2'b00,
            STATE_SET   = 2'b01,
            STATE_WAIT1 = 2'b10,
            STATE_WAIT2 = 2'b11;

logic [1:0] state = STATE_CLR;
logic [1:0] state_next;

always @(posedge clk) state <= state_next;

// LED remains on for 2-3 ticks of cnt
always @* begin
  state_next = state;
  
  case (state)
    STATE_CLR: begin
      led = 1'b1; // 1 clears LED
      if (sig) state_next = STATE_SET;
    end

    STATE_SET: begin
      led = 1'b0;
      if (cnt) state_next = STATE_WAIT1;
    end 

    STATE_WAIT1: begin
      led = 1'b0;
      if (cnt) state_next = STATE_WAIT2;
    end

    STATE_WAIT2: begin
      led = 1'b0;
      if (cnt) state_next = STATE_CLR;
    end
  endcase 
end 

endmodule 



module ioblock(
  // Internal
  clk,
  rst,

  rxclip,
  rxgoodlvl,
  rxclrstatus,
  run,

  cmd_addr,
  cmd_data,
  cmd_rqst,
  cmd_requires_resp,
  cmd_ack_ext,
  cmd_ptt,

  clk_i2c_rst,
  clk_i2c_start,

  tx_on,
  cw_keydown,

  resp_rqst,
  resp,

  // External
  rffe_rfsw_sel,

  // Power
  pwr_clk3p3,
  pwr_clk1p2,
  pwr_envpa, 

`ifdef BETA2
  pwr_clkvpa,
`else
  pwr_envop,
  pwr_envbias,
`endif

  // Clock
  clk_recovered,

  sda1_i,
  sda1_o,
  sda1_t,
  scl1_i,
  scl1_o,
  scl1_t,

  sda2_i,
  sda2_o,
  sda2_t,
  scl2_i,
  scl2_o,
  scl2_t,

  sda3_i,
  sda3_o,
  sda3_t,
  scl3_i,
  scl3_o,
  scl3_t,

  // IO
  io_led_d2,
  io_led_d3,
  io_led_d4,
  io_led_d5,
  io_lvds_rxn,
  io_lvds_rxp,
  io_lvds_txn,
  io_lvds_txp,
  io_cn8,
  io_cn9,
  io_cn10,

  io_db1_2,       // BETA2,BETA3: io_db24
  io_db1_3,       // BETA2,BETA3: io_db22_3
  io_db1_4,       // BETA2,BETA3: io_db22_2
  io_db1_5,       // BETA2,BETA3: io_cn4_6
  io_db1_6,       // BETA2,BETA3: io_cn4_7    
  io_phone_tip,   // BETA2,BETA3: io_cn4_2
  io_phone_ring,  // BETA2,BETA3: io_cn4_3
  io_tp2,
  
`ifndef BETA2
  io_tp7,
  io_tp8,  
  io_tp9,
`endif

  // PA
`ifdef BETA2
  pa_tr,
  pa_en
`else
  pa_inttr,
  pa_exttr
`endif
);

// Internal
input           clk;
input           rst;

input           rxclip;
input           rxgoodlvl;
output logic    rxclrstatus = 1'b0;
input           run;

input  [5:0]    cmd_addr;
input  [31:0]   cmd_data;
input           cmd_rqst;
input           cmd_requires_resp;
input           cmd_ack_ext;
input           cmd_ptt;

input           clk_i2c_rst;
input           clk_i2c_start;

output          tx_on;
output          cw_keydown;

input           resp_rqst;
output [39:0]   resp;

// External
output          rffe_rfsw_sel;

// Power
output          pwr_clk3p3;
output          pwr_clk1p2;
output          pwr_envpa; 

`ifdef BETA2
output          pwr_clkvpa;
`else
output          pwr_envop;
output          pwr_envbias;
`endif

// Clock
output          clk_recovered;

input           sda1_i;
output          sda1_o;
output          sda1_t;
input           scl1_i;
output          scl1_o;
output          scl1_t;

input           sda2_i;
output          sda2_o;
output          sda2_t;
input           scl2_i;
output          scl2_o;
output          scl2_t;

input           sda3_i;
output          sda3_o;
output          sda3_t;
input           scl3_i;
output          scl3_o;
output          scl3_t;

// IO
output          io_led_d2;
output          io_led_d3;
output          io_led_d4;
output          io_led_d5;
input           io_lvds_rxn;
input           io_lvds_rxp;
input           io_lvds_txn;
input           io_lvds_txp;
input           io_cn8;
input           io_cn9;
input           io_cn10;

input           io_db1_2;       // BETA2;BETA3: io_db24
input           io_db1_3;       // BETA2;BETA3: io_db22_3
input           io_db1_4;       // BETA2;BETA3: io_db22_2
output          io_db1_5;       // BETA2;BETA3: io_cn4_6
input           io_db1_6;       // BETA2;BETA3: io_cn4_7    
input           io_phone_tip;   // BETA2;BETA3: io_cn4_2
input           io_phone_ring;  // BETA2;BETA3: io_cn4_3
input           io_tp2;
  
`ifndef BETA2
input           io_tp7;
input           io_tp8;  
input           io_tp9;
`endif

  // PA
`ifdef BETA2
output          pa_tr;
output          pa_en;
`else
output          pa_inttr;
output          pa_exttr;
`endif

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

logic         int_ptt = 1'b0;
logic         int_requires_resp = 1'b0;

logic [16:0]  led_count;
logic         led_saturate;

logic         ext_txinhibit, ext_cwkey, ext_ptt;

always @(posedge clk) begin
  if (cmd_rqst) begin
    int_ptt <= cmd_ptt;
    int_requires_resp <= cmd_requires_resp;   
    if (cmd_addr == 6'h09) begin
      vna          <= cmd_data[23];      // 1 = enable vna mode
      pa_enable    <= cmd_data[19];
      tr_disable   <= cmd_data[18];
    end
  end
end


i2c i2c_i (
  .clk(clk),
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



// 6.5 ms debounce with 2.5MHz clock 
debounce de_cwkey(.clean_pb(ext_cwkey), .pb(~io_phone_tip), .clk(clk));
assign io_db1_5 = ext_cwkey;
assign cw_keydown = ext_cwkey;

debounce de_ptt(.clean_pb(ext_ptt), .pb(~io_phone_ring), .clk(clk));
debounce de_txinhibit(.clean_pb(ext_txinhibit), .pb(~io_cn8), .clk(clk));


assign tx_on = (int_ptt | ext_cwkey | ext_ptt | vna) & ~ext_txinhibit & run;

// At 2.5 MHz, led_saturate occurs about every 50ms
always @(posedge clk) led_count <= led_count + 1;
assign led_saturate = &led_count;

led_flash led_run(.clk(clk), .cnt(led_saturate), .sig(run), .led(io_led_d2));
led_flash led_tx(.clk(clk), .cnt(led_saturate), .sig(tx_on), .led(io_led_d3));
led_flash led_rxgoodlvl(.clk(clk), .cnt(led_saturate), .sig(rxgoodlvl), .led(io_led_d4));
led_flash led_rxclip(.clk(clk), .cnt(led_saturate), .sig(rxclip), .led(io_led_d5));

// Clear status
always @(posedge clk) rxclrstatus <= ~rxclrstatus;





// FIXME: Sequence power
// FIXME: External TR won't work in low power mode
`ifdef BETA2
assign pa_tr = tx_on & (pa_enable | ~tr_disable);
assign pa_en = tx_on & pa_enable;
assign pwr_envpa = tx_on;
`else
assign pwr_envbias = tx_on & pa_enable;
assign pwr_envop = tx_on;
assign pa_exttr = tx_on;
assign pa_inttr = tx_on & (pa_enable | ~tr_disable);
assign pwr_envpa = tx_on & pa_enable;
`endif

assign rffe_rfsw_sel = pa_enable;

assign pwr_clk3p3 = 1'b0;
assign pwr_clk1p2 = 1'b0;

`ifdef BETA2
assign pwr_clkvpa = 1'b0;
`endif

assign clk_recovered = 1'b0;



assign cmd_ack = int_requires_resp & (cmd_ack_i2c | cmd_ack_ext);

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
      iresp <= {1'b1,cmd_addr_resp,tx_on, cmd_data_resp}; // Queue size is 1
    end else begin
      case( resp_addr) 
        2'b00: iresp <= {3'b000,resp_addr,2'b00,tx_on, 7'b0001111,(~io_led_d4 | ~io_led_d5), 8'h00, 8'h00, HERMES_SERIALNO};
        2'b01: iresp <= {3'b000,resp_addr,2'b00,tx_on, 4'h0,temperature, 4'h0,fwd_pwr};
        2'b10: iresp <= {3'b000,resp_addr,2'b00,tx_on, 4'h0,rev_pwr, 4'h0,bias_current};
        2'b11: iresp <= {3'b000,resp_addr,2'b00,tx_on, 32'h0}; // Unused in HL
      endcase 
    end
  end 
end

assign resp = iresp;

endmodule // ioblock
