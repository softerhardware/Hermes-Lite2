`timescale 1ns/1ps
module tx_pi_pio (
    input         clk,
    input         rst,              
    input         ds_stream,        
    input         tx_tready,        
    output reg [7:0] tx_part_iq,    
    output reg       txvalid,       
    output reg       txlast         
);

  // State encoding
  localparam IDLE     = 2'b00;
  localparam SHIFTING = 2'b01;

  reg [1:0] state, state_next;
  reg [2:0] bit_count,  bit_count_next;   
  reg [2:0] byte_count, byte_count_next;  
  reg [7:0] shift_reg,  shift_reg_next;

  reg [7:0] tx_part_iq_next;
  reg       txvalid_next, txlast_next;

  wire start_pulse = (state == IDLE) & tx_tready;

  // Simulation
  initial begin
    state         = IDLE;
    bit_count     = 3'd0;
    byte_count    = 3'd0;
    shift_reg     = 8'd0;
    tx_part_iq    = 8'd0;
    txvalid       = 1'b0;
    txlast        = 1'b0;
  end

  always @(posedge clk or posedge rst) begin
    if (rst) begin
      state         <= IDLE;
      bit_count     <= 3'd0;
      byte_count    <= 3'd0;
      shift_reg     <= 8'd0;
      tx_part_iq    <= 8'd0;
      txvalid       <= 1'b0;
      txlast        <= 1'b0;
    end else begin
      state         <= state_next;
      bit_count     <= bit_count_next;
      byte_count    <= byte_count_next;
      shift_reg     <= shift_reg_next;
      tx_part_iq    <= tx_part_iq_next;
      txvalid       <= txvalid_next;
      txlast        <= txlast_next;
    end
  end

  // Combinatorisch
  always @* begin
    // defaults
    state_next       = state;
    bit_count_next   = bit_count;
    byte_count_next  = byte_count;
    shift_reg_next   = shift_reg;

    txvalid_next     = 1'b0;
    txlast_next      = 1'b0;
    tx_part_iq_next  = tx_part_iq;

    case (state)
      IDLE: begin
        bit_count_next   = 3'd7;
        byte_count_next  = 3'd3;
        if (start_pulse) state_next = SHIFTING;
      end

      SHIFTING: begin
        shift_reg_next = (shift_reg << 1) | {7'b0, ds_stream};

        if (bit_count == 3'd0) begin
          tx_part_iq_next = shift_reg_next;
          txvalid_next    = 1'b1;

          if (byte_count == 3'd0) begin
            txlast_next  = 1'b1;    
            state_next   = IDLE;
          end else begin
            byte_count_next = byte_count - 1'b1;
            bit_count_next  = 3'd7; 
          end
        end else begin
          bit_count_next = bit_count - 1'b1;
        end
      end

      default: begin
        state_next = IDLE;
      end
    endcase
  end

endmodule
