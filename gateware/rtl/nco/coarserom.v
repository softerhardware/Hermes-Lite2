// 256 x 36 coarse sine/cosine ROM (18-bit sine in [35:18], 18-bit cosine in [17:0]).
//
// When USE_ALTSYNCRAM is defined (Quartus synthesis builds, set in the variant
// .qsf as a Verilog macro), an explicit altsyncram ROM is instantiated with an
// .mif init file. This avoids inferring a RAM with an unused write port, which
// triggers Warning (10030) "Net ... has no driver or initial value" for the
// inferred altsyncram data_a/waddr_a/we_a nets.
//
// Otherwise (simulation), the behavioral ROM with $readmemb is used.

`ifdef USE_ALTSYNCRAM

module coarserom (
  address,
  clock,
  q);

  parameter init_file = "missing_file.mif";

  input [7:0]  address;
  input        clock;
  output [35:0] q;

  wire [35:0] sub_wire0;
  wire [35:0] q = sub_wire0[35:0];

  // init_file is passed by sincos.v; default points at the .mif sibling of
  // sincos_coarse.txt. Callers using the .txt default are updated in sincos.v.
  altsyncram  altsyncram_component (
    .address_a (address),
    .clock0 (clock),
    .q_a (sub_wire0),
    .aclr0 (1'b0),
    .aclr1 (1'b0),
    .address_b (1'b1),
    .addressstall_a (1'b0),
    .addressstall_b (1'b0),
    .byteena_a (1'b1),
    .byteena_b (1'b1),
    .clock1 (1'b1),
    .clocken0 (1'b1),
    .clocken1 (1'b1),
    .clocken2 (1'b1),
    .clocken3 (1'b1),
    .data_a ({36{1'b1}}),
    .data_b (1'b1),
    .eccstatus (),
    .q_b (),
    .rden_a (1'b1),
    .rden_b (1'b1),
    .wren_a (1'b0),
    .wren_b (1'b0));
  defparam
    altsyncram_component.address_aclr_a = "NONE",
    altsyncram_component.clock_enable_input_a = "BYPASS",
    altsyncram_component.clock_enable_output_a = "BYPASS",
    altsyncram_component.init_file = init_file,
    altsyncram_component.intended_device_family = "Cyclone IV E",
    altsyncram_component.lpm_hint = "ENABLE_RUNTIME_MOD=NO",
    altsyncram_component.lpm_type = "altsyncram",
    altsyncram_component.numwords_a = 256,
    altsyncram_component.operation_mode = "ROM",
    altsyncram_component.outdata_aclr_a = "NONE",
    altsyncram_component.outdata_reg_a = "CLOCK0",
    altsyncram_component.widthad_a = 8,
    altsyncram_component.width_a = 36,
    altsyncram_component.width_byteena_a = 1;
endmodule

`else

module coarserom (
  address,
  clock,
  q);

  parameter init_file = "missing.txt";

  input [7:0]  address;
  input   clock;
  output reg [35:0]  q;

  reg [35:0] rom[255:0];

  initial
  begin
    $readmemb(init_file, rom);
  end

  always @ (posedge clock)
  begin
    q <= rom[address];
  end

endmodule

`endif
