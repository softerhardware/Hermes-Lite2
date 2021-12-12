
`timescale 1us/1ns
/* verilator lint_off WIDTH */
module mix2 (
  clk,
  clk_2x,
  rst,
  phi0,
  phi1,
  adc,
  mixdata0_i,
  mixdata0_q,
  mixdata1_i,
  mixdata1_q
);

input                 clk;
input                 clk_2x;
input                 rst;
input         [31:0]  phi0;
input         [31:0]  phi1;
input  signed [11:0]  adc;
output logic signed [17:0]  mixdata0_i;
output logic signed [17:0]  mixdata0_q;
output logic signed [17:0]  mixdata1_i;
output logic signed [17:0]  mixdata1_q;

parameter CALCTYPE = 0;
parameter ARCH = "cyclone4";

logic         [18:0]  sin, ssin;
logic         [18:0]  cos, scos;

logic  signed [17:0]  ssin_q, scos_q;
logic  signed [35:0]  i_data_d, q_data_d;
logic  signed [18:0]  i_rounded, q_rounded;

logic                 state = 1'b0;
logic                 final_sel;


nco2 #(.CALCTYPE(CALCTYPE), .ARCH(ARCH)) nco2_i (
  .state(state),
  .clk(clk),
  .clk_2x(clk_2x),
  .rst(rst),
  .phi0(phi0),
  .phi1(phi1),
  .cos(cos),
  .sin(sin)
);

always @(posedge clk_2x) begin
  state <= ~state;
end

assign ssin = {sin[18],~sin[17:0]} + 19'h01;
assign scos = {cos[18],~cos[17:0]} + 19'h01;

always @(posedge clk_2x) begin
  ssin_q <= sin[18] ? ssin[18:1] : sin[18:1];
  scos_q <= cos[18] ? scos[18:1] : cos[18:1];
end


`ifndef SIMULATION
generate if (ARCH == "cyclone4") begin: CYCLONE4

  assign final_sel = state; // Select IQ based on pipeline depth

  // Quartus can infer here, historically inference did not add pipeline of 2, but was 0
  lpm_mult #(
    .lpm_hint          ("DEDICATED_MULTIPLIER_CIRCUITRY=YES,MAXIMIZE_SPEED=5"),
    .lpm_pipeline      (2                                                    ),
    .lpm_representation("SIGNED"                                             ),
    .lpm_type          ("LPM_MULT"                                           ),
    .lpm_widtha        (18                                                   ),
    .lpm_widthb        (18                                                   ),
    .lpm_widthp        (36                                                   )
  ) imult (
    .clock (clk_2x            ),
    .dataa ({{6{adc[11]}},adc}),
    .datab (scos_q            ),
    .result(i_data_d          ),
    .aclr  (1'b0              ),
    .clken (1'b1              ),
    .sclr  (1'b0              ),
    .sum   (1'b0              )
  );

  lpm_mult #(
    .lpm_hint          ("DEDICATED_MULTIPLIER_CIRCUITRY=YES,MAXIMIZE_SPEED=5"),
    .lpm_pipeline      (2                                                    ),
    .lpm_representation("SIGNED"                                             ),
    .lpm_type          ("LPM_MULT"                                           ),
    .lpm_widtha        (18                                                   ),
    .lpm_widthb        (18                                                   ),
    .lpm_widthp        (36                                                   )
  ) qmult (
    .clock (clk_2x            ),
    .dataa ({{6{adc[11]}},adc}),
    .datab (ssin_q            ),
    .result(q_data_d          ),
    .aclr  (1'b0              ),
    .clken (1'b1              ),
    .sclr  (1'b0              ),
    .sum   (1'b0              )
  );

end else if (ARCH == "trion") begin: TRION

  assign final_sel = state; // Select IQ based on pipeline depth

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
  ) imult (
    .CLK (clk_2x            ),
    .CEA (1'b1              ),
    .RSTA(1'b1              ),
    .CEB (1'b1              ),
    .RSTB(1'b1              ),
    .CEO (1'b1              ),
    .RSTO(1'b1              ),
    .A   ({{6{adc[11]}},adc}),
    .B   (scos_q            ),
    .O   (i_data_d          )
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
  ) qmult (
    .CLK (clk_2x            ),
    .CEA (1'b1              ),
    .RSTA(1'b1              ),
    .CEB (1'b1              ),
    .RSTB(1'b1              ),
    .CEO (1'b1              ),
    .RSTO(1'b1              ),
    .A   ({{6{adc[11]}},adc}),
    .B   (ssin_q            ),
    .O   (q_data_d          )
  );


end else if (ARCH == "trion_sim") begin: TRION_SIM

  logic signed [17:0]  ssin_q1, scos_q1;
  logic signed [35:0]  i_data, q_data;
  logic signed  [11:0]  adci, adcq;

  assign final_sel = state; // Select IQ based on pipeline depth

  assign i_data = $signed(adci) * scos_q1;
  always @(posedge clk_2x) begin
    adci <= adc;
    scos_q1 <= scos_q;
    i_data_d <= i_data;
  end

  assign q_data = $signed(adcq) * ssin_q1;
  always @(posedge clk_2x) begin
    adcq <= adc;
    ssin_q1 <= ssin_q;
    q_data_d <= q_data;
  end

end else begin: GENERIC
`endif // Simulation

  logic signed  [11:0]  adci, adcq;

  assign final_sel = ~state; // Select IQ based on pipeline depth

  always @(posedge clk) begin
    adci <= adc;
    adcq <= adc;
  end

  always @(posedge clk_2x) begin
    i_data_d <= $signed(adci) * scos_q;
    q_data_d <= $signed(adcq) * ssin_q;
  end


`ifndef SIMULATION
end
endgenerate
`endif // Simulation

assign i_rounded = i_data_d[28:11] + {17'h00,i_data_d[10]};
assign q_rounded = q_data_d[28:11] + {17'h00,q_data_d[10]};

always @(posedge clk_2x) begin
  if (final_sel) begin
    mixdata0_i <= i_rounded[17:0];
    mixdata0_q <= q_rounded[17:0];
  end else begin
    mixdata1_i <= i_rounded[17:0];
    mixdata1_q <= q_rounded[17:0];
  end
end

endmodule
/* verilator lint_on WIDTH */

