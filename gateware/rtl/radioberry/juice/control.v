module control(
	input 			clk,				//10 MHz
	input 			clk_ctrl,			//2.5 MHz
	input 			clk_slow,
	
	input 			reset,
	
	input           rxclip,
	input           rxgoodlvl,
	output logic    rxclrstatus = 1'b0,
	
	input 			run,
	
	input  [7:0] 	dsiq_status,
	output logic    dsiq_sample = 1'b0,
	
	input  [5:0]    cmd_addr,
	input  [31:0]   cmd_data,
	input           cmd_rqst,
	
	input           cmd_requires_resp,
	
	input           tx_on,
	input           cw_on,
	output          cw_keydown,

	input           io_phone_tip,
	input           io_phone_ring,

	output logic    msec_pulse = 1'b0,
	output logic    qmsec_pulse = 1'b0,
 
	input           resp_rqst,
	output [39:0] 	resp,
	
	output          pa_inttr,
	output          pa_exttr,
	
	output          fan_pwm, 
	
	output          pwr_envpa,
	output          pwr_envbias,
	
	output          rffe_ad9866_rst_n,
	output          rffe_ad9866_sdio,
	output          rffe_ad9866_sclk,
	output          rffe_ad9866_sen_n,

	input         	scl_i,
	output       	scl_o,
	output       	scl_t,
	input        	sda_i,
	output        	sda_o,
	output        	sda_t
  );

parameter     CW = 0;
parameter     VERSION_MAJOR = 8'h0;
parameter     FAN = 0;

logic         	pa_enable = 1'b0;
logic         	tr_disable = 1'b0;

logic [11:0]   	qmillisec_count, qmillisec_count_next;
logic [1:0]   	millisec_count, millisec_count_next;
logic         	ext_cwkey, ext_ptt;
logic 			int_tx_on;
logic         	temp_enabletx = 1'b1;
logic 			ext_pttqst;

logic  			resp_cnt = 1'b0;
logic [1:0]  	clip_cnt = 2'b00;

localparam RESP_START    = 2'b00,
           RESP_ACK      = 2'b01,
           RESP_READ     = 2'b11,
           RESP_WAIT     = 2'b10;

logic [1:0]   	resp_state = RESP_START, resp_state_next;


logic         	cmd_ack_i2c, cmd_ack_ad9866;
logic [31:0]  	cmd_resp_data_i2c;

logic [39:0]  	iresp = {8'h00, 8'b00011110, 8'h00, 8'h00, VERSION_MAJOR};
logic [ 1:0]  	resp_addr = 2'b00;

logic        	cmd_resp_rqst;

logic         	cmd_ack;
logic [ 5:0]  	resp_cmd_addr = 6'h00, resp_cmd_addr_next;
logic [31:0]  	resp_cmd_data = 32'h00, resp_cmd_data_next;

logic 			slow_adc_sample;
logic [11:0]  	fwd_pwr;
logic [11:0]  	rev_pwr;
logic [11:0]  	bias_current;
logic [11:0]  	temperature;

assign int_tx_on = (tx_on | ext_ptt ) & run;
assign pa_inttr = int_tx_on & (pa_enable | ~tr_disable);
assign pa_exttr = int_tx_on;
assign pwr_envpa = int_tx_on & pa_enable & temp_enabletx;
assign pwr_envbias = int_tx_on & pa_enable & temp_enabletx;


logic [19:0]  adccount = 20'h0000;
always @ (posedge clk_ctrl) begin
	if (~(|adccount)) slow_adc_sample <= 0; 
	adccount <= adccount + 20'h01;
	if (adccount > 'd250000 & ready)  begin slow_adc_sample <= 1; adccount <= 20'h0;  end
end

i2c_bus i2c_bus_i (
  .clk(clk_ctrl),
  .rst(reset),
  
  //slow adc
  .sample(slow_adc_sample),
  
  .ain0(rev_pwr),
  .ain1(temperature),
  .ain2(bias_current),
  .ain3(fwd_pwr),

  .cmd_addr(cmd_addr),
  .cmd_data(cmd_data),
  .cmd_rqst(cmd_rqst),
  .cmd_ack(cmd_ack_i2c),
  .cmd_resp_data(cmd_resp_data_i2c),
  
  .read_done(),
  .ready(ready),

  .scl_i(scl_i),
  .scl_o(scl_o),
  .scl_t(scl_t),
  .sda_i(sda_i),
  .sda_o(sda_o),
  .sda_t(sda_t)
);

// Clear status
always @(posedge clk_ctrl) rxclrstatus <= ~rxclrstatus;

always @(posedge clk_ctrl) begin
  if (cmd_rqst) begin
    if (cmd_addr == 6'h09) begin
      pa_enable    <= cmd_data[19];
      tr_disable   <= cmd_data[18];
    end
  end
end


//  Main Response state machine
always @ (posedge clk_ctrl) begin
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
always @(posedge clk_ctrl) begin
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
        2'b11: iresp <= {3'b000,resp_addr, ext_cwkey, 1'b0, ptt_resp, 16'h0, 16'h0}; // Unused in HL
      endcase
    end
  end else if (~(&clip_cnt)) begin
    clip_cnt <= clip_cnt + {1'b0,rxclip};
  end
end

assign resp = iresp;


always @(posedge clk_ctrl) begin
  if (resp_rqst & (resp_addr == 2'b01))
    dsiq_sample <= ~dsiq_sample;
end


assign rffe_ad9866_rst_n = ~reset;

ad9866ctrl ad9866ctrl_i (
  .clk(clk_ctrl),
  .rst(reset),

  .rffe_ad9866_sdio(rffe_ad9866_sdio),
  .rffe_ad9866_sclk(rffe_ad9866_sclk),
  .rffe_ad9866_sen_n(rffe_ad9866_sen_n),

  .cmd_addr(cmd_addr),
  .cmd_data(cmd_data),
  .cmd_rqst(cmd_rqst),
  .cmd_ack(cmd_ack_ad9866)
);

// Gererate two slow pulses for timing.  msec_pulse occurs every one millisecond.
// qmsec_pulse occurs every quarter of a millisecond
// led_saturate occurs every 64 milliseconds.
always @(posedge clk) begin
  qmillisec_count <= qmillisec_count_next;
  millisec_count <= millisec_count_next;
end

always @* begin
  qmillisec_count_next = qmillisec_count - 10'd1;
  millisec_count_next  = millisec_count;

  qmsec_pulse = 1'b0;
  msec_pulse = 1'b0;
  
  if (qmillisec_count == 12'd0) begin
    qmillisec_count_next = 12'd2500;
    qmsec_pulse = 1'b1;
    millisec_count_next = millisec_count - 2'd1;
    if (&millisec_count) msec_pulse = 1'b1;
  end
end


debounce de_phone_tip(.clean_pb(ext_cwkey), .pb(~io_phone_tip), .clk(clk), .msec_pulse(msec_pulse));
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


generate case (FAN)
  0: begin: NOFAN // No FAN or Band Volts
  
    assign fan_pwm = 1'b0;
    assign temp_enabletx = 1'b1;

  end

  1: begin: FAN

    // temperature == (((T*.01)+.5)/3.26)*4096
    localparam TEMP_20C = 12'b001101101111;
    localparam TEMP_25C = 12'b001110101110;
    localparam TEMP_30C = 12'b001111101101;
    localparam TEMP_35C = 12'b010000101011;
    localparam TEMP_37C = 12'b010001001011;
    localparam TEMP_40C = 12'b010001101011;
    localparam TEMP_42C = 12'b010010001010;
    localparam TEMP_45C = 12'b010010101010;
    localparam TEMP_47C = 12'b010011001001;
    localparam TEMP_50C = 12'b010011101000;
    localparam TEMP_52C = 12'b010100000111;
    localparam TEMP_55C = 12'b010100100111;
    localparam TEMP_60C = 12'b010101100110;

    localparam FAN_OFF          = 3'b000,
               FAN_LOWSPEED     = 3'b001,
               FAN_MEDSPEED     = 3'b011,
               FAN_FULLSPEED    = 3'b010,
               FAN_OVERHEAT     = 3'b110;
					
    logic band_volts_enabled = 1'b0;					

    logic fan_output = 1'b0;
    logic [15:0] fan_cnt;
    logic [2:0] fan_state_next, fan_state = FAN_OFF;
    logic [1:0] tupvote_next, tupvote;
    logic [1:0] tdnvote_next, tdnvote;
	 
	 always @(posedge clk_ctrl)
      if (cmd_rqst & (cmd_addr == 6'h00))
        band_volts_enabled <= cmd_data[11];

    // Fan state machine
    always @ (posedge clk_ctrl) begin
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

      if (band_volts_enabled == 0) begin 
        // Combo
        fan_output = 1'b0;
        temp_enabletx = 1'b1;

        case (fan_state)
          FAN_OFF: begin
            if (temperature > TEMP_37C) tupvote_next = tupvote + 2'b01;
            if (&tupvote) fan_state_next = FAN_LOWSPEED;
            fan_output = 1'b0;
          end

          FAN_LOWSPEED: begin
            if (temperature > TEMP_40C) tupvote_next = tupvote + 2'b01;
            else if (temperature < TEMP_35C) tdnvote_next = tdnvote + 2'b01;
            if (&tupvote) fan_state_next = FAN_MEDSPEED;
            else if (&tdnvote) fan_state_next = FAN_OFF;
            fan_output = fan_cnt[15]; // on 50% of time
          end

          FAN_MEDSPEED: begin
            if (temperature > TEMP_45C) tupvote_next = tupvote + 2'b01;
            else if (temperature < TEMP_37C) tdnvote_next = tdnvote + 2'b01;
            if (&tupvote) fan_state_next = FAN_FULLSPEED;
            else if (&tdnvote) fan_state_next = FAN_LOWSPEED;
            fan_output = fan_cnt[15] | fan_cnt[14]; // on 75% of time
          end

          FAN_FULLSPEED: begin
            if (temperature > TEMP_55C) tupvote_next = tupvote + 2'b01;
            else if (temperature < TEMP_40C) tdnvote_next = tdnvote + 2'b01;
            if (&tupvote) fan_state_next = FAN_OVERHEAT;
            else if (&tdnvote) fan_state_next = FAN_MEDSPEED;
            fan_output = 1'b1; // on 100% of time
          end

          FAN_OVERHEAT: begin
            if (temperature < TEMP_50C) tdnvote_next = tdnvote + 2'b01;
            if (&tdnvote) fan_state_next = FAN_FULLSPEED;
            fan_output = 1'b1;
            temp_enabletx = 1'b0;
          end
        endcase
      end
    end
    
    //MI0BOT: Addition of Band Volts using Fan PWM output. Selection via "Dither" bit
 
    // Enough freq resolution to define bands
    localparam FREQ_2MHZ  = 10'h001f;	//  2.03162 MHz
    localparam FREQ_4MHZ  = 10'h003e;	//  4.06323 MHz
    localparam FREQ_6MHZ  = 10'h005c;	//  6.02931 MHz
    localparam FREQ_8MHZ  = 10'h007a;	//  7.99539 MHz
    localparam FREQ_12MHZ = 10'h00b7;	// 11.9931  MHz
    localparam FREQ_16MHZ = 10'h00f4;	// 15.9908  MHz
    localparam FREQ_20MHZ = 10'h0131;	// 19.9885  MHz
    localparam FREQ_23MHZ = 10'h015e;	// 22.9376  MHZ
    localparam FREQ_25MHZ = 10'h017e;	// 25.0348  MHz
	
	  localparam DAC_VOLT   = 3300;		// Power voltage in mV
	  localparam DAC_BITS   = 12;
   
    localparam VOLT_160M  = ( 230*(2**DAC_BITS))/DAC_VOLT;	// Band voltage required in mV
    localparam VOLT_80M   = ( 460*(2**DAC_BITS))/DAC_VOLT;
    localparam VOLT_60M   = ( 690*(2**DAC_BITS))/DAC_VOLT;
    localparam VOLT_40M   = ( 920*(2**DAC_BITS))/DAC_VOLT;
    localparam VOLT_30M   = (1150*(2**DAC_BITS))/DAC_VOLT;
    localparam VOLT_20M   = (1380*(2**DAC_BITS))/DAC_VOLT;
    localparam VOLT_17M   = (1610*(2**DAC_BITS))/DAC_VOLT;
    localparam VOLT_15M   = (1840*(2**DAC_BITS))/DAC_VOLT;
    localparam VOLT_12M   = (2070*(2**DAC_BITS))/DAC_VOLT;
    localparam VOLT_10M   = (2300*(2**DAC_BITS))/DAC_VOLT;
    
    logic band_volts_output = 1'b0;
   				
    logic [(DAC_BITS-1):0] volt_cnt;
    logic [(DAC_BITS-1):0] volt_mark;
    logic [31:0] freq = 32'h00000000;
   
    always @(posedge clk_ctrl) begin
   	if (cmd_rqst & (cmd_addr == 6'h01)) begin
   	  freq <= cmd_data;
   	  end
    end
   
      // PWM counter
    always @ (posedge clk_ctrl) begin
      if (band_volts_enabled == 1) begin 
        volt_cnt <= volt_cnt + 1'b1;
        band_volts_output = (volt_mark > volt_cnt);	
      end
    end
    
 
    // Frequency checking
    always @* begin
      if      (freq[25:16] >= FREQ_25MHZ) volt_mark = VOLT_10M;
      else if (freq[25:16] >= FREQ_23MHZ) volt_mark = VOLT_12M;
      else if (freq[25:16] >= FREQ_20MHZ) volt_mark = VOLT_15M;
      else if (freq[25:16] >= FREQ_16MHZ) volt_mark = VOLT_17M;
      else if (freq[25:16] >= FREQ_12MHZ) volt_mark = VOLT_20M;
      else if (freq[25:16] >= FREQ_8MHZ) volt_mark = VOLT_30M;
      else if (freq[25:16] >= FREQ_6MHZ) volt_mark = VOLT_40M;
      else if (freq[25:16] >= FREQ_4MHZ) volt_mark = VOLT_60M;
      else if (freq[25:16] >= FREQ_2MHZ) volt_mark = VOLT_80M;
      else volt_mark = VOLT_160M;
      
      if (band_volts_enabled == 1)  
        fan_pwm = band_volts_output;
      else
        fan_pwm = fan_output;
    end
  end
endcase
endgenerate

endmodule
