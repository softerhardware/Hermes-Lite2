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
    output [31:0]        cmd_resp_data,

    output logic [31:0]  static_ip,
    output logic [15:0]  alt_mac,
    output logic [ 7:0]  eeprom_config,

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

logic         scl_i, scl_o, scl_t, sda_i, sda_o, sda_t;
logic         en_i2c2, ready;

localparam [3:0]
  STATE_W0    = 4'h0,
  STATE_W1    = 4'h1,
  STATE_W2    = 4'h2,
  STATE_W3    = 4'h3,
  STATE_W4    = 4'h4,
  STATE_W5    = 4'h5,
  STATE_W6    = 4'h6,
  STATE_WWAIT = 4'h7,
  STATE_R0    = 4'h8,
  STATE_R1    = 4'h9,
  STATE_R2    = 4'ha,
  STATE_R3    = 4'hb,
  STATE_R4    = 4'hc,
  STATE_R5    = 4'hd,
  STATE_R6    = 4'he,
  STATE_PASS  = 4'hf;


logic [ 3:0]  state = STATE_W0, state_next;

logic [ 5:0]  icmd_addr;
logic [31:0]  icmd_data;
logic         icmd_rqst;
logic         read_done;

logic [31:0]  static_ip_next;
logic [15:0]  alt_mac_next;
logic [7:0]   eeprom_config_next;

always @(posedge clk) begin
  state <= state_next;
  static_ip <= static_ip_next;
  alt_mac <= alt_mac_next;
  eeprom_config <= eeprom_config_next;
end

always @* begin
  state_next = state;
  static_ip_next = static_ip;
  alt_mac_next = alt_mac;
  eeprom_config_next = eeprom_config;

  icmd_addr = cmd_addr;
  icmd_data = cmd_data;
  icmd_rqst = cmd_rqst;

  case(state)
    STATE_W0: begin
      icmd_addr = 6'h3c;
      icmd_data = {8'h06, 1'b1, 7'h6a, 8'h17, 8'h04};
      icmd_rqst = 1'b0;
      if (init_start & ready) begin
          icmd_rqst = 1'b1;
          state_next = STATE_W1;
      end
    end

    STATE_W1: begin
      icmd_addr = 6'h3c;
      icmd_data = {8'h06, 1'b1, 7'h6a, 8'h18, 8'h40};
      icmd_rqst = 1'b0;
      if (init_start & ready) begin
          icmd_rqst = 1'b1;
          state_next = STATE_W2;
      end
    end

    STATE_W2: begin
      icmd_addr = 6'h3c;
      icmd_data = {8'h06, 1'b1, 7'h6a, 8'h1e, 8'he8};
      icmd_rqst = 1'b0;
      if (init_start & ready) begin
          icmd_rqst = 1'b1;
          state_next = STATE_W3;
      end
    end

    STATE_W3: begin
      icmd_addr = 6'h3c;
      icmd_data = {8'h06, 1'b1, 7'h6a, 8'h1f, 8'h80};
      icmd_rqst = 1'b0;
      if (init_start & ready) begin
          icmd_rqst = 1'b1;
          state_next = STATE_W4;
      end
    end

    STATE_W4: begin
      icmd_addr = 6'h3c;
      icmd_data = {8'h06, 1'b1, 7'h6a, 8'h2d, 8'h01};
      icmd_rqst = 1'b0;
      if (init_start & ready) begin
          icmd_rqst = 1'b1;
          state_next = STATE_W5;
      end
    end

    STATE_W5: begin
      icmd_addr = 6'h3c;
      icmd_data = {8'h06, 1'b1, 7'h6a, 8'h2e, 8'h10};
      icmd_rqst = 1'b0;
      if (init_start & ready) begin
          icmd_rqst = 1'b1;
          state_next = STATE_W6;
      end
    end

    STATE_W6: begin
      icmd_addr = 6'h3c;
      icmd_data = {8'h06, 1'b1, 7'h6a, 8'h60, 8'h3b};
      icmd_rqst = 1'b0;
      if (init_start & ready) begin
          icmd_rqst = 1'b1;
          state_next = STATE_WWAIT;
      end
    end

    // Wait state is need to switch between i2c controllers
    STATE_WWAIT: begin
      icmd_addr = 6'h3c;
      icmd_data = {8'h06, 1'b1, 7'h6a, 8'h60, 8'h3b};
      icmd_rqst = 1'b0;
      if (init_start & ready) begin
          state_next = STATE_R0;
      end
    end

    STATE_R0: begin
      icmd_addr = 6'h3d;
      icmd_data = {8'h07, 8'hac, 8'h8c, 8'hxx};
      icmd_rqst = init_start & ready;
      if (read_done) begin
        static_ip_next = {cmd_resp_data[15:8],static_ip[23:0]};
        state_next = STATE_R1;
      end
    end

    STATE_R1: begin
      icmd_addr = 6'h3d;
      icmd_data = {8'h07, 8'hac, 8'h9c, 8'hxx};
      icmd_rqst = init_start & ready;
      if (read_done) begin
        static_ip_next = {static_ip[31:24],cmd_resp_data[15:8],static_ip[15:0]};
        state_next = STATE_R2;
      end
    end

    STATE_R2: begin
      icmd_addr = 6'h3d;
      icmd_data = {8'h07, 8'hac, 8'hac, 8'hxx};
      icmd_rqst = init_start & ready;
      if (read_done) begin
        static_ip_next = {static_ip[31:16],cmd_resp_data[15:8],static_ip[7:0]};
        state_next = STATE_R3;
      end
    end

    STATE_R3: begin
      icmd_addr = 6'h3d;
      icmd_data = {8'h07, 8'hac, 8'hbc, 8'hxx};
      icmd_rqst = init_start & ready;
      if (read_done) begin
        static_ip_next = {static_ip[31:8],cmd_resp_data[15:8]};
        state_next = STATE_R4;
      end
    end

    STATE_R4: begin
      icmd_addr = 6'h3d;
      icmd_data = {8'h07, 8'hac, 8'hcc, 8'hxx};
      icmd_rqst = init_start & ready;
      if (read_done) begin
        alt_mac_next = {cmd_resp_data[15:8],alt_mac[7:0]};
        state_next = STATE_R5;
      end
    end

    STATE_R5: begin
      icmd_addr = 6'h3d;
      icmd_data = {8'h07, 8'hac, 8'hdc, 8'hxx};
      icmd_rqst = init_start & ready;
      if (read_done) begin
        alt_mac_next = {alt_mac[15:8],cmd_resp_data[15:8]};
        state_next = STATE_R6;
      end
    end

    STATE_R6: begin
      icmd_addr = 6'h3d;
      icmd_data = {8'h07, 8'hac, 8'h6c, 8'hxx};
      icmd_rqst = init_start & ready;
      if (read_done) begin
        eeprom_config_next = cmd_resp_data[15:8];
        state_next = STATE_PASS;
      end
    end

    STATE_PASS: begin
      if (~init_start) state_next = STATE_W0;
    end

  endcase
end

i2c_bus2 i2c_bus2_i (
  .clk(clk),
  .rst(rst),

  .cmd_addr(icmd_addr),
  .cmd_data(icmd_data),
  .cmd_rqst(icmd_rqst),
  .cmd_ack(cmd_ack),
  .cmd_resp_data(cmd_resp_data),

  .read_done(read_done),
  .en_i2c2(en_i2c2),
  .ready(ready),

  .scl_i(scl_i),
  .scl_o(scl_o),
  .scl_t(scl_t),
  .sda_i(sda_i),
  .sda_o(sda_o),
  .sda_t(sda_t)
);

assign scl_i = en_i2c2 ? scl2_i : scl1_i;
assign sda_i = en_i2c2 ? sda2_i : sda1_i;

assign scl1_o = scl_o;
assign scl2_o = scl_o;

assign scl1_t = en_i2c2 ? 1'b1 : scl_t;
assign scl2_t = en_i2c2 ? scl_t : 1'b1;

assign sda1_t = en_i2c2 ? 1'b1 : sda_t;
assign sda2_t = en_i2c2 ? sda_t : 1'b1;

endmodule