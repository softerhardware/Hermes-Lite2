
module control(
  // Internal
  clk,
  clk_ad9866,
  clk_125,
  clk_slow,

  ethup,
  have_dhcp_ip,
  have_fixed_ip,
  network_speed,
  ad9866up,

  rxclip,
  rxgoodlvl,
  rxclrstatus,
  run,

  dsiq_status,
  dsiq_sample,

  cmd_addr,
  cmd_data,
  cmd_rqst,
  cmd_requires_resp,

  atu_txinhibit,
  tx_on,
  cw_on,
  cw_keydown,

  msec_pulse,
  qmsec_pulse,

  resp_rqst,
  resp,

  static_ip,
  alt_mac,
  eeprom_config,

  // External
  rffe_rfsw_sel,

  rffe_ad9866_rst_n,
  rffe_ad9866_sdio,
  rffe_ad9866_sclk,
  rffe_ad9866_sen_n,

  // Power
  pwr_clk3p3,
  pwr_clk1p2,
  pwr_envpa,
  pwr_envop,
  pwr_envbias,

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
  io_led_run,
  io_led_tx,
  io_led_adc75,
  io_led_adc100,

  io_tx_inhibit,

  io_uart_txd,

  io_cw_keydown,

  io_phone_tip,   // BETA2,BETA3: io_cn4_2
  io_phone_ring,  // BETA2,BETA3: io_cn4_3

  io_atu_ack,
  io_atu_req,

  // PA
  pa_inttr,
  pa_exttr,

  hl2_reset,

  fan_pwm,

  ad9866_rst
  
);

// Internal
input           clk;
input           clk_ad9866;
input           clk_125;
input           clk_slow;

input           ethup;
input           have_dhcp_ip;
input           have_fixed_ip;
input  [1:0]    network_speed;
input           ad9866up;

input           rxclip;
input           rxgoodlvl;
output logic    rxclrstatus = 1'b0;
input           run;

input [7:0]     dsiq_status;
output logic    dsiq_sample = 1'b0;

input  [5:0]    cmd_addr;
input  [31:0]   cmd_data;
input           cmd_rqst;
input           cmd_requires_resp;

output          atu_txinhibit;
input           tx_on;
input           cw_on;
output          cw_keydown;

output logic    msec_pulse = 1'b0;
output logic    qmsec_pulse = 1'b0;

input           resp_rqst;
output [39:0]   resp;

output [31:0]   static_ip;
output [15:0]   alt_mac;
output [ 7:0]   eeprom_config;

// External
output          rffe_rfsw_sel;

output          rffe_ad9866_rst_n;

output          rffe_ad9866_sdio;
output          rffe_ad9866_sclk;
output          rffe_ad9866_sen_n;

// Power
output logic    pwr_clk3p3 = 1'b0;
output logic    pwr_clk1p2 = 1'b0;
output          pwr_envpa;
output          pwr_envop;
output          pwr_envbias;

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
output          io_led_run;
output          io_led_tx;
output          io_led_adc75;
output          io_led_adc100;

input           io_tx_inhibit;

output          io_uart_txd;
output          io_cw_keydown;
input           io_phone_tip;
input           io_phone_ring;

input           io_atu_ack;
output          io_atu_req;

// PA
output          pa_inttr;
output          pa_exttr;

output          hl2_reset;

output          fan_pwm;

output          ad9866_rst;


parameter     VERSION_MAJOR = 8'h0;
parameter     UART = 0;
parameter     ATU = 0;
parameter     FAN = 0;
parameter     PSSYNC = 0;
parameter     CW = 0;
parameter     FAST_LNA = 0;


logic         vna = 1'b0;                    // Selects vna mode when set.
logic         pa_enable = 1'b0;
logic         tr_disable = 1'b0;

logic [11:0]  fwd_pwr;
logic [11:0]  rev_pwr;
logic [11:0]  bias_current;
logic [11:0]  temperature;

logic         cmd_ack_i2c, cmd_ack_ad9866;
logic [31:0]  cmd_resp_data_i2c;
logic         ptt;

logic [39:0]  iresp = {8'h00, 8'b00011110, 8'h00, 8'h00, VERSION_MAJOR};
logic [ 1:0]  resp_addr = 2'b00;

logic         cmd_resp_rqst;

logic         cmd_ack;
logic [ 5:0]  resp_cmd_addr = 6'h00, resp_cmd_addr_next;
logic [31:0]  resp_cmd_data = 32'h00, resp_cmd_data_next;

logic [8:0]   led_count, led_count_next;
logic         led_saturate;
logic [9:0]   qmillisec_count, qmillisec_count_next;
logic [1:0]   millisec_count, millisec_count_next;

logic         ext_txinhibit, ext_cwkey, ext_ptt;

logic         slow_adc_rst;
logic         clk_i2c_rst;
logic         clk_i2c_start;

logic [15:0]  resetcounter = 16'h0000;
logic         resetsaturate;

logic [ 1:0]  clip_cnt = 2'b00;

logic         led_d2, led_d3, led_d4, led_d5;


logic         resp_cnt = 1'b0;

localparam RESP_START   = 2'b00,
           RESP_ACK     = 2'b01,
           RESP_READ    = 2'b11,
           RESP_WAIT    = 2'b10;

logic [1:0]   resp_state = RESP_START, resp_state_next;


logic         cw_keydown;

logic         ptt_resp = 1'b0;

logic [ 7:0]  ieeprom_config;

logic         use_eeprom_config = 1'b0;

logic         hl2_reset_state = 1'b0;

logic         temp_enabletx = 1'b1;

logic int_tx_on;

logic clean_ring;

logic slow_adc_sample;




/////////////////////////////////////////////////////
// Reset

// Most FPGA logic is reset when ethernet is up and ad9866 PLL is locked
// AD9866 is released from reset

assign resetsaturate = &resetcounter;

always @ (posedge clk)
  if (~resetsaturate & ethup) resetcounter <= resetcounter + 16'h01;

// At ~410us
assign clk_i2c_rst = ~(|resetcounter[15:10]);

// At ~820us
assign clk_i2c_start = (|resetcounter[15:11]);

// At ~6.5ms
assign slow_adc_rst = ~(|resetcounter[15:14]);

// At ~13ms
assign rffe_ad9866_rst_n = resetcounter[15];

// At ~26ms
assign ad9866_rst = ~resetsaturate | ~ad9866up;



always @(posedge clk) begin
  if (cmd_rqst) begin
    if (cmd_addr == 6'h09) begin
      vna          <= cmd_data[23];      // 1 = enable vna mode
      pa_enable    <= cmd_data[19];
      tr_disable   <= cmd_data[18];
    end
    else if (cmd_addr == 6'h3a) begin
      hl2_reset_state <= cmd_data[0];
    end
  end
end

// Reset FPGA from configuration flash if not running
assign hl2_reset = hl2_reset_state & ~run;

always @(posedge clk)
  if (slow_adc_rst) use_eeprom_config <= ~(clean_ring & ext_cwkey);

assign eeprom_config[7:5] = use_eeprom_config ? ieeprom_config[7:5] : 3'b000;
assign eeprom_config[4:0] = ieeprom_config[4:0];

i2c i2c_i (
  .clk(clk),
  .rst(clk_i2c_rst),
  .init_start(clk_i2c_start),

  .cmd_addr(cmd_addr),
  .cmd_data(cmd_data),
  .cmd_rqst(cmd_rqst),
  .cmd_ack(cmd_ack_i2c),
  .cmd_resp_data(cmd_resp_data_i2c),

  .static_ip(static_ip),
  .alt_mac(alt_mac),
  .eeprom_config(ieeprom_config),

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

assign slow_adc_sample = resp_rqst & resp_cnt;
slow_adc slow_adc_i (
  .clk(clk),
  .rst(slow_adc_rst),
  .sample(slow_adc_sample),
  .ain0(rev_pwr),
  .ain1(temperature),
  .ain2(bias_current),
  .ain3(fwd_pwr),
  .scl_i(scl3_i),
  .scl_o(scl3_o),
  .scl_t(scl3_t),
  .sda_i(sda3_i),
  .sda_o(sda3_o),
  .sda_t(sda3_t)
);

// Gererate two slow pulses for timing.  msec_pulse occurs every one millisecond.
// qmsec_pulse occurs every quarter of a millisecond
// led_saturate occurs every 64 milliseconds.
always @(posedge clk) begin
  qmillisec_count <= qmillisec_count_next;
  millisec_count <= millisec_count_next;
  led_count <= led_count_next;
end

always @* begin
  qmillisec_count_next = qmillisec_count - 10'd1;
  millisec_count_next  = millisec_count;
  led_count_next = led_count;

  qmsec_pulse = 1'b0;
  msec_pulse = 1'b0;
  led_saturate = 1'b0;

  if (qmillisec_count == 10'd0) begin
    qmillisec_count_next = 10'd625;
    qmsec_pulse = 1'b1;

    millisec_count_next = millisec_count - 2'd1;

    if (&millisec_count) begin
      msec_pulse = 1'b1;
      led_count_next = led_count + 9'h01;
      led_saturate = &led_count[5:0];
    end
  end
end


led_flash led_rxgoodlvl(.clk(clk), .cnt(led_saturate), .sig(rxgoodlvl), .led(led_d4));
led_flash led_rxclip(.clk(clk), .cnt(led_saturate), .sig(rxclip), .led(led_d5));

// For test, measure the ad9866 clock, if it is
logic [5:0] fast_clk_cnt;
always @(posedge clk_ad9866) begin
  // Count when 1x, at 76.8 MHz we should see 62 ticks when 1x is true
  if (qmillisec_count[1] & ~(&fast_clk_cnt)) fast_clk_cnt <= fast_clk_cnt + 6'h01;
  // Clear when 01 to prepare for next count
  else if (qmillisec_count[0]) fast_clk_cnt <= 6'h00;
end

logic good_fast_clk;
always @(posedge clk) begin
  // Compute when 00
  if (qmillisec_count[1:0] == 2'b00) good_fast_clk <= ~(&fast_clk_cnt);
end

// Solid when connected to software
// Blinking to indicate good ethernet clock
assign io_led_run = run ? ~run : ~(ethup & led_count[8]);

// Blinking indicates fixed ip, solid indicates dhcp
assign io_led_tx = run ? ~int_tx_on : ~((have_fixed_ip & led_count[8]) | have_dhcp_ip);

// Blinks if 100 Mbps, solid if 1Gbs, off otherwise
assign io_led_adc75 = run ? led_d4 : ~(((network_speed == 2'b01) & led_count[8]) | network_speed == 2'b10);

// Lights if ad9866 is up and the  clock is less than 80 MHz
assign io_led_adc100 = run ? led_d5 : ~(ad9866up & good_fast_clk);

// Clear status
always @(posedge clk) rxclrstatus <= ~rxclrstatus;

assign int_tx_on = (tx_on | ext_ptt ) & ~ext_txinhibit & run & temp_enabletx;

assign pwr_envbias = int_tx_on & ~vna & pa_enable;
assign pwr_envop = int_tx_on;
assign pa_exttr = int_tx_on;
assign pa_inttr = int_tx_on & ~vna & (pa_enable | ~tr_disable);
assign pwr_envpa = int_tx_on & ~vna & pa_enable;

assign rffe_rfsw_sel = ~vna & pa_enable;


// AD9866 Ctrl
ad9866ctrl #(.FAST_LNA(FAST_LNA)) ad9866ctrl_i (
  .clk(clk),
  .rst(ad9866_rst),

  .rffe_ad9866_sdio(rffe_ad9866_sdio),
  .rffe_ad9866_sclk(rffe_ad9866_sclk),
  .rffe_ad9866_sen_n(rffe_ad9866_sen_n),

  .cmd_addr(cmd_addr),
  .cmd_data(cmd_data),
  .cmd_rqst(cmd_rqst),
  .cmd_ack(cmd_ack_ad9866)
);



// Response state machine
always @ (posedge clk) begin
  resp_state <= resp_state_next;
  resp_cmd_addr <= resp_cmd_addr_next;
  resp_cmd_data <= resp_cmd_data_next;
end

// FSM Combinational
always @* begin
  // Next State
  resp_state_next = resp_state;
  resp_cmd_addr_next = resp_cmd_addr;
  resp_cmd_data_next = resp_cmd_data;

  // Combinational
  cmd_resp_rqst = 1'b0;

  case (resp_state)
    RESP_START: begin
      if (cmd_rqst & cmd_requires_resp) begin
        // Save data for response
        resp_cmd_addr_next = cmd_addr;
        resp_cmd_data_next = cmd_data;
        resp_state_next  = RESP_ACK;
      end
    end

    RESP_ACK: begin
      // Always send a response, may be error
      resp_state_next = RESP_READ;
      if (~(cmd_ack_i2c & cmd_ack_ad9866)) begin
        // Error response if subsystem was not ready
        resp_cmd_addr_next = 6'h3f;
        resp_state_next = RESP_WAIT;
      end
    end

    RESP_READ: begin
      // If there is a read, the ack will be low here until the read is ready
      if (~(cmd_ack_i2c & cmd_ack_ad9866)) begin
        if (~cmd_ack_i2c) begin
          resp_cmd_data_next = cmd_resp_data_i2c;
        end else if (~cmd_ack_ad9866) begin
          resp_cmd_data_next = cmd_resp_data_i2c; // FIXME: suppor read cmd_resp_data_ad9866
        end
      end else begin
        resp_state_next = RESP_WAIT;
      end
    end

    RESP_WAIT: begin
      cmd_resp_rqst = 1'b1;
      if (resp_rqst & ~resp_cnt) begin // Only every other resp_rqst
        if (cmd_rqst & cmd_requires_resp) begin
          // Save data for response
          resp_cmd_addr_next = cmd_addr;
          resp_cmd_data_next = cmd_data;
          resp_state_next  = RESP_ACK;
        end else begin
          resp_state_next = RESP_START;
        end
      end
    end

    default: begin
      resp_state_next = RESP_START;
    end

  endcase
end


assign ptt_resp = cw_on | ext_ptt;


// Resp request occurs relatively infrequently
// Output register iresp is updated on resp_rqst
// Output register iresp will be stable before required in any other clock domain
always @(posedge clk) begin
  if (resp_rqst) begin
    resp_cnt <= ~resp_cnt; // Count every other response
    clip_cnt  <= 2'b00;
    resp_addr <= resp_addr + 2'b01; // Slot will be skipped if command response
    if (cmd_resp_rqst & ~resp_cnt) begin // Only every other resp_rqst
      // Command response
      iresp <= {1'b1,resp_cmd_addr,ptt_resp, resp_cmd_data}; // Queue size is 1
    end else begin
      case( resp_addr)
        2'b00: iresp <= {3'b000,resp_addr, ext_cwkey, 1'b0, ptt_resp, 7'b0001111,(&clip_cnt), 8'h00, dsiq_status, VERSION_MAJOR};
        2'b01: iresp <= {3'b000,resp_addr, ext_cwkey, 1'b0, ptt_resp, 4'h0,temperature, 4'h0,fwd_pwr};
        2'b10: iresp <= {3'b000,resp_addr, ext_cwkey, 1'b0, ptt_resp, 4'h0,rev_pwr, 4'h0,bias_current};
        2'b11: iresp <= {3'b000,resp_addr, ext_cwkey, 1'b0, ptt_resp, 32'h0}; // Unused in HL
      endcase
    end
  end else if (~(&clip_cnt)) begin
    clip_cnt <= clip_cnt + {1'b0,rxclip};
  end
end

assign resp = iresp;


always @(posedge clk) begin
  if (resp_rqst & (resp_addr == 2'b01))
    dsiq_sample <= ~dsiq_sample;
end



generate case (PSSYNC)

  0: begin: NOPSSYNC
    assign pwr_clk3p3 = 1'b0;
    assign pwr_clk1p2 = 1'b0;
  end

  1: begin: PSSYNC

    logic         disable_syncfreq = 1'b0;
    logic [ 5:0]  pwrcnt = 6'h10;
    //logic [ 2:0]  pwrphase = 3'b100;

    always @(posedge clk)
      if (cmd_rqst & (cmd_addr == 6'h00))
        disable_syncfreq <= cmd_data[12];

    // sync clock
    always @(posedge clk_125) begin
      if (pwrcnt == 6'h00) begin
        //case(pwrphase)
        //  3'b000: pwrcnt <= 6'd59;
        //  3'b001: pwrcnt <= 6'd57;
        //  3'b010: pwrcnt <= 6'd58;
        //  3'b011: pwrcnt <= 6'd55;
        //  3'b100: pwrcnt <= 6'd58;
        //  3'b101: pwrcnt <= 6'd59;
        //  3'b110: pwrcnt <= 6'd56;
        //  3'b111: pwrcnt <= 6'd59;
        //endcase
        //if (pwrphase == 3'b000) pwrphase <= 3'b110;
        //else pwrphase <= pwrphase - 3'b001;
        pwrcnt <= 6'd58;
      end else begin
        pwrcnt <= pwrcnt - 6'h01;
      end

      if (disable_syncfreq) begin
        pwr_clk3p3 <= 1'b0;
        pwr_clk1p2 <= 1'b0;
      end else begin
        if (pwrcnt == 6'h00) pwr_clk3p3 <= ~pwr_clk3p3;
        if (pwrcnt == 6'h11) pwr_clk1p2 <= ~pwr_clk1p2;
      end
    end
  end
endcase
endgenerate


generate case (FAN)
  0: begin: NOFAN // No FAN

    assign fan_pwm = 1'b0;
    assign temp_enabletx = 1'b1;

  end

  1: begin: FAN

    // temperature == (((T*.01)+.5)/3.26)*4096
    localparam TEMP_20C = 12'b001101101111;
    localparam TEMP_25C = 12'b001110101110;
    localparam TEMP_30C = 12'b001111101101;
    localparam TEMP_35C = 12'b010000101011;
    localparam TEMP_40C = 12'b010001101011;
    localparam TEMP_45C = 12'b010010101010;
    localparam TEMP_50C = 12'b010011101000;
    localparam TEMP_55C = 12'b010100100111;
    localparam TEMP_60C = 12'b010101100110;

    localparam FAN_OFF          = 3'b000,
               FAN_LOWSPEED     = 3'b001,
               FAN_MEDSPEED     = 3'b011,
               FAN_FULLSPEED    = 3'b010,
               FAN_OVERHEAT     = 3'b110;

    logic [15:0] fan_cnt;
    logic [2:0] fan_state_next, fan_state = FAN_OFF;
    logic [1:0] tupvote_next, tupvote;
    logic [1:0] tdnvote_next, tdnvote;

    // Fan state machine
    always @ (posedge clk) begin
      fan_cnt <= fan_cnt + 1;
      if (slow_adc_sample) begin
        fan_state <= fan_state_next;
        tupvote <= tupvote_next;
        tdnvote <= tdnvote_next;
      end
    end

    // FSM Combinational
    always @* begin
      // Next State
      fan_state_next = fan_state;

      tupvote_next = (tupvote == 2'b00) ? tupvote : tupvote - 2'b01;
      tdnvote_next = (tdnvote == 2'b00) ? tdnvote : tdnvote - 2'b01;

      // Combo
      fan_pwm = 1'b0;
      temp_enabletx = 1'b1;

      case (fan_state)
        FAN_OFF: begin
          if (temperature > TEMP_35C) tupvote_next = tupvote + 2'b01;
          if (&tupvote) fan_state_next = FAN_LOWSPEED;
          fan_pwm = 1'b0;
        end

        FAN_LOWSPEED: begin
          if (temperature > TEMP_40C) tupvote_next = tupvote + 2'b01;
          else if (temperature < TEMP_30C) tdnvote_next = tdnvote + 2'b01;
          if (&tupvote) fan_state_next = FAN_MEDSPEED;
          else if (&tdnvote) fan_state_next = FAN_OFF;
          fan_pwm = fan_cnt[15]; // on 50% of time
        end

        FAN_MEDSPEED: begin
          if (temperature > TEMP_45C) tupvote_next = tupvote + 2'b01;
          else if (temperature < TEMP_35C) tdnvote_next = tdnvote + 2'b01;
          if (&tupvote) fan_state_next = FAN_FULLSPEED;
          else if (&tdnvote) fan_state_next = FAN_LOWSPEED;
          fan_pwm = fan_cnt[15] | fan_cnt[14]; // on 75% of time
        end

        FAN_FULLSPEED: begin
          if (temperature > TEMP_55C) tupvote_next = tupvote + 2'b01;
          else if (temperature < TEMP_40C) tdnvote_next = tdnvote + 2'b01;
          if (&tupvote) fan_state_next = FAN_OVERHEAT;
          else if (&tdnvote) fan_state_next = FAN_MEDSPEED;
          fan_pwm = 1'b1; // on 100% of time
        end

        FAN_OVERHEAT: begin
          if (temperature < TEMP_50C) tdnvote_next = tdnvote + 2'b01;
          if (&tdnvote) fan_state_next = FAN_FULLSPEED;
          fan_pwm = 1'b1;
          temp_enabletx = 1'b0;
        end
      endcase
    end
  end
endcase
endgenerate


generate
  case (UART)
    0: begin: NOUART // No UART
      assign io_uart_txd = 1'b0;
    end

    1: begin: JI1UDD_HR50 // JI1UDD HR50

      logic [31:0]  tx_freq = 32'h00000000;
      logic uart_txd;
      always @(posedge clk) begin
        if (cmd_rqst & (cmd_addr == 6'h01)) begin
          tx_freq <= cmd_data;
        end
      end

      extamp extamp_i (
        .clk(clk),
        .freq(tx_freq),
        .ptt(int_tx_on),
        .uart_txd(uart_txd)
      );
      // Invert for level shifter
      assign io_uart_txd = ~uart_txd;
    end
  endcase
endgenerate

generate
  case (ATU)
    0: begin: NOATU // No ATU
      assign io_atu_req = 1'b1;
      assign atu_txinhibit = 1'b0;
    end

    1: begin: ATU // ATU

      exttuner exttuner_i (
        .clk           (clk           ),
        .cmd_addr      (cmd_addr      ),
        .cmd_data      (cmd_data      ),
        .cmd_rqst      (cmd_rqst      ),
        .millisec_pulse(msec_pulse),
        .int_ptt       (int_tx_on         ),
        .key           (io_atu_ack    ),
        .start         (io_atu_req    ),
        .txinhibit     (atu_txinhibit )
      );
    end
  endcase
endgenerate


debounce de_phone_tip(.clean_pb(ext_cwkey), .pb(~io_phone_tip), .clk(clk), .msec_pulse(msec_pulse));
assign io_cw_keydown = cw_keydown;

debounce de_txinhibit(.clean_pb(ext_txinhibit), .pb(~io_tx_inhibit), .clk(clk), .msec_pulse(msec_pulse));

debounce de_phone_ring(.clean_pb(clean_ring), .pb(~io_phone_ring), .clk(clk), .msec_pulse(msec_pulse));

generate
  case (CW)
    0: begin: CW_NONE
      assign cw_keydown = 1'b0;

      assign ext_ptt = 1'b0;
    end

    1: begin: CW_BASIC

      assign cw_keydown = ext_cwkey;
      assign ext_ptt = clean_ring;

    end

    2: begin: CW_OPENHPSDR

      // No ext_ptt
      assign ext_ptt = 1'b0;

      cw_openhpsdr cw_openhpsdr_i (
        .clk               (clk       ),
        .clk_slow          (clk_slow  ),
        .cmd_addr          (cmd_addr  ),
        .cmd_data          (cmd_data  ),
        .cmd_rqst          (cmd_rqst  ),
        .dot_key           (ext_cwkey ),
        .dash_key          (clean_ring),
        .cw_keydown        (cw_keydown)
      );
    end

  endcase
endgenerate

endmodule
