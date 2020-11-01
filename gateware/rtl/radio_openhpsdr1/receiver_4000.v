
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


// Fixed decimate by 48
module cic_s1(
  input clock,
  input in_strobe,
  input  out_strobe,
  input signed [17:0] in_data,
  output signed [15:0] out_data
);

// generated file

// CIC: INTEG_COMB N=4 R=48 M=1 Bin=18 Bout=16
// growth 23 = ceil(N=4 * log2(R=48)=6)
// Bin 18 + growth 23 = acc_max 41

wire signed [40:0] integrator0_data;
wire signed [40:0] integrator1_data;
wire signed [40:0] integrator2_data;
wire signed [40:0] integrator3_data;
wire signed [22:0] integrator4_data;
wire signed [22:0] comb0_data;
wire signed [20:0] comb1_data;
wire signed [19:0] comb2_data;
wire signed [18:0] comb3_data;
wire signed [17:0] comb4_data;

// important that "in" be declared signed by wrapper code
// so this assignment will sign-extend:
assign integrator0_data = in_data;

cic_integrator #(.WIDTH(41)) cic_integrator1_inst(
  .clock(clock),
  .strobe(in_strobe),
  .in_data(integrator0_data[40 -:41]),  // trunc 0 bits
  .out_data(integrator1_data)
);

cic_integrator #(.WIDTH(41)) cic_integrator2_inst(
  .clock(clock),
  .strobe(in_strobe),
  .in_data(integrator1_data[40 -:41]),  // trunc 0 bits
  .out_data(integrator2_data)
);

cic_integrator #(.WIDTH(41)) cic_integrator3_inst(
  .clock(clock),
  .strobe(in_strobe),
  .in_data(integrator2_data[40 -:41]),  // trunc 0 bits
  .out_data(integrator3_data)
);

cic_integrator #(.WIDTH(23)) cic_integrator4_inst(
  .clock(clock),
  .strobe(in_strobe),
  .in_data(integrator3_data[40 -:23]),  // trunc 18 bits
  .out_data(integrator4_data)
);

assign comb0_data = integrator4_data;

cic_comb #(.WIDTH(21)) cic_comb1_inst(
  .clock(clock),
  .strobe(out_strobe),
  .in_data(comb0_data[22 -:21]),  // trunc 2 bits
  .out_data(comb1_data)
);

cic_comb #(.WIDTH(20)) cic_comb2_inst(
  .clock(clock),
  .strobe(out_strobe),
  .in_data(comb1_data[20 -:20]),  // trunc 1 bits
  .out_data(comb2_data)
);

cic_comb #(.WIDTH(19)) cic_comb3_inst(
  .clock(clock),
  .strobe(out_strobe),
  .in_data(comb2_data[19 -:19]),  // trunc 1 bits
  .out_data(comb3_data)
);

cic_comb #(.WIDTH(18)) cic_comb4_inst(
  .clock(clock),
  .strobe(out_strobe),
  .in_data(comb3_data[18 -:18]),  // trunc 1 bits
  .out_data(comb4_data)
);

assign out_data = comb4_data[17 -:16];  // trunc 2 bits

endmodule



module cic_s2(
  input clock,
  input in_strobe,
  input  out_strobe,
  input signed [15:0] in_data,
  output signed [16:0] out_data
);

// generated file

// CIC: INTEG_COMB N=5 R=50 M=1 Bin=16 Bout=17
// growth 29 = ceil(N=5 * log2(R=50)=6)
// Bin 16 + growth 29 = acc_max 45

wire signed [44:0] integrator0_data;
wire signed [44:0] integrator1_data;
wire signed [44:0] integrator2_data;
wire signed [44:0] integrator3_data;
wire signed [44:0] integrator4_data;
wire signed [24:0] integrator5_data;
wire signed [24:0] comb0_data;
wire signed [22:0] comb1_data;
wire signed [21:0] comb2_data;
wire signed [20:0] comb3_data;
wire signed [19:0] comb4_data;
wire signed [19:0] comb5_data;

// important that "in" be declared signed by wrapper code
// so this assignment will sign-extend:
assign integrator0_data = in_data;

cic_integrator #(.WIDTH(45)) cic_integrator1_inst(
  .clock(clock),
  .strobe(in_strobe),
  .in_data(integrator0_data[44 -:45]),  // trunc 0 bits
  .out_data(integrator1_data)
);

cic_integrator #(.WIDTH(45)) cic_integrator2_inst(
  .clock(clock),
  .strobe(in_strobe),
  .in_data(integrator1_data[44 -:45]),  // trunc 0 bits
  .out_data(integrator2_data)
);

cic_integrator #(.WIDTH(45)) cic_integrator3_inst(
  .clock(clock),
  .strobe(in_strobe),
  .in_data(integrator2_data[44 -:45]),  // trunc 0 bits
  .out_data(integrator3_data)
);

cic_integrator #(.WIDTH(45)) cic_integrator4_inst(
  .clock(clock),
  .strobe(in_strobe),
  .in_data(integrator3_data[44 -:45]),  // trunc 0 bits
  .out_data(integrator4_data)
);

cic_integrator #(.WIDTH(25)) cic_integrator5_inst(
  .clock(clock),
  .strobe(in_strobe),
  .in_data(integrator4_data[44 -:25]),  // trunc 20 bits
  .out_data(integrator5_data)
);

assign comb0_data = integrator5_data;

cic_comb #(.WIDTH(23)) cic_comb1_inst(
  .clock(clock),
  .strobe(out_strobe),
  .in_data(comb0_data[24 -:23]),  // trunc 2 bits
  .out_data(comb1_data)
);

cic_comb #(.WIDTH(22)) cic_comb2_inst(
  .clock(clock),
  .strobe(out_strobe),
  .in_data(comb1_data[22 -:22]),  // trunc 1 bits
  .out_data(comb2_data)
);

cic_comb #(.WIDTH(21)) cic_comb3_inst(
  .clock(clock),
  .strobe(out_strobe),
  .in_data(comb2_data[21 -:21]),  // trunc 1 bits
  .out_data(comb3_data)
);

cic_comb #(.WIDTH(20)) cic_comb4_inst(
  .clock(clock),
  .strobe(out_strobe),
  .in_data(comb3_data[20 -:20]),  // trunc 1 bits
  .out_data(comb4_data)
);

cic_comb #(.WIDTH(20)) cic_comb5_inst(
  .clock(clock),
  .strobe(out_strobe),
  .in_data(comb4_data[19 -:20]),  // trunc 0 bits
  .out_data(comb5_data)
);

assign out_data = comb5_data[19 -:17];  // trunc 3 bits


endmodule


module receiver_nco(
  input rst_all,
  input clock,                  //61.44 MHz
  input clock_2x,
  input [5:0] rate,             //48k....384k
  input signed [17:0] mixdata_I,
  input signed [17:0] mixdata_Q,
  output out_strobe,
  output reg [23:0] out_data_I,
  output reg [23:0] out_data_Q,
  output [33:0] debug
  );

parameter CICRATE = 5;

parameter REGISTER_OUTPUT = 0;
  
// Receive CIC filters followed by FIR filter
wire signed [15:0] decimA_real, decimA_imag;
wire signed [16:0] decimB_real, decimB_imag;

reg strobe1, strobe2;

reg [5:0] cnt1;
reg [5:0] cnt2;

assign debug = 34'h0;

always @(posedge clock) begin
  if (rst_all | cnt1 == 6'd47) begin
    cnt1 <= 6'h0;
    strobe1 <= 1'b1;
  end else begin
    cnt1 <= cnt1 + 6'h1;
    strobe1 <= 1'b0;
  end
end

always @(posedge clock) begin
  if (rst_all) begin
    cnt2 <= 6'h0;
    strobe2 <= 1'b0;
  end else if (strobe1) begin
    if (cnt2 == 6'd49) begin
      cnt2 <= 6'h0;
      strobe2 <= 1'b1;
    end else begin
      cnt2 <= cnt2 + 6'h1;
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
    .out_data(decimB_real)
    );

//Q channel
cic_s2 varcic_inst_Q1(
    .clock(clock),
    .in_strobe(strobe1),
    .out_strobe(strobe2),
    .in_data(decimA_imag),
    .out_data(decimB_imag)
    );


firX8R8 fir2 (
  .rst_all(rst_all),
  .clock(clock),
  .clock_2x(clock_2x),
  .x_avail(strobe2),
  .x_real({decimB_real[16],decimB_real}),
  .x_imag({decimB_imag[16],decimB_imag}),
  .y_avail(out_strobe),
  .y_real(out_data_I),
  .y_imag(out_data_Q)
  );


endmodule
