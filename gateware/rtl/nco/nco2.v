
`timescale 1us/1ns

module nco2 (
  state,
  clk_2x,
  clk,
  rst,
  phi0,
  phi1,
  cos,
  sin
);

input             state;
input             clk_2x;
input             clk;
input             rst;
input     [31:0]  phi0;
input     [31:0]  phi1;
output    [18:0]  sin;
output    [18:0]  cos;

logic [31:0]      angle0 = 32'h00;
logic [31:0]      angle1 = 32'h00;

parameter         CALCTYPE = 0;

always @(posedge clk_2x) begin
  if (state) begin
    angle1 <= angle0 + phi1;
    angle0 <= rst ? 32'h00 : angle1;
  end else begin
    angle1 <= angle0 + phi0;
    angle0 <= rst ? 32'h00 : angle1;
  end
end

sincos #(.CALCTYPE(CALCTYPE)) sincos_i (
  .clk(clk_2x),
  .angle(angle1[31:12]),
  .cos(cos),
  .sin(sin)
);

endmodule


