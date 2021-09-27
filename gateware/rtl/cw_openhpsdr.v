

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
    end
  end
end

iambic #(48) iambic_i (
  .clock       (clk_slow     ),
  .cw_speed    (keyer_speed  ),
  .iambic_mode (keyer_mode   ),
  .weight      (keyer_weight ),
  .letter_space(keyer_spacing),
  .dot_key     (dot_key      ),
  .dash_key    (dash_key     ),
  .paddle_swap (keyer_reverse),
  .cw_ptt_delay(cw_ptt_delay ),
  .cw_hang_time(cw_hang_time ),
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