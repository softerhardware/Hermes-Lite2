

module mult_ABOpiped (
  input                  clk,
  input  signed [17:0] a  ,
  input  signed [17:0] b  ,
  output signed [35:0] o
);

  lpm_mult #(
    .lpm_hint          ("DEDICATED_MULTIPLIER_CIRCUITRY=YES,MAXIMIZE_SPEED=5"),
    .lpm_pipeline      (2                                                    ),
    .lpm_representation("SIGNED"                                             ),
    .lpm_type          ("LPM_MULT"                                           ),
    .lpm_widtha        (18                                                   ),
    .lpm_widthb        (18                                                   ),
    .lpm_widthp        (36                                                   )
  ) sinmult (
    .clock (clk ),
    .dataa (a   ),
    .datab (b   ),
    .result(o   ),
    .aclr  (1'b0),
    .clken (1'b1),
    .sclr  (1'b0),
    .sum   (1'b0)
  );

endmodule


module umult_ABOpiped (
  input                  clk,
  input  unsigned [17:0] a  ,
  input  unsigned [17:0] b  ,
  output unsigned [35:0] o
);

  lpm_mult #(
    .lpm_hint          ("DEDICATED_MULTIPLIER_CIRCUITRY=YES,MAXIMIZE_SPEED=5"),
    .lpm_pipeline      (2                                                    ),
    .lpm_representation("UNSIGNED"                                           ),
    .lpm_type          ("LPM_MULT"                                           ),
    .lpm_widtha        (18                                                   ),
    .lpm_widthb        (18                                                   ),
    .lpm_widthp        (36                                                   )
  ) sinmult (
    .clock (clk ),
    .dataa (a   ),
    .datab (b   ),
    .result(o   ),
    .aclr  (1'b0),
    .clken (1'b1),
    .sclr  (1'b0),
    .sum   (1'b0)
  );

endmodule
