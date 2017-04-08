module test_cpl_cordic;

    reg clk;
    reg signed [31:0] phase;
    wire signed [15:0] cos;

    initial begin
        $from_myhdl(clk, phase);
        $to_myhdl(cos);
        $dumpfile("test_cpl_cordic.lxt");
        $dumpvars(0, test_cpl_cordic);
    end


cpl_cordic #(.OUT_WIDTH(16)) UUT (
    .clock(clk), 
    .frequency(phase), 
    .in_data_I(16'h4c9a),           
    .in_data_Q(16'h0000), 
    .out_data_I(cos), 
    .out_data_Q()
);

endmodule