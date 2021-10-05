

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


always @(posedge clk) begin
  if (cmd_rqst) begin
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


iambic #(48) iambic_i (
  .clock       (clk_slow     ),
//.cw_speed    (keyer_speed  ),
  .dot_delay   (dot_delay    ),
  .dash_delay  (dash_delay   ),
  .iambic_mode (keyer_mode   ),
//.weight      (keyer_weight ),
  .letter_space(keyer_spacing),
  .dot_key     (dot_key      ),
  .dash_key    (dash_key     ),
  .paddle_swap (keyer_reverse),
  .cw_ptt_delay(cw_ptt_delay ),
  .cw_hang_time(cw_hang_time ),
  .mode_b_mem_timing(mode_b_mem_timing),
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