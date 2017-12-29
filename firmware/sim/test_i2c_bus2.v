
`timescale 1ns / 1ps

/*
 * Testbench for i2c_master
 */
module test_i2c_bus2;

// Parameters

// Inputs
reg clk = 0;
reg rst = 0;
reg scl_i = 1;
reg sda_i = 1;

reg [5:0]  wbs_adr_i;
reg [31:0] wbs_dat_i;
reg wbs_we_i;
reg wbs_stb_i; 
reg wbs_cyc_i;  


// Outputs
wire wbs_ack_o;
wire scl_o;
wire scl_t;
wire sda_o;
wire sda_t;


initial begin
    // myhdl integration
    $from_myhdl(
        clk,
        rst,
        scl_i,
        sda_i,
        wbs_adr_i,
        wbs_dat_i,
        wbs_we_i,
        wbs_stb_i,
        wbs_cyc_i
    );
    $to_myhdl(
        wbs_ack_o,
        scl_o,
        scl_t,
        sda_o,
        sda_t
    );

    // dump file
    $dumpfile("test_i2c_bus2.lxt");
    $dumpvars(0, test_i2c_bus2);
end

i2c_bus2 UUT (
    .clk(clk),
    .rst(rst),
    .wbs_adr_i(wbs_adr_i),
    .wbs_dat_i(wbs_dat_i),
    .wbs_we_i(wbs_we_i),
    .wbs_stb_i(wbs_stb_i),
    .wbs_ack_o(wbs_ack_o),
    .wbs_cyc_i(wbs_cyc_i),
    .scl_i(scl_i),
    .scl_o(scl_o),
    .scl_t(scl_t),
    .sda_i(sda_i),
    .sda_o(sda_o),
    .sda_t(sda_t)
);

endmodule
