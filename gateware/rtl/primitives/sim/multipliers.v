

module mult_ABOpiped (
  input                  clk,
  input  signed [17:0] a  ,
  input  signed [17:0] b  ,
  output signed [35:0] o
);

  // Use reg, wire and format below for generic multiplier inference rules
  reg  signed [17:0] ra, rb;
  reg  signed [35:0] ro;
  wire signed [35:0] m ;

  assign m = ra * rb;
  always @(posedge clk) begin
    ra <= a;
    rb <= b;
    ro <= m;
  end

  assign o = ro;

endmodule


module umult_ABOpiped (
  input                  clk,
  input  unsigned [17:0] a  ,
  input  unsigned [17:0] b  ,
  output unsigned [35:0] o
);

  // Use reg, wire and format below for generic multiplier inference rules
  reg  unsigned [17:0] ra, rb;
  reg  unsigned [35:0] ro;
  wire unsigned [35:0] m ;

  assign m = ra * rb;
  always @(posedge clk) begin
    ra <= a;
    rb <= b;
    ro <= m;
  end

  assign o = ro;

endmodule
