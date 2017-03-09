


module i2c(
    input  wire         clk,
    input  wire         rst,
    input  wire         init_start,

    // Bus interface
    input  wire [5:0]   addr,
    input  wire [31:0]  data,
    input  wire         write,

    /*
     * I2C interface
     */
    input  wire         scl1_i,
    output wire         scl1_o,
    output wire         scl1_t,
    input  wire         sda1_i,
    output wire         sda1_o,
    output wire         sda1_t,    

    input  wire         scl2_i,
    output wire         scl2_o,
    output wire         scl2_t,
    input  wire         sda2_i,
    output wire         sda2_o,
    output wire         sda2_t
);

// I2C for Versa Clock
wire [6:0]  i2c1_cmd_address;
wire        i2c1_cmd_start, i2c1_cmd_read, i2c1_cmd_write, i2c1_cmd_write_multiple, i2c1_cmd_stop, i2c1_cmd_valid, i2c1_cmd_ready;
wire [7:0]  i2c1_data;
wire        i2c1_data_valid, i2c1_data_ready, i2c1_data_last;


wire [6:0]  i2c2_cmd_address;
wire        i2c2_cmd_start, i2c2_cmd_read, i2c2_cmd_write, i2c2_cmd_write_multiple, i2c2_cmd_stop, i2c2_cmd_valid, i2c2_cmd_ready;
wire [7:0]  i2c2_data;
wire        i2c2_data_valid, i2c2_data_ready, i2c2_data_last;


wire i2c2_write_en = write & (addr == 6'h3d) & (data[31:24] == 8'h06);


i2c_init i2c1_init_i (
    .clk(clk),
    .rst(rst),
    /*
     * I2C master interface
     */
    .cmd_address(i2c1_cmd_address),
    .cmd_start(i2c1_cmd_start),
    .cmd_read(i2c1_cmd_read),
    .cmd_write(i2c1_cmd_write),
    .cmd_write_multiple(i2c1_cmd_write_multiple),
    .cmd_stop(i2c1_cmd_stop),
    .cmd_valid(i2c1_cmd_valid),
    .cmd_ready(i2c1_cmd_ready),

    .data_out(i2c1_data),
    .data_out_valid(i2c1_data_valid),
    .data_out_ready(i2c1_data_ready),
    .data_out_last(i2c1_data_last),
    /*
     * Status
     */
    .busy(),
    /*
     * Configuration
     */
    .start(init_start)
);

i2c_master i2c1_master_i (
    .clk(clk),
    .rst(rst),
    /*
     * Host interface
     */
    .cmd_address(i2c1_cmd_address),
    .cmd_start(i2c1_cmd_start),
    .cmd_read(i2c1_cmd_read),
    .cmd_write(i2c1_cmd_write),
    .cmd_write_multiple(i2c1_cmd_write_multiple),
    .cmd_stop(i2c1_cmd_stop),
    .cmd_valid(i2c1_cmd_valid),
    .cmd_ready(i2c1_cmd_ready),

    .data_in(i2c1_data),
    .data_in_valid(i2c1_data_valid),
    .data_in_ready(i2c1_data_ready),
    .data_in_last(i2c1_data_last),

    .data_out(),
    .data_out_valid(),
    .data_out_ready(1'b1),
    .data_out_last(),

    /*
     * I2C interface
     */
    .scl_i(scl1_i),
    .scl_o(scl1_o),
    .scl_t(scl1_t),
    .sda_i(sda1_i),
    .sda_o(sda1_o),
    .sda_t(sda1_t),

    /*
     * Status
     */
    .busy(),
    .bus_control(),
    .bus_active(),
    .missed_ack(),

    /*
     * Configuration
     */
    .prescale(16'h0002),
    .stop_on_idle(1'b0)
);




i2c2_init i2c2_init_i (
    .clk(clk),
    .rst(rst),
    /*
     * I2C master interface
     */
    .cmd_address(i2c2_cmd_address),
    .cmd_start(i2c2_cmd_start),
    .cmd_read(i2c2_cmd_read),
    .cmd_write(i2c2_cmd_write),
    .cmd_write_multiple(i2c2_cmd_write_multiple),
    .cmd_stop(i2c2_cmd_stop),
    .cmd_valid(i2c2_cmd_valid),
    .cmd_ready(i2c2_cmd_ready),

    .data_out(i2c2_data),
    .data_out_valid(i2c2_data_valid),
    .data_out_ready(i2c2_data_ready),
    .data_out_last(i2c2_data_last),
    /*
     * Status
     */
    .busy(),
    /*
     * Configuration
     */
    .write(i2c2_write_en),
    .data(data)
);

i2c_master i2c2_master_i (
    .clk(clk),
    .rst(rst),
    /*
     * Host interface
     */
    .cmd_address(i2c2_cmd_address),
    .cmd_start(i2c2_cmd_start),
    .cmd_read(i2c2_cmd_read),
    .cmd_write(i2c2_cmd_write),
    .cmd_write_multiple(i2c2_cmd_write_multiple),
    .cmd_stop(i2c2_cmd_stop),
    .cmd_valid(i2c2_cmd_valid),
    .cmd_ready(i2c2_cmd_ready),

    .data_in(i2c2_data),
    .data_in_valid(i2c2_data_valid),
    .data_in_ready(i2c2_data_ready),
    .data_in_last(i2c2_data_last),

    .data_out(),
    .data_out_valid(),
    .data_out_ready(1'b1),
    .data_out_last(),

    /*
     * I2C interface
     */
    .scl_i(scl2_i),
    .scl_o(scl2_o),
    .scl_t(scl2_t),
    .sda_i(sda2_i),
    .sda_o(sda2_o),
    .sda_t(sda2_t),

    /*
     * Status
     */
    .busy(),
    .bus_control(),
    .bus_active(),
    .missed_ack(),

    /*
     * Configuration
     */
    .prescale(16'h0002),
    .stop_on_idle(1'b0)
);

endmodule