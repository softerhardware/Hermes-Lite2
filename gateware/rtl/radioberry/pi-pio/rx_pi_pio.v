// Module for bringing the data from gateware to raspberry pi (upstream).

module rx_pi_pio(
	input						clk                 ,
 
	input		[23:0]			us_tdata            ,
	input						us_tlast            ,
	output						us_tready           ,
	input						us_tvalid           ,
	input		[10:0]			us_tlength          ,
	
	output logic [3:0]  		us_stream			,
	output logic 				us_stream_valid
);


localparam START        = 5'h0,
           RXDATA5      = 5'h1,
           RXDATA4      = 5'h2,
           RXDATA3      = 5'h3,
           RXDATA2      = 5'h4,
           RXDATA1      = 5'h5,
           RXDATA0      = 5'h6;

logic [ 4:0] state      = START;
logic [ 4:0] state_next;
logic [ 7:0] sample_no    = 8'h00;
logic [ 7:0] sample_no_next;

// State
always @ (posedge clk) begin
  state <= state_next;
  sample_no <= sample_no_next;
end


// FSM Combinational
always @* begin

  // Next State
  state_next = state;
  
  sample_no_next = sample_no;
  
  // Combinational
  us_tready = 1'b0;
  us_stream_valid = 1'b0;
  
  case (state)
    START: begin
		if ((us_tlength > 11'd256) & us_tvalid) begin 
			state_next = RXDATA5;
			us_stream_valid = 1'b1;
			sample_no_next = 8'd160;	// 80 IQ samples.
			us_stream = 4'h00;
		end 
    end 
	
    RXDATA5: begin
		sample_no_next = sample_no - 8'd1;
		us_stream = us_tdata[23:20];
		state_next = RXDATA4;
    end

    RXDATA4: begin
		us_stream = us_tdata[19:16];
		state_next = RXDATA3;
    end
	
	RXDATA3: begin
		us_stream = us_tdata[15:12];
		state_next = RXDATA2;
    end

	RXDATA2: begin
		us_stream = us_tdata[11:8];
		state_next = RXDATA1;
    end

	RXDATA1: begin
		us_stream = us_tdata[7:4];
		state_next = RXDATA0;
    end

    RXDATA0: begin
		us_stream = us_tdata[3:0];
		us_tready = 1'b1; 
		state_next = sample_no[7:0] ? RXDATA5 : START;
    end	
	
    default: state_next = START;

  endcase 
end 


endmodule