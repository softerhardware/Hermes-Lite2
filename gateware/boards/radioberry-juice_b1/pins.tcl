set_location_assignment PIN_53 -to rffe_ad9866_clk76p8

#FTDI 	
set_location_assignment PIN_55 -to  ftd_clk_60		
set_location_assignment PIN_44 -to  ftd_data[0]	
set_location_assignment PIN_32 -to  ftd_data[1]	
set_location_assignment PIN_33 -to  ftd_data[2]	
set_location_assignment PIN_113 -to ftd_data[3]	
set_location_assignment PIN_60 -to  ftd_data[4]	
set_location_assignment PIN_59 -to  ftd_data[5]	
set_location_assignment PIN_58 -to  ftd_data[6]	
set_location_assignment PIN_50 -to  ftd_data[7]	
set_location_assignment PIN_46 -to  read_rx_fifo_ftd_n	
set_location_assignment PIN_49 -to  write_tx_fifo_ftd_n
set_location_assignment PIN_43 -to  ftd_tx_fifo_full	
set_location_assignment PIN_42 -to  ftd_rx_fifo_empty			
set_location_assignment PIN_31 -to  send_immediately_ftd_n	
set_location_assignment PIN_39 -to  output_enable_ftd_n	


#Radioberry IO
set_location_assignment PIN_144 -to io_pa_exttr
set_location_assignment PIN_143 -to io_pa_inttr
set_location_assignment PIN_136 -to io_pwr_envpa
set_location_assignment PIN_137 -to io_pwr_envbias
set_location_assignment PIN_120 -to io_phone_tip
set_location_assignment PIN_121 -to io_phone_ring
set_location_assignment PIN_115 -to io_scl
set_location_assignment PIN_119 -to io_sda

#CW 
set_location_assignment PIN_141 -to io_cwl
set_location_assignment PIN_142 -to io_cwr

#RF-Frontend
set_location_assignment PIN_111 -to rffe_ad9866_mode
set_location_assignment PIN_114 -to rffe_ad9866_rst_n
set_location_assignment PIN_65 -to rffe_ad9866_sen_n
set_location_assignment PIN_66 -to rffe_ad9866_sclk
set_location_assignment PIN_68 -to rffe_ad9866_sdio

set_location_assignment PIN_71 -to rffe_ad9866_rxclk
set_location_assignment PIN_80 -to rffe_ad9866_rx[0]
set_location_assignment PIN_83 -to rffe_ad9866_rx[1]
set_location_assignment PIN_85 -to rffe_ad9866_rx[2]
set_location_assignment PIN_86 -to rffe_ad9866_rx[3]
set_location_assignment PIN_87 -to rffe_ad9866_rx[4]
set_location_assignment PIN_98 -to rffe_ad9866_rx[5]

set_location_assignment PIN_77 -to rffe_ad9866_rxsync
set_location_assignment PIN_99 -to rffe_ad9866_tx[0]
set_location_assignment PIN_100 -to rffe_ad9866_tx[1]
set_location_assignment PIN_101 -to rffe_ad9866_tx[2]
set_location_assignment PIN_103 -to rffe_ad9866_tx[3]
set_location_assignment PIN_105 -to rffe_ad9866_tx[4]
set_location_assignment PIN_106 -to rffe_ad9866_tx[5]
set_location_assignment PIN_72 -to rffe_ad9866_txquiet_n
set_location_assignment PIN_76 -to rffe_ad9866_txsync


set_instance_assignment -name FAST_INPUT_REGISTER ON 	-to ftd_clk_60

set_instance_assignment -name FAST_INPUT_REGISTER ON 	-to ftd_data[*]
set_instance_assignment -name FAST_OUTPUT_REGISTER ON 	-to ftd_data[*]

set_instance_assignment -name FAST_OUTPUT_REGISTER ON 	-to read_rx_fifo_ftd_n
set_instance_assignment -name FAST_OUTPUT_REGISTER ON 	-to write_tx_fifo_ftd_n
set_instance_assignment -name FAST_OUTPUT_REGISTER ON 	-to output_enable_ftd_n

set_instance_assignment -name FAST_INPUT_REGISTER ON 	-to ftd_tx_fifo_full
set_instance_assignment -name FAST_INPUT_REGISTER ON 	-to ftd_rx_fifo_empty

set_instance_assignment -name FAST_OUTPUT_REGISTER ON 	-to rffe_ad9866_tx[*]
set_instance_assignment -name FAST_OUTPUT_REGISTER ON 	-to rffe_ad9866_txsync
set_instance_assignment -name FAST_INPUT_REGISTER ON 	-to rffe_ad9866_rx[*]
set_instance_assignment -name FAST_INPUT_REGISTER ON 	-to rffe_ad9866_rxsync
set_instance_assignment -name FAST_OUTPUT_REGISTER ON 	-to rffe_ad9866_sdio
set_instance_assignment -name FAST_OUTPUT_REGISTER ON 	-to rffe_ad9866_sen_n
set_instance_assignment -name FAST_OUTPUT_REGISTER ON 	-to rffe_ad9866_sclk
set_instance_assignment -name FAST_OUTPUT_REGISTER ON	-to rffe_ad9866_rst_n
set_instance_assignment -name FAST_OUTPUT_REGISTER ON 	-to rffe_ad9866_txquiet_n

set_instance_assignment -name FAST_OUTPUT_ENABLE_REGISTER ON -to *

set_instance_assignment -name WEAK_PULL_UP_RESISTOR ON -to io_phone_tip
set_instance_assignment -name WEAK_PULL_UP_RESISTOR ON -to io_pa_exttr
set_instance_assignment -name WEAK_PULL_UP_RESISTOR ON -to io_pa_inttr
set_instance_assignment -name WEAK_PULL_UP_RESISTOR ON -to io_pwr_envpa
set_instance_assignment -name WEAK_PULL_UP_RESISTOR ON -to io_pwr_envbias
set_instance_assignment -name WEAK_PULL_UP_RESISTOR ON -to io_cwl
set_instance_assignment -name WEAK_PULL_UP_RESISTOR ON -to io_cwr

