
module mult_ABOpiped (
  input                clk,
  input  signed [17:0] a  ,
  input  signed [17:0] b  ,
  output signed [35:0] o
);

  EFX_MULT #(
    .WIDTH        (18  ),
    .A_REG        (1   ),
    .B_REG        (1   ),
    .O_REG        (1   ),
    .CLK_POLARITY (1'b1),
    .CEA_POLARITY (1'b1),
    .RSTA_POLARITY(1'b0),
    .RSTA_SYNC    (1'b0),
    .RSTA_VALUE   (1'b0),
    .CEB_POLARITY (1'b1),
    .RSTB_POLARITY(1'b0),
    .RSTB_SYNC    (1'b0),
    .RSTB_VALUE   (1'b0),
    .CEO_POLARITY (1'b1),
    .RSTO_POLARITY(1'b0),
    .RSTO_SYNC    (1'b0),
    .RSTO_VALUE   (1'b0)
  ) mult (
    .CLK (clk ),
    .CEA (1'b1),
    .RSTA(1'b1),
    .CEB (1'b1),
    .RSTB(1'b1),
    .CEO (1'b1),
    .RSTO(1'b1),
    .A   (a   ),
    .B   (b   ),
    .O   (o   )
  );

endmodule
