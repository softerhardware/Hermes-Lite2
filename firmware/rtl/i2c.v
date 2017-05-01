`timescale 1ns / 1ps

module i2c #
(
    parameter WB_DATA_WIDTH = 32,
    parameter WB_ADDR_WIDTH = 6
)
(
    input  logic         clk,
    input  logic         clock_76p8_mhz,
    input  logic         rst,
    input  logic         init_start,

    // Wishbone slave interface
    input  logic [WB_ADDR_WIDTH-1:0]   wbs_adr_i,
    input  logic [WB_DATA_WIDTH-1:0]   wbs_dat_i,
    input  logic                       wbs_we_i,
    input  logic                       wbs_stb_i,
    output logic                       wbs_ack_o,   
    input  logic                       wbs_cyc_i,  

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


logic [6:0]  i2c2_cmd_address;
logic        i2c2_cmd_start, i2c2_cmd_read, i2c2_cmd_write, i2c2_cmd_write_multiple, i2c2_cmd_stop, i2c2_cmd_valid, i2c2_cmd_ready;
logic [7:0]  i2c2_data;
logic        i2c2_data_valid, i2c2_data_ready, i2c2_data_last;

logic        i2c2_busy;

// Wishbone slave
logic wbs_ack = 0;
always @(posedge clk) begin
  if (rst | wbs_ack) 
    wbs_ack <= 1'b0;
  else if (~i2c2_busy & wbs_we_i & wbs_stb_i & (wbs_adr_i == 6'h3d) & (wbs_dat_i[31:24] == 8'h06))
    wbs_ack <= 1'b1;
end
assign wbs_ack_o = wbs_ack;

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
    .clk(clock_76p8_mhz),
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
    .busy(i2c2_busy),
    /*
     * Configuration
     */
    .write(i2c2_write_en),
    .data(wbs_dat_i)
);

i2c_master i2c2_master_i (
    .clk(clock_76p8_mhz),
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
    .prescale(16'h0030),
    .stop_on_idle(1'b0)
);

endmodule