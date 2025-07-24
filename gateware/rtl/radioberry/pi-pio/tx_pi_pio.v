module tx_pi_pio (
    input         clk,      
    input         ds_stream,
    output reg    ds_stream_valid,
    output reg [7:0]  tx_part_iq,   
    output reg    txvalid,
    output reg    txlast
);

    // State encoding
    localparam IDLE     = 2'b00;
    localparam SHIFTING = 2'b01;
	
	logic [ 4:0] state      = IDLE;

    reg [1:0] state_next;
    reg [2:0] byte_count, byte_count_next;
    reg [2:0] bit_count, bit_count_next;
    reg [7:0] shift_reg, shift_reg_next;

    // State registers
    always @(posedge clk) begin
        state      <= state_next;
        bit_count  <= bit_count_next;
        byte_count <= byte_count_next;
        shift_reg  <= shift_reg_next;
    end
	
    always @(*) begin
        tx_part_iq = shift_reg;
    end

    // FSM logic
    always @* begin
        // Defaults
        state_next      = state;
        bit_count_next  = bit_count;
        byte_count_next = byte_count;
        shift_reg_next  = shift_reg;
        ds_stream_valid = 1'b0;
        txvalid         = 1'b0;
        txlast          = 1'b0;

        case (state)
            IDLE: begin
                ds_stream_valid = 1'b1;
                state_next     = SHIFTING;
                bit_count_next = 3'd7;        
                byte_count_next= 3'd3;     
                shift_reg_next = {7'd0, ds_stream};
            end

            SHIFTING: begin
                shift_reg_next = { shift_reg[6:0], ds_stream};
                if (bit_count == 0) begin
                    txvalid         = 1'b1;
                    if (byte_count == 0) begin
                        txlast     = 1'b1;  
                        state_next = IDLE;
                    end else begin
                        byte_count_next = byte_count - 1'b1;
                        bit_count_next  = 3'd7;
                    end
                end else begin
                    bit_count_next = bit_count - 1'b1;
                end
            end
        endcase
    end

endmodule
