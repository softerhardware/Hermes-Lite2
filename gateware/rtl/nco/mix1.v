
`timescale 1us/1ns
/* verilator lint_off WIDTH */
module mix1 (
  clk,
  rst,
  phi,
  adc,
  i_data,
  q_data
);

input                 clk;
input                 rst;
input         [31:0]  phi;
input  signed [11:0]  adc;
output signed [17:0]  i_data;
output signed [17:0]  q_data;

parameter CALCTYPE = 3;

logic         [18:0]  sin, ssin;
logic         [18:0]  cos, scos;

logic  signed [17:0]  ssin_q, scos_q;
logic  signed [35:0]  i_data_d, q_data_d;

nco1 #(.CALCTYPE(CALCTYPE)) nco1_i (
  .clk(clk),
  .rst(rst),
  .phi(phi),
  .cos(cos),
  .sin(sin)
);

assign ssin = {sin[18],~sin[17:0]} + 19'h01;
assign scos = {cos[18],~cos[17:0]} + 19'h01;

always @(posedge clk) begin
  ssin_q <= sin[18] ? ssin[18:1] : sin[18:1];
  scos_q <= cos[18] ? scos[18:1] : cos[18:1];
end

mult_ABOpiped imult (
  .clk(clk_2x),
  .a({{6{adc[11]}},adc}),
  .b(scos_q),
  .o(i_data_d)
);

mult_ABOpiped qmult (
  .clk(clk_2x),
  .a({{6{adc[11]}},adc}),
  .b(ssin_q),
  .o(q_data_d)
);

assign i_data = i_data_d[28:11] + {17'h00,i_data_d[10]};
assign q_data = q_data_d[28:11] + {17'h00,q_data_d[10]};

endmodule
/* verilator lint_on WIDTH */

