

module cw_openhpsdr (
  input               clk               ,
  input               clk_slow          ,
  input        [ 5:0] cmd_addr          ,
  input        [31:0] cmd_data          ,
  input               cmd_rqst          ,
  input               dot_key           ,
  input               dash_key          ,
  output              cw_ptt            ,
  output              cw_keydown
);

logic       keyer_reverse; // reverse CW keyes if set
logic [5:0] keyer_speed  ; // CW keyer speed 0-60 WPM
logic [1:0] keyer_mode   ; // 00 = straight/external/bug, 01 = Mode A, 10 = Mode B
logic [7:0] keyer_weight ; // keyer weight 33-66
logic       keyer_spacing; // 0 = off, 1 = on
logic       keyer_cw_ptt ;
logic       keyer_out    ;
logic [7:0] cw_ptt_delay ; // key-down delay 0-255 ms
logic [9:0] cw_hang_time ; // break-in delay
logic [2:0] mode_b_mem_timing = 3'b0 ; // dot memory inhibit period 0-7, re-use EER PWM min

// Toggles in clk whenever any keyer parameter bus changes, so the clk_slow
// domain can capture all buses atomically via sync_qualifier below.  For
// speed/weight changes a second toggle fires once the delay recompute has
// completed (see divider block).
reg cfg_toggle = 1'b0;

always @(posedge clk) begin
  if (cmd_rqst) begin
    if ((cmd_addr == 6'h0f) | (cmd_addr == 6'h10) | (cmd_addr == 6'h11))
      cfg_toggle <= ~cfg_toggle;

    if (cmd_addr == 6'h0b) begin
      keyer_reverse <= cmd_data[22];
      keyer_speed <= cmd_data[13:8];
      keyer_mode <= cmd_data[15:14];
      keyer_weight <= cmd_data[6:0];
      keyer_spacing <= cmd_data[7];
    end else if (cmd_addr == 6'h0f) begin
      cw_ptt_delay <= cmd_data[15:8];
    end else if (cmd_addr == 6'h10) begin
      cw_hang_time <= {cmd_data[31:24], cmd_data[17:16]};
    end else if (cmd_addr == 6'h11) begin
      mode_b_mem_timing <= {~cmd_data[24], cmd_data[17:16]}; // 3'b100(100d) -> 3'b000
    end
  end
end


reg [15:0] dot_delay;
reg [17:0] dash_delay;
reg [29:0] acc = 30'b0;
reg  [5:0] cnt =  6'b0;
wire [5:0] div = ( cnt > 6'd24 )? 6'd50 : keyer_speed ; // 6'd50: weight 50%
wire [6:0] sub = acc[29:23] - {1'b0, div};

always @(posedge clk) begin
  if (cmd_rqst) begin
    if (cmd_addr == 6'h0b) begin
      cnt <= 6'd0;
      acc <= {14'b0, 16'd57600};    // 16'd57600: 1200 * clock speed 48
    end

  end else if (cnt == 6'd24) begin
    cnt <= cnt + 1'b1;
    dot_delay <= acc[15:0];
    acc[29:0] <= {15'b0, acc[15:0]} * 3 * keyer_weight;

  end else if (cnt >= 6'd49) begin
    dash_delay <= acc[17:0];

  end else begin
    cnt <= cnt + 1'b1;
    acc <= sub[6]? {acc[28:0], 1'b0} : {sub[5:0], acc[22:0], 1'b1}; 
  end
end

// Toggle once when a speed/weight recompute completes (divider parks at
// cnt==49 with dot/dash finalized) so the clk_slow captures settle values.
reg parked = 1'b1;  // divider idle/parked tracker

always @(posedge clk) begin
  if (cmd_rqst & (cmd_addr == 6'h0b))
    parked <= 1'b0;
  else if (~parked & (cnt == 6'd49)) begin
    parked     <= 1'b1;
    cfg_toggle <= ~cfg_toggle;
  end
end


// Qualified copies of the parameter buses in the clk_slow domain: captured
// atomically when cfg_toggle arrives through the synchronizers, eliminating
// torn multi-bit samples while the operator changes keyer settings.
wire [15:0] dot_delay_slow       ;
wire [17:0] dash_delay_slow      ;
wire [ 1:0] iambic_mode_slow     ;
wire        letter_space_slow    ;
wire        paddle_swap_slow     ;
wire [ 7:0] cw_ptt_delay_slow    ;
wire [ 9:0] cw_hang_time_slow    ;
wire [ 2:0] mode_b_mem_timing_slow;

sync_qualifier #(.WIDTH(16)) qual_dot_delay
  (.clock(clk_slow), .data_in(dot_delay),        .data_valid(cfg_toggle), .data_valid_sync(), .data_out(dot_delay_slow));
sync_qualifier #(.WIDTH(18)) qual_dash_delay
  (.clock(clk_slow), .data_in(dash_delay),       .data_valid(cfg_toggle), .data_valid_sync(), .data_out(dash_delay_slow));
sync_qualifier #(.WIDTH(2))  qual_iambic_mode
  (.clock(clk_slow), .data_in(keyer_mode),       .data_valid(cfg_toggle), .data_valid_sync(), .data_out(iambic_mode_slow));
sync_qualifier #(.WIDTH(1))  qual_letter_space
  (.clock(clk_slow), .data_in(keyer_spacing),    .data_valid(cfg_toggle), .data_valid_sync(), .data_out(letter_space_slow));
sync_qualifier #(.WIDTH(1))  qual_paddle_swap
  (.clock(clk_slow), .data_in(keyer_reverse),    .data_valid(cfg_toggle), .data_valid_sync(), .data_out(paddle_swap_slow));
sync_qualifier #(.WIDTH(8))  qual_cw_ptt_delay
  (.clock(clk_slow), .data_in(cw_ptt_delay),     .data_valid(cfg_toggle), .data_valid_sync(), .data_out(cw_ptt_delay_slow));
sync_qualifier #(.WIDTH(10)) qual_cw_hang_time
  (.clock(clk_slow), .data_in(cw_hang_time),     .data_valid(cfg_toggle), .data_valid_sync(), .data_out(cw_hang_time_slow));
sync_qualifier #(.WIDTH(3))  qual_mode_b_timing
  (.clock(clk_slow), .data_in(mode_b_mem_timing),.data_valid(cfg_toggle), .data_valid_sync(), .data_out(mode_b_mem_timing_slow));

iambic #(48) iambic_i (
  .clock       (clk_slow     ),
//.cw_speed    (keyer_speed  ),
  .dot_delay   (dot_delay_slow    ),
  .dash_delay  (dash_delay_slow   ),
  .iambic_mode (iambic_mode_slow  ),
//.weight      (keyer_weight ),
  .letter_space(letter_space_slow ),
  .dot_key     (dot_key      ),
  .dash_key    (dash_key     ),
  .paddle_swap (paddle_swap_slow  ),
  .cw_ptt_delay(cw_ptt_delay_slow ),
  .cw_hang_time(cw_hang_time_slow ),
  .mode_b_mem_timing(mode_b_mem_timing_slow),
  .cw_ptt      (keyer_cw_ptt ),
  .keyer_out   (keyer_out    )
);

sync sync_cw_ptt (
  .clock(clk), 
  .sig_in(keyer_cw_ptt),
  .sig_out(cw_ptt)
);

sync sync_cw_keydown (
  .clock(clk),
  .sig_in(keyer_out),
  .sig_out(cw_keydown)
);
      
endmodule