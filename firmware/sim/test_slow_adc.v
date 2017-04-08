
// Language: Verilog 2001

`timescale 1ns / 1ps

/*
 * Testbench for i2c_master
 */
module test_slow_adc;

// Parameters

// Inputs
reg clk = 0;
reg rst = 0;
reg [7:0] current_test = 0;
reg scl_i = 1;
reg sda_i = 1;

// Outputs
wire [11:0] ain0, ain1, ain2, ain3;
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
        sda_i
    );
    $to_myhdl(
        ain0,
        ain1,
        ain2,
        ain3,
        scl_o,
        scl_t,
        sda_o,
        sda_t
    );

    // dump file
    $dumpfile("test_slow_adc.lxt");
    $dumpvars(0, test_slow_adc);
end

slow_adc UUT (
    .clk(clk),
    .rst(rst),
    .ain0(ain0),
    .ain1(ain1),
    .ain2(ain2),
    .ain3(ain3),
    .scl_i(scl_i),
    .scl_o(scl_o),
    .scl_t(scl_t),
    .sda_i(sda_i),
    .sda_o(sda_o),
    .sda_t(sda_t)
);

endmodule
