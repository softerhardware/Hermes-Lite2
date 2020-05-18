/*
--------------------------------------------------------------------------------
This library is free software; you can redistribute it and/or
modify it under the terms of the GNU Library General Public
License as published by the Free Software Foundation; either
version 2 of the License, or (at your option) any later version.
This library is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
Library General Public License for more details.
You should have received a copy of the GNU Library General Public
License along with this library; if not, write to the
Free Software Foundation, Inc., 51 Franklin St, Fifth Floor,
Boston, MA  02110-1301, USA.
--------------------------------------------------------------------------------
*/



module cic_s1(
  input clock,
  input in_strobe,
  input  out_strobe,
  input signed [17:0] in_data,
  output signed [19:0] out_data
);

// generated file

// CIC: INTEG_COMB N=3 R=10 M=1 Bin=18 Bout=20
// growth 10 = ceil(N=3 * log2(R=10)=3)
// Bin 18 + growth 10 = acc_max 28

wire signed [27:0] integrator0_data;
wire signed [27:0] integrator1_data;
wire signed [26:0] integrator2_data;
wire signed [24:0] integrator3_data;
wire signed [24:0] comb0_data;
wire signed [23:0] comb1_data;
wire signed [22:0] comb2_data;
wire signed [21:0] comb3_data;

// important that "in" be declared signed by wrapper code
// so this assignment will sign-extend:
assign integrator0_data = in_data;

cic_integrator #(.WIDTH(28)) cic_integrator1_inst(
  .clock(clock),
  .strobe(in_strobe),
  .in_data(integrator0_data[27 -:28]),  // trunc 0 bits
  .out_data(integrator1_data)
);

cic_integrator #(.WIDTH(27)) cic_integrator2_inst(
  .clock(clock),
  .strobe(in_strobe),
  .in_data(integrator1_data[27 -:27]),  // trunc 1 bits
  .out_data(integrator2_data)
);

cic_integrator #(.WIDTH(25)) cic_integrator3_inst(
  .clock(clock),
  .strobe(in_strobe),
  .in_data(integrator2_data[26 -:25]),  // trunc 2 bits
  .out_data(integrator3_data)
);

assign comb0_data = integrator3_data;

cic_comb #(.WIDTH(24)) cic_comb1_inst(
  .clock(clock),
  .strobe(out_strobe),
  .in_data(comb0_data[24 -:24]),  // trunc 1 bits
  .out_data(comb1_data)
);

cic_comb #(.WIDTH(23)) cic_comb2_inst(
  .clock(clock),
  .strobe(out_strobe),
  .in_data(comb1_data[23 -:23]),  // trunc 1 bits
  .out_data(comb2_data)
);

cic_comb #(.WIDTH(22)) cic_comb3_inst(
  .clock(clock),
  .strobe(out_strobe),
  .in_data(comb2_data[22 -:22]),  // trunc 1 bits
  .out_data(comb3_data)
);

assign out_data = comb3_data[21 -:20]; // trunc 2 bits

endmodule


module cic_s2(
  input clock,
  input in_strobe,
  input  out_strobe,
  input signed [19:0] in_data,
  output signed [23:0] out_data
);

// generated file

// CIC: INTEG_COMB N=5 R=20 M=1 Bin=20 Bout=24
// growth 22 = ceil(N=5 * log2(R=20)=4)
// Bin 20 + growth 22 = acc_max 42

wire signed [41:0] integrator0_data;
wire signed [41:0] integrator1_data;
wire signed [40:0] integrator2_data;
wire signed [36:0] integrator3_data;
wire signed [33:0] integrator4_data;
wire signed [30:0] integrator5_data;
wire signed [30:0] comb0_data;
wire signed [29:0] comb1_data;
wire signed [28:0] comb2_data;
wire signed [27:0] comb3_data;
wire signed [26:0] comb4_data;
wire signed [26:0] comb5_data;

// important that "in" be declared signed by wrapper code
// so this assignment will sign-extend:
assign integrator0_data = in_data;

cic_integrator #(.WIDTH(42)) cic_integrator1_inst(
  .clock(clock),
  .strobe(in_strobe),
  .in_data(integrator0_data[41 -:42]),  // trunc 0 bits
  .out_data(integrator1_data)
);

cic_integrator #(.WIDTH(41)) cic_integrator2_inst(
  .clock(clock),
  .strobe(in_strobe),
  .in_data(integrator1_data[41 -:41]),  // trunc 1 bits
  .out_data(integrator2_data)
);

cic_integrator #(.WIDTH(37)) cic_integrator3_inst(
  .clock(clock),
  .strobe(in_strobe),
  .in_data(integrator2_data[40 -:37]),  // trunc 4 bits
  .out_data(integrator3_data)
);

cic_integrator #(.WIDTH(34)) cic_integrator4_inst(
  .clock(clock),
  .strobe(in_strobe),
  .in_data(integrator3_data[36 -:34]),  // trunc 3 bits
  .out_data(integrator4_data)
);

cic_integrator #(.WIDTH(31)) cic_integrator5_inst(
  .clock(clock),
  .strobe(in_strobe),
  .in_data(integrator4_data[33 -:31]),  // trunc 3 bits
  .out_data(integrator5_data)
);

assign comb0_data = integrator5_data;

cic_comb #(.WIDTH(30)) cic_comb1_inst(
  .clock(clock),
  .strobe(out_strobe),
  .in_data(comb0_data[30 -:30]),  // trunc 1 bits
  .out_data(comb1_data)
);

cic_comb #(.WIDTH(29)) cic_comb2_inst(
  .clock(clock),
  .strobe(out_strobe),
  .in_data(comb1_data[29 -:29]),  // trunc 1 bits
  .out_data(comb2_data)
);

cic_comb #(.WIDTH(28)) cic_comb3_inst(
  .clock(clock),
  .strobe(out_strobe),
  .in_data(comb2_data[28 -:28]),  // trunc 1 bits
  .out_data(comb3_data)
);

cic_comb #(.WIDTH(27)) cic_comb4_inst(
  .clock(clock),
  .strobe(out_strobe),
  .in_data(comb3_data[27 -:27]),  // trunc 1 bits
  .out_data(comb4_data)
);

cic_comb #(.WIDTH(27)) cic_comb5_inst(
  .clock(clock),
  .strobe(out_strobe),
  .in_data(comb4_data[26 -:27]),  // trunc 0 bits
  .out_data(comb5_data)
);

assign out_data = comb5_data[26 -:24]; // trunc 3 bits

endmodule


module receiver_nco(
  input clock,                  //61.44 MHz
  input clock_2x,
  input [5:0] rate,             //48k....384k
  input signed [17:0] mixdata_I,
  input signed [17:0] mixdata_Q,
  output reg out_strobe,
  output reg signed [23:0] out_data_I,
  output reg signed [23:0] out_data_Q,
  output [33:0] debug
  );

  parameter CICRATE = 5;


// Receive CIC filters followed by FIR filter
wire signed [19:0] decimA_real, decimA_imag;
wire signed [23:0] data_I, data_Q;

reg strobe1, strobe2;

reg [3:0] cnt1;
reg [4:0] cnt2;

assign debug = 34'h0;

always @(posedge clock) begin
  if (cnt1 == 4'h9) begin
    cnt1 <= 4'h0;
    strobe1 <= 1'b1;
  end else begin
    cnt1 <= cnt1 + 4'h1;
    strobe1 <= 1'b0;
  end
end

always @(posedge clock) begin
  if (strobe1) begin
    if (cnt2 == 5'd19) begin
      cnt2 <= 5'h0;
      strobe2 <= 1'b1;
    end else begin
      cnt2 <= cnt2 + 5'h1;
      strobe2 <= 1'b0;
    end
  end else begin
    strobe2 <= 1'b0;
  end
end

// CIC filter
//I channel
cic_s1 cic_inst_I2(
    .clock(clock),
    .in_strobe(1'b1),
    .out_strobe(strobe1),
    .in_data(mixdata_I),
    .out_data(decimA_real)
);

//Q channel
cic_s1 cic_inst_Q2(
    .clock(clock),
    .in_strobe(1'b1),
    .out_strobe(strobe1),
    .in_data(mixdata_Q),
    .out_data(decimA_imag)
);


//I channel
cic_s2 varcic_inst_I1(
    .clock(clock),
    .in_strobe(strobe1),
    .out_strobe(strobe2),
    .in_data(decimA_real),
    .out_data(data_I)
    );

//Q channel
cic_s2 varcic_inst_Q1(
    .clock(clock),
    .in_strobe(strobe1),
    .out_strobe(strobe2),
    .in_data(decimA_imag),
    .out_data(data_Q)
    );

always @(posedge clock) begin
  out_strobe <= strobe2;
  if (strobe2) begin
    out_data_I <= data_I;
    out_data_Q <= data_Q;
  end
end

endmodule
