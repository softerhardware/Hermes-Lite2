`timescale 1ns / 1ps

module i2c (
    input  logic         clk,
    input  logic         rst,
    input  logic         init_start,
    input  logic         lost_clock,

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

// Sparse state encoding
// Bits [4:0] are 32 states for a particular target
// Bits [7:5] are one hot for target
// Bit [5] is Versa target
// Bit [6] is EEPROM
// Bit [7] is AK4951
// Bits [7:5] = 3'b000 is passthrough from PC

localparam [7:0]
  STATE_CLINIT0      = {3'b001,5'b00000},
  STATE_CLINIT1      = {3'b001,5'b00001},
  STATE_CLINIT2      = {3'b001,5'b00010},
  STATE_CLINIT3      = {3'b001,5'b00011},
  STATE_CLINIT4      = {3'b001,5'b00100},
  STATE_CLINIT5      = {3'b001,5'b00101},
  STATE_CLINIT6      = {3'b001,5'b00111},
  STATE_CL2ON0       = {3'b001,5'b01000},
  STATE_CL2ON1       = {3'b001,5'b01001},
  STATE_CL2ON2       = {3'b001,5'b01010},
  STATE_CL2ON3       = {3'b001,5'b01011},
  STATE_CL2ON4       = {3'b001,5'b01100},
  STATE_CL2ON5       = {3'b001,5'b01101},
  STATE_CL2ON6       = {3'b001,5'b01110},
  STATE_CL2ON7       = {3'b001,5'b01111},
  STATE_CL2ON8       = {3'b001,5'b10000},
  STATE_CL2OFF0      = {3'b001,5'b10001},
  STATE_CL2OFF1      = {3'b001,5'b10010},
  STATE_CL1ON0       = {3'b001,5'b10011},
  STATE_CL1ON1       = {3'b001,5'b10100},
  STATE_CL1ON2       = {3'b001,5'b10101},
  STATE_CL1ON3       = {3'b001,5'b10110},
  STATE_CL1ON4       = {3'b001,5'b10111},
  STATE_CL1ON5       = {3'b001,5'b11000},
  STATE_CL1OFF0      = {3'b001,5'b11001},
  STATE_CL1OFF1      = {3'b001,5'b11010},
  STATE_CL1OFF2      = {3'b001,5'b11011},
  STATE_CL1OFF3      = {3'b001,5'b11100},
  STATE_CL1OFF4      = {3'b001,5'b11101},
  STATE_CL1OFF5      = {3'b001,5'b11110};

localparam [7:0]
  STATE_EEPROM0      = {3'b001,5'b11111}, // Keep address 6'h3c
  STATE_EEPROM1      = {3'b010,5'b00001},
  STATE_EEPROM2      = {3'b010,5'b00010},
  STATE_EEPROM3      = {3'b010,5'b00100},
  STATE_EEPROM4      = {3'b010,5'b01000},
  STATE_EEPROM5      = {3'b010,5'b10000},
  STATE_EEPROM6      = {3'b010,5'b10001},
  STATE_EEPROM7      = {3'b010,5'b00110};

localparam [7:0]
  STATE_AK4951S0     = {3'b100,5'b00001},
  STATE_AK4951S1     = {3'b100,5'b00010},
  STATE_AK4951S2     = {3'b100,5'b00100},
  STATE_AK4951S3     = {3'b100,5'b01000},
  STATE_AK4951S4     = {3'b100,5'b10000},
  STATE_AK4951S5     = {3'b100,5'b10001},
  STATE_AK4951S6     = {3'b100,5'b01010},
  STATE_AK4951S7     = {3'b100,5'b00110},
  STATE_AK4951S8     = {3'b100,5'b00111};

localparam [7:0]
  STATE_IDLE         = {3'b000,5'b00000};



logic [ 7:0]  state = STATE_CLINIT0, state_next;

logic [ 5:0]  icmd_addr;
logic [15:0]  icmd_data_upper;
logic [15:0]  icmd_reg_val;
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

  // Setup common data for various targets
  if (state[5]) begin
    // Versa target
    icmd_addr       = 6'h3c;
    icmd_data_upper = {8'h06, 1'b1, 7'h6a};
    icmd_rqst       = 1'b0;

  end else if (state[6]) begin
    // EEPROM target
    icmd_addr       = 6'h3d;
    icmd_data_upper = {8'h07, 8'hac};
    icmd_rqst       = ready;

`ifdef AK4951
  end else if (state[7]) begin
    // AD4951 Target
    icmd_addr       = 6'h3c;
    icmd_data_upper = {8'h06, 1'b1, 7'h12};
    icmd_rqst       = 1'b0;
`endif

  end else begin
    icmd_addr       = cmd_addr;
    icmd_data_upper = cmd_data[31:16];
    icmd_rqst       = cmd_rqst;
  end
  icmd_reg_val = cmd_data[15:0];



  case(state)

    // Sequences called while running
    STATE_IDLE: begin
      if (~init_start) state_next = STATE_CLINIT0;
      else if (lost_clock) state_next = STATE_CL1OFF0;
      else if (cmd_rqst) begin
        case (cmd_addr)
          6'h39: begin
            case (cmd_data[3:0])
              4'h8: state_next = STATE_CL2ON6;
              4'ha: state_next = STATE_CL2OFF0;
              4'hb: state_next = STATE_CL2ON0;
              4'hc: state_next = STATE_CL1OFF0;
              4'hd: state_next = STATE_CL1ON0;
              default: state_next = STATE_IDLE;
            endcase
          end

          default: state_next = STATE_IDLE;
        endcase
      end
    end

    ///////////////////////////////////////
    // Versa Clock States

    // Start of init sequence
    STATE_CLINIT0: begin
      icmd_reg_val = {8'h17, 8'h04}; // Divider to 0x0440
      if (init_start & ready) begin
          icmd_rqst = 1'b1;
          state_next = STATE_CLINIT1;
      end
    end

    STATE_CLINIT1: begin
      icmd_reg_val = {8'h18, 8'h40};
      if (ready) begin
          icmd_rqst = 1'b1;
          state_next = STATE_CLINIT2;
      end
    end

    STATE_CLINIT2: begin
      icmd_reg_val = {8'h1e, 8'he8}; // RC control register from Versa tool
      if (ready) begin
          icmd_rqst = 1'b1;
          state_next = STATE_CLINIT3;
      end
    end

    STATE_CLINIT3: begin
      icmd_reg_val = {8'h1f, 8'h80}; // RC control register from Versa tool
      if (ready) begin
          icmd_rqst = 1'b1;
          state_next = STATE_CLINIT4;
      end
    end

    STATE_CLINIT4: begin
      icmd_reg_val = {8'h2d, 8'h01}; // Output 1 divider
      if (ready) begin
          icmd_rqst = 1'b1;
          state_next = STATE_CLINIT5;
      end
    end

    STATE_CLINIT5: begin
      icmd_reg_val = {8'h2e, 8'h10}; // Output 1 divider
      if (ready) begin
          icmd_rqst = 1'b1;
          state_next = STATE_CLINIT6;
      end
    end

    STATE_CLINIT6: begin
      icmd_reg_val = {8'h60, 8'h3b}; // Enable output 1
      if (ready) begin
          icmd_rqst = 1'b1;
`ifndef AK4951
          state_next = STATE_EEPROM0;
`else
          state_next = STATE_AK4951S0;
`endif
      end
    end

    STATE_CL2ON0: begin
      icmd_reg_val = {8'h62, 8'h3b}; // Clock2 CMOS1 output and 3.3V
      if (ready) begin
          icmd_rqst = 1'b1;
          state_next = STATE_CL2ON1;
      end
    end

    STATE_CL2ON1: begin
      icmd_reg_val = {8'h3d, 8'h01}; // Set divide by 0x0110
      if (ready) begin
          icmd_rqst = 1'b1;
          state_next = STATE_CL2ON2;
      end
    end

    STATE_CL2ON2: begin
      icmd_reg_val = {8'h3e, 8'h10}; // Set divide by 0x0110
      if (ready) begin
          icmd_rqst = 1'b1;
          state_next = STATE_CL2ON3;
      end
    end

    STATE_CL2ON3: begin
      icmd_reg_val = {8'h31, 8'h81}; // Enable divider output for clock2
      if (ready) begin
          icmd_rqst = 1'b1;
          state_next = STATE_CL2ON4;
      end
    end

    STATE_CL2ON4: begin
      icmd_reg_val = {8'h3f, 8'h1f}; // Fractional portion of skew
      if (ready) begin
          icmd_rqst = 1'b1;
          state_next = STATE_CL2ON5;
      end
    end

    STATE_CL2ON5: begin
      icmd_reg_val = {8'h63, 8'h01}; // Enable clock2 output
      if (ready) begin
          icmd_rqst = 1'b1;
          state_next = STATE_CL2ON6;
      end
    end

    STATE_CL2ON6: begin
      icmd_reg_val = {8'h76, 8'h43}; // Enable reset to sync
      if (ready) begin
          icmd_rqst = 1'b1;
          state_next = STATE_CL2ON7;
      end
    end

    STATE_CL2ON7: begin
      icmd_reg_val = {8'h76, 8'h63}; // Disable reset
      if (ready) begin
          icmd_rqst = 1'b1;
          state_next = STATE_IDLE;
      end
    end

    STATE_CL2OFF0: begin
      icmd_reg_val = {8'h31, 8'h80}; // Disable divider output for clock2
      if (ready) begin
          icmd_rqst = 1'b1;
          state_next = STATE_CL2OFF1;
      end
    end

    STATE_CL2OFF1: begin
      icmd_reg_val = {8'h63, 8'h00}; // Disable clock2 output
      if (ready) begin
          icmd_rqst = 1'b1;
          state_next = STATE_IDLE;
      end
    end

    STATE_CL1ON0: begin
      icmd_reg_val = {8'h17, 8'h02}; // Change top multiplier to 0x22
      if (ready) begin
          icmd_rqst = 1'b1;
          state_next = STATE_CL1ON1;
      end
    end

    STATE_CL1ON1: begin
      icmd_reg_val = {8'h18, 8'h20}; // Change top multiplier to 0x22
      if (ready) begin
          icmd_rqst = 1'b1;
          state_next = STATE_CL1ON2;
      end
    end

    STATE_CL1ON2: begin
      icmd_reg_val = {8'h10, 8'hc0}; // Enable xtal and clock
      if (ready) begin
          icmd_rqst = 1'b1;
          state_next = STATE_CL1ON3;
      end
    end

    STATE_CL1ON3: begin
      icmd_reg_val = {8'h13, 8'h03}; // Switch to clock
      if (ready) begin
          icmd_rqst = 1'b1;
          state_next = STATE_CL1ON4;
      end
    end

    STATE_CL1ON4: begin
      icmd_reg_val = {8'h10, 8'h44}; // Enable clock input only, and refmode
      if (ready) begin
          icmd_rqst = 1'b1;
          state_next = STATE_CL1ON5;
      end
    end

    STATE_CL1ON5: begin
      icmd_reg_val = {8'h21, 8'h0c}; // Use previous channel, direct input, may have skew
      if (ready) begin
          icmd_rqst = 1'b1;
          state_next = STATE_IDLE;
      end
    end

    STATE_CL1OFF0: begin
      icmd_reg_val = {8'h10, 8'hc4}; // Enable xtal and clock
      if (ready) begin
          icmd_rqst = 1'b1;
          state_next = STATE_CL1OFF1;
      end
    end

    STATE_CL1OFF1: begin
      icmd_reg_val = {8'h21, 8'h81}; // Use and enable divider
      if (ready) begin
          icmd_rqst = 1'b1;
          state_next = STATE_CL1OFF2;
      end
    end

    STATE_CL1OFF2: begin
      icmd_reg_val = {8'h13, 8'h00}; // Use CL1 input instead of xtal
      if (ready) begin
          icmd_rqst = 1'b1;
          state_next = STATE_CL1OFF3;
      end
    end

    STATE_CL1OFF3: begin
      icmd_reg_val = {8'h10, 8'h80}; // Enable xtal input only
      if (ready) begin
          icmd_rqst = 1'b1;
          state_next = STATE_CL1OFF4;
      end
    end

    STATE_CL1OFF4: begin
      icmd_reg_val = {8'h17, 8'h04}; // Change top multiplier
      if (ready) begin
          icmd_rqst = 1'b1;
          state_next = STATE_CL1OFF5;
      end
    end

    STATE_CL1OFF5: begin
      icmd_reg_val = {8'h18, 8'h40};
      if (ready) begin
          icmd_rqst = 1'b1;
          state_next = STATE_IDLE;
      end
    end

//////////////////////////////
// AK4951 Init sequence
`ifdef AK4951
    STATE_AK4951S0: begin
      icmd_reg_val = {8'hxx, 8'hxx}; // Wait
      if (ready) begin
        state_next = STATE_AK4951S1;
      end
    end

    STATE_AK4951S1: begin
      icmd_reg_val = {8'h00, 8'h00};
      if (ready) begin
          icmd_rqst = 1'b1;
          state_next = STATE_AK4951S2;
      end
    end

    STATE_AK4951S2: begin
      icmd_reg_val = {8'h05, 8'h33};
      if (ready) begin
          icmd_rqst = 1'b1;
          state_next = STATE_AK4951S3;
      end
    end

    STATE_AK4951S3: begin
      icmd_reg_val = {8'h0d, 8'h91}; // IVL 0dB
      if (ready) begin
          icmd_rqst = 1'b1;
          state_next = STATE_AK4951S4;
      end
    end

    STATE_AK4951S4: begin
      icmd_reg_val = {8'h00, 8'hc5};
      if (ready) begin
          icmd_rqst = 1'b1;
          state_next = STATE_AK4951S5;
      end
    end

    STATE_AK4951S5: begin
      icmd_reg_val = {8'h01, 8'hb6};
      if (ready) begin
          icmd_rqst = 1'b1;
          state_next = STATE_AK4951S6;
      end
    end

    STATE_AK4951S6: begin
//    icmd_reg_val = {8'h04, 8'h47}; // monoral
      icmd_reg_val = {8'h04, 8'h44}; // stereo
      if (ready) begin
          icmd_rqst = 1'b1;
          state_next = STATE_AK4951S7;
      end
    end

    STATE_AK4951S7: begin
      icmd_reg_val = {8'h03, 8'h00};
      if (ready) begin
          icmd_rqst = 1'b1;
          state_next = STATE_AK4951S8;
      end
    end

    STATE_AK4951S8: begin
      icmd_reg_val = {8'h02, 8'hae};
      if (ready) begin
          icmd_rqst = 1'b1;
          state_next = STATE_EEPROM0;
      end
    end
`endif

//////////////////////////////
// EEPROM read sequence

    // Wait state is need to switch between i2c controllers
    STATE_EEPROM0: begin
      icmd_reg_val = {8'hxx, 8'hxx};
      if (ready) begin
        state_next = STATE_EEPROM1;
      end
    end


    STATE_EEPROM1: begin
      icmd_reg_val = {8'h8c, 8'hxx};
      if (read_done) begin
        static_ip_next = {cmd_resp_data[15:8],static_ip[23:0]};
        state_next = STATE_EEPROM2;
      end
    end

    STATE_EEPROM2: begin
      icmd_reg_val = {8'h9c, 8'hxx};
      if (read_done) begin
        static_ip_next = {static_ip[31:24],cmd_resp_data[15:8],static_ip[15:0]};
        state_next = STATE_EEPROM3;
      end
    end

    STATE_EEPROM3: begin
      icmd_reg_val = {8'hac, 8'hxx};
      if (read_done) begin
        static_ip_next = {static_ip[31:16],cmd_resp_data[15:8],static_ip[7:0]};
        state_next = STATE_EEPROM4;
      end
    end

    STATE_EEPROM4: begin
      icmd_reg_val = {8'hbc, 8'hxx};
      if (read_done) begin
        static_ip_next = {static_ip[31:8],cmd_resp_data[15:8]};
        state_next = STATE_EEPROM5;
      end
    end

    STATE_EEPROM5: begin
      icmd_reg_val = {8'hcc, 8'hxx};
      if (read_done) begin
        alt_mac_next = {cmd_resp_data[15:8],alt_mac[7:0]};
        state_next = STATE_EEPROM6;
      end
    end

    STATE_EEPROM6: begin
      icmd_reg_val = {8'hdc, 8'hxx};
      if (read_done) begin
        alt_mac_next = {alt_mac[15:8],cmd_resp_data[15:8]};
        state_next = STATE_EEPROM7;
      end
    end

    STATE_EEPROM7: begin
      icmd_reg_val = {8'h6c, 8'hxx};
      if (read_done) begin
        eeprom_config_next = cmd_resp_data[15:8];
        state_next = STATE_IDLE;
      end
    end

    default: begin
      state_next = STATE_IDLE;
      icmd_addr       = 6'hxx;
      icmd_data_upper = 16'hxxxx;
      icmd_rqst       = 1'bx;
      icmd_reg_val    = 16'hxxxx;
    end

  endcase
end

i2c_bus2 i2c_bus2_i (
  .clk(clk),
  .rst(rst),

  .cmd_addr(icmd_addr),
  .cmd_data({icmd_data_upper,icmd_reg_val}),
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

assign sda1_o = sda_o;
assign sda2_o = sda_o;

assign scl1_t = en_i2c2 ? 1'b1 : scl_t;
assign scl2_t = en_i2c2 ? scl_t : 1'b1;

assign sda1_t = en_i2c2 ? 1'b1 : sda_t;
assign sda2_t = en_i2c2 ? sda_t : 1'b1;

endmodule