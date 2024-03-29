
//  radioberry


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
	
	//Radio Control
	input 			pi_spi_sck, 
	input 			pi_spi_mosi, 
	output 			pi_spi_miso, 
	input [1:0]	 	pi_spi_ce,
	
	//RX IQ data
	input wire 		pi_rx_clk,
	output wire 	pi_rx_samples,
	output [7:0] 	pi_rx_data,
 
	// Radioberry IO
	input           io_phone_tip,
	input           io_phone_ring,
	output 			io_pa_exttr,
	output       	io_pa_inttr,
	
	// Local CW using pihpsdr
	input 			io_cwl,
	input 			io_cwr,
	output 			pi_cwl,
	output 			pi_cwr
);


  radioberry_core #(
    .NR   		(8                                 ),
    .NT   		(0                                  ),
    .UART 		(0                                  ),
    .ATU  		(0                                  ),
	.VNA 		(0									),
	.CW   		(0									)
  ) radioberry_core_i (
 
    .rffe_ad9866_rst_n         (rffe_ad9866_rst_n    ),
    .rffe_ad9866_tx            (rffe_ad9866_tx       ),
    .rffe_ad9866_rx            (rffe_ad9866_rx       ),
    .rffe_ad9866_rxsync        (rffe_ad9866_rxsync   ),
    .rffe_ad9866_rxclk         (rffe_ad9866_rxclk    ),
    .rffe_ad9866_txquiet_n     (rffe_ad9866_txquiet_n),
    .rffe_ad9866_txsync        (rffe_ad9866_txsync   ),
    .rffe_ad9866_sdio          (rffe_ad9866_sdio     ),
    .rffe_ad9866_sclk          (rffe_ad9866_sclk     ),
    .rffe_ad9866_sen_n         (rffe_ad9866_sen_n    ),
    .rffe_ad9866_clk76p8       (rffe_ad9866_clk76p8  ),
    .rffe_ad9866_mode          (rffe_ad9866_mode     ),
	.pi_spi_sck					(pi_spi_sck), 
	.pi_spi_mosi				(pi_spi_mosi), 
	.pi_spi_miso				(pi_spi_miso), 
	.pi_spi_ce					(pi_spi_ce),
	.pi_rx_clk					(pi_rx_clk),
	.pi_rx_samples				(pi_rx_samples),
	.pi_rx_data					(pi_rx_data),
	.io_phone_tip				(io_phone_tip),
	.io_phone_ring				(io_phone_ring),
	.io_pa_exttr				(io_pa_exttr),
	.io_pa_inttr				(io_pa_inttr),
	.io_cwl						(io_cwl),
	.io_cwr						(io_cwr),
	.pi_cwl						(pi_cwl),
	.pi_cwr						(pi_cwr)
  );

endmodule