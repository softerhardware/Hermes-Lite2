
module radioberry_phy 
( 
	input 	logic 			ftd_reset,
	
	input	logic			run,
	
 	// ftdi 245 protocol 
	input 	logic  			ftd_clk_60,
    
	input	logic 	[7:0] 	data_i, 
    output 	logic	[7:0] 	data_o, 
    output 	logic  			data_en, 
	
	output 	logic  			output_enable_ftd_n,  
    input   logic 			ftd_rx_fifo_empty,  
    output  logic 			read_rx_fifo_ftd_n,
	
    input 	logic 			ftd_tx_fifo_full,                  
    output 	logic  			write_tx_fifo_ftd_n,  
	
    output  logic 			send_immediately_ftd_n,
	
	// openhpsdr p-1 down stream	
	output logic [7:0]		ds_stream,
	output logic			ds_valid,
	
	// openhpsdr p-1 up stream
	input 	logic [7:0]		us_stream,
	input 	logic			us_valid,
	output	logic 			us_ready
);
 
assign send_immediately_ftd_n = 1'b1;

logic send, receive, tx_ready, rx_ready, receiving, sending;

logic sync; 


assign data_en = output_enable_ftd_n;

assign receiving = ~output_enable_ftd_n | ~read_rx_fifo_ftd_n;
assign sending = ~write_tx_fifo_ftd_n;
assign tx_ready  = ~ftd_tx_fifo_full & run;
assign rx_ready  = ~ftd_rx_fifo_empty;

assign us_ready = ~write_tx_fifo_ftd_n;
assign write_tx_fifo_ftd_n = ftd_reset | ftd_tx_fifo_full ? 1 : (~ftd_tx_fifo_full & sync & us_valid & send) ? 0 : 1;

always @(posedge ftd_clk_60)
begin
	if (ftd_reset) begin send <= 1'b0; receive <= 1'b0; end
	else begin
		if (rx_ready & ~sending) begin send <= 1'b0; receive <= 1'b1; end
		else if (tx_ready & ~receiving) begin send <= 1'b1; receive <= 1'b0; end
	end
end

// ftdi write mode; TX FIFO (up stream)
always @(posedge ftd_clk_60) begin
	if (ftd_reset) sync <= 0; 
	else begin
		if(!ftd_tx_fifo_full) begin
			if (~us_valid) data_o <= us_stream;
			if (sync & us_valid & send) data_o <= us_stream;
			sync <= 1;
		end else sync <= 0;
	end
end


// ftdi read mode; RX FIFO (down stream)
always @(posedge ftd_clk_60) begin
    output_enable_ftd_n <= 1;
	read_rx_fifo_ftd_n <= 1;
	ds_valid <= 0;

	if(~ftd_rx_fifo_empty & receive) begin
		output_enable_ftd_n <= 0;
		if (~output_enable_ftd_n) read_rx_fifo_ftd_n <= 0;
		if (~read_rx_fifo_ftd_n) begin 	ds_stream <= data_i; ds_valid <= 1; end
	end	
end

endmodule