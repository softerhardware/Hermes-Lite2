module FIFO (rst, clk, full, usedw, empty, wrreq, data, rdreq, q);

parameter SZ = 2048;
parameter WD = 16;

localparam DP= clogb2(SZ-1);

input  wire          rst;
input  wire          clk;
output wire          full;
output reg  [DP-1:0] usedw;
output wire          empty;
input  wire          wrreq;
input  wire [WD-1:0] data;
input  wire          rdreq;
output reg  [WD-1:0] q;

reg [WD-1:0] mem [0:SZ-1];
reg [DP-1:0] inptr, outptr;

assign full = (usedw == {DP{1'b1}});
assign empty = (usedw == 1'b0);

always @(posedge clk)
begin
  if (rst)
    inptr <= 1'b0;
  else if (wrreq)
    inptr <= inptr + 1'b1;

  if (rst)
    outptr <= 1'b0;
  else if (rdreq)
    outptr <= outptr + 1'b1;

  if (rst)
    usedw <= 1'b0;
  else if (rdreq & !wrreq)
    usedw <= usedw - 1'b1;
  else if (wrreq & !rdreq)
    usedw <= usedw + 1'b1;

  if (wrreq)
    mem[inptr] <= data;

  if (rdreq)
    q <= mem[outptr];
end

function integer clogb2;
input [31:0] depth;
begin
  for(clogb2=0; depth>0; clogb2=clogb2+1)
  depth = depth >> 1;
end
endfunction

endmodule