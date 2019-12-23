set_time_format -unit ns -decimal_places 3

create_clock -name pi_spi_sck -period 15.625MHz [get_ports pi_spi_sck] 
create_clock -name pi_rx_clk -period 4.800MHz [get_ports pi_rx_clk] 
create_clock -name pi_tx_clk -period 4.800MHz [get_ports pi_tx_clk] 

create_clock -name {radioberry_core:radioberry_core_i|ddr_mux:ddr_mux_rx_inst|rd_req} -period 0.200MHz [get_registers {radioberry_core:radioberry_core_i|ddr_mux:ddr_mux_rx_inst|rd_req}]
create_clock -name {radioberry_core:radioberry_core_i|spi_slave:spi_slave_inst|done} -period 0.400MHz [get_registers {radioberry_core:radioberry_core_i|spi_slave:spi_slave_inst|done}]

create_clock -name rffe_ad9866_clk76p8 -period 76.800MHz [get_ports rffe_ad9866_clk76p8]

create_clock -name virt_ad9866_rxclk_rx -period 153.600MHz
create_clock -name virt_ad9866_rxclk_tx -period 153.600MHz

create_generated_clock -source {radioberry_core_i|ad9866pll_inst|altpll_component|auto_generated|pll1|inclk[0]} -duty_cycle 50.00 -name clock_76p8MHz {radioberry_core_i|ad9866pll_inst|altpll_component|auto_generated|pll1|clk[0]}

create_generated_clock -source {radioberry_core_i|ad9866pll_inst|altpll_component|auto_generated|pll1|inclk[0]} -multiply_by 2 -duty_cycle 50.00 -name clock_153p6_mhz {radioberry_core_i|ad9866pll_inst|altpll_component|auto_generated|pll1|clk[1]}

create_generated_clock -source {radioberry_core_i|ad9866pll_inst|altpll_component|auto_generated|pll1|inclk[0]} -multiply_by 16 -divide_by 5 -duty_cycle 50.00 -name clock_245p76_mhz {radioberry_core_i|ad9866pll_inst|altpll_component|auto_generated|pll1|clk[2]}

create_generated_clock -source {radioberry_core_i|ad9866pll_inst|altpll_component|auto_generated|pll1|inclk[0]} -multiply_by 25 -divide_by 192 -duty_cycle 50.00 -name clock_10_mhz {radioberry_core_i|ad9866pll_inst|altpll_component|auto_generated|pll1|clk[3]}


derive_pll_clocks

derive_clock_uncertainty

set_clock_groups -asynchronous \
						-group {	radioberry_core:radioberry_core_i|ddr_mux:ddr_mux_rx_inst|rd_req} \
						-group {	radioberry_core:radioberry_core_i|spi_slave:spi_slave_inst|done} \
						-group {	pi_rx_clk } \
						-group {	pi_tx_clk } \
						-group {	pi_spi_sck } \
						-group { \
									clock_153p6_mhz rffe_ad9866_clk76p8 clock_76p8MHz clock_10_mhz \
								}
				
# CLOCK						
set_false_path -from [get_ports {pi_rx_clk}]	
set_false_path -from [get_ports {pi_tx_clk}]
set_false_path -from [get_ports {pi_spi_sck}]				

# IO
set_false_path -from [get_ports {pi_spi_mosi}]
set_false_path -to [get_ports {pi_spi_miso}]
set_false_path -from [get_ports {pi_spi_ce[*]}]
set_false_path -to [get_ports {pi_rx_samples}]
set_false_path -to [get_ports {pi_rx_last}]
set_false_path -to [get_ports {pi_rx_data[*]}]
set_false_path -to [get_ports {pi_tx_samples}]
set_false_path -from [get_ports {pi_tx_data[*]}]


## AD9866 RX Path
## See http://billauer.co.il/blog/2017/04/altera-intel-fpga-io-ff-packing/
set_input_delay -add_delay -max -clock virt_ad9866_rxclk_rx 5.0 [get_ports {rffe_ad9866_rxsync}]
set_input_delay -add_delay -min -clock virt_ad9866_rxclk_rx 0.0 [get_ports {rffe_ad9866_rxsync}]

set_input_delay -add_delay -max -clock virt_ad9866_rxclk_rx 5.0 [get_ports {rffe_ad9866_rx[*]}]
set_input_delay -add_delay -min -clock virt_ad9866_rxclk_rx 0.0 [get_ports {rffe_ad9866_rx[*]}]


## AD9866 TX Path

set_output_delay -add_delay -max -clock virt_ad9866_rxclk_tx 2.5 [get_ports {rffe_ad9866_txsync}]
set_output_delay -add_delay -min -clock virt_ad9866_rxclk_tx 0.0 [get_ports {rffe_ad9866_txsync}]

set_output_delay -add_delay -max -clock virt_ad9866_rxclk_tx 2.5 [get_ports {rffe_ad9866_tx[*]}]
set_output_delay -add_delay -min -clock virt_ad9866_rxclk_tx 0.0 [get_ports {rffe_ad9866_tx[*]}]


## AD9866 Other IO
set_false_path -to [get_ports {rffe_ad9866_sclk}]
set_false_path -to [get_ports {rffe_ad9866_sdio}]
#set_false_path -from [get_ports {rffe_ad9866_sdo}]
set_false_path -to [get_ports {rffe_ad9866_sen_n}]
set_false_path -to [get_ports {rffe_ad9866_rst_n}]
set_false_path -to [get_ports {rffe_ad9866_mode}]
set_false_path -to [get_ports {rffe_ad9866_txquiet_n}]


## Additional timing constraints

## Multicycle for FIR

set_multicycle_path -from [get_clocks {clock_153p6_mhz}] -to [get_clocks {clock_76p8MHz}] -setup -start 2
set_multicycle_path -from [get_clocks {clock_153p6_mhz}] -to [get_clocks {clock_76p8MHz}] -hold -start 2

## end of constraints