`timescale 1ns / 1ps

module i2c (
    input  logic         clk,
    input  logic         rst,
    input  logic         init_start,

    // Command slave interface
    input  logic [5:0]   cmd_addr,
    input  logic [31:0]  cmd_data,
    input  logic         cmd_rqst,
    output logic         cmd_ack,   

    /*
     * I2C interface
     */
    input  logic         scl1_i,
    output logic         scl1_o,
    output logic         scl1_t,
    input  logic         sda1_i,
    output logic         sda1_o,
    output logic         sda1_t,    

    input  logic         scl2_i,
    output logic         scl2_o,
    output logic         scl2_t,
    input  logic         sda2_i,
    output logic         sda2_o,
    output logic         sda2_t
);

// I2C for Versa Clock
logic [6:0]  i2c1_cmd_address;
logic        i2c1_cmd_start, i2c1_cmd_read, i2c1_cmd_write, i2c1_cmd_write_multiple, i2c1_cmd_stop, i2c1_cmd_valid, i2c1_cmd_ready;
logic [7:0]  i2c1_data;
logic        i2c1_data_valid, i2c1_data_ready, i2c1_data_last;


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

i2c_bus2 i2c_bus2_i (
  .clk(clk),
  .rst(rst),

  .cmd_addr(cmd_addr),
  .cmd_data(cmd_data),
  .cmd_rqst(cmd_rqst),
  .cmd_ack(cmd_ack),   

  .scl_i(scl2_i),
  .scl_o(scl2_o),
  .scl_t(scl2_t),
  .sda_i(sda2_i),
  .sda_o(sda2_o),
  .sda_t(sda2_t)
);

endmodule