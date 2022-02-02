
//  radioberry using juice board.


// following Hermeslite setup as defined by Steve Haynal KF7O


module radioberry (

	//RF Frontend
	output          rffe_ad9866_rst_n,
	output  [5:0]   rffe_ad9866_tx,
	input   [5:0]   rffe_ad9866_rx,
	input           rffe_ad9866_rxsync,
	input           rffe_ad9866_rxclk,  
	output          rffe_ad9866_txquiet_n,
	output          rffe_ad9866_txsync,
	output          rffe_ad9866_sdio,
	output          rffe_ad9866_sclk,
	output          rffe_ad9866_sen_n,
	input           rffe_ad9866_clk76p8,
	output          rffe_ad9866_mode,
	
	// Juice interface; based on FTDI 
	input  			ftd_clk_60,
    inout	[7:0] 	ftd_data, 
	output			output_enable_ftd_n,  
    input			ftd_rx_fifo_empty,  
    output			read_rx_fifo_ftd_n,
    input  			ftd_tx_fifo_full,                  
    output 			write_tx_fifo_ftd_n,  
    output 			send_immediately_ftd_n, 
          
	// Radioberry IO
	input           io_phone_tip,
	input           io_phone_ring,
	output 			io_pa_exttr,
	output       	io_pa_inttr,
	
	// Power
	output			io_pwr_envpa,
	output			io_pwr_envbias,
	
	// I2C
	inout        	io_scl,
	inout        	io_sda
);


  radioberry_juice_core #(
    .NR   		(10                                  ),
    .NT   		(0                                  ),
    .UART 		(0                                  ),
    .ATU  		(0                                  ),
	.VNA 		(0									),
	.FAN        (1                                  ),
	.CW   		(1									),
	.FPGA_TYPE  (2									)
  ) radioberry_juice_core_i (
 
    .rffe_ad9866_rst_n         	(rffe_ad9866_rst_n    ),
    .rffe_ad9866_tx            	(rffe_ad9866_tx       ),
    .rffe_ad9866_rx            	(rffe_ad9866_rx       ),
    .rffe_ad9866_rxsync        	(rffe_ad9866_rxsync   ),
    .rffe_ad9866_rxclk        	(rffe_ad9866_rxclk    ),
    .rffe_ad9866_txquiet_n    	(rffe_ad9866_txquiet_n),
    .rffe_ad9866_txsync       	(rffe_ad9866_txsync   ),
    .rffe_ad9866_sdio         	(rffe_ad9866_sdio     ),
    .rffe_ad9866_sclk         	(rffe_ad9866_sclk     ),
    .rffe_ad9866_sen_n        	(rffe_ad9866_sen_n    ),
    .rffe_ad9866_clk76p8       	(rffe_ad9866_clk76p8  ),
    .rffe_ad9866_mode          	(rffe_ad9866_mode     ),
	.ftd_clk_60					(ftd_clk_60),
    .ftd_data					(ftd_data), 
	.output_enable_ftd_n		(output_enable_ftd_n),  
    .ftd_rx_fifo_empty			(ftd_rx_fifo_empty),  
    .read_rx_fifo_ftd_n			(read_rx_fifo_ftd_n),
    .ftd_tx_fifo_full			(ftd_tx_fifo_full),                  
    .write_tx_fifo_ftd_n		(write_tx_fifo_ftd_n),  
    .send_immediately_ftd_n		(send_immediately_ftd_n), 	
	.io_phone_tip				(io_phone_tip),
	.io_phone_ring				(io_phone_ring),
	.io_pa_exttr				(io_pa_exttr),
	.io_pa_inttr				(io_pa_inttr),
	.io_pwr_envpa				(io_pwr_envpa),
	.io_pwr_envbias				(io_pwr_envbias),
	.io_scl						(io_scl),
	.io_sda						(io_sda)
  );

endmodule
