set_time_format -unit ns -decimal_places 3

create_clock -name pi_spi_sck -period 15.625MHz [get_ports pi_spi_sck] 
create_clock -name pi_rx_clk -period 208.333 [get_ports pi_rx_clk]   ;# 1/4.8MHz = 208.333ns
create_clock -name pi_tx_clk -period 62.5   [get_ports pi_tx_clk]    ;# 1/16MHz = 62.5ns

create_clock -name {radioberry_core:radioberry_core_i|rx_pi_pio:rx_pi_pio_i|state.START} -period 208.333 [get_registers {radioberry_core:radioberry_core_i|rx_pi_pio:rx_pi_pio_i|state.START}]
create_clock -name {radioberry_core:radioberry_core_i|spi_slave:spi_slave_inst|done} -period 0.400MHz [get_registers {radioberry_core:radioberry_core_i|spi_slave:spi_slave_inst|done}]

create_clock -name rffe_ad9866_clk76p8 -period 76.800MHz [get_ports rffe_ad9866_clk76p8]

create_clock -name virt_ad9866_rxclk_rx -period 153.600MHz
create_clock -name virt_ad9866_rxclk_tx -period 153.600MHz

create_generated_clock -source {radioberry_core_i|ad9866pll_inst|altpll_component|auto_generated|pll1|inclk[0]} -duty_cycle 50.00 -name clock_76p8MHz {radioberry_core_i|ad9866pll_inst|altpll_component|auto_generated|pll1|clk[0]}

create_generated_clock -source {radioberry_core_i|ad9866pll_inst|altpll_component|auto_generated|pll1|inclk[0]} -multiply_by 2 -duty_cycle 50.00 -name clock_153p6_mhz {radioberry_core_i|ad9866pll_inst|altpll_component|auto_generated|pll1|clk[1]}

create_generated_clock -source {radioberry_core_i|ad9866pll_inst|altpll_component|auto_generated|pll1|inclk[0]} -multiply_by 16 -divide_by 5 -duty_cycle 50.00 -name clock_245p76_mhz {radioberry_core_i|ad9866pll_inst|altpll_component|auto_generated|pll1|clk[2]}

create_generated_clock -source {radioberry_core_i|ad9866pll_inst|altpll_component|auto_generated|pll1|inclk[0]} -multiply_by 25 -divide_by 192 -duty_cycle 50.00 -name clock_10_mhz {radioberry_core_i|ad9866pll_inst|altpll_component|auto_generated|pll1|clk[3]}

create_generated_clock -source {radioberry_core_i|ad9866pll_inst|altpll_component|auto_generated|pll1|inclk[0]} -divide_by 1600 -duty_cycle 50.00 -name clock_48khz {radioberry_core_i|ad9866pll_inst|altpll_component|auto_generated|pll1|clk[4]}


derive_pll_clocks

derive_clock_uncertainty

set_clock_groups -asynchronous \
						-group {	pi_rx_clk } \
						-group {	pi_tx_clk } \
						-group {	pi_spi_sck } \
						-group { \
									clock_153p6_mhz rffe_ad9866_clk76p8 clock_76p8MHz clock_10_mhz clock_48khz \
								}
				
# CLOCK						
#set_false_path -from [get_ports {pi_rx_clk}]	
#set_false_path -from [get_ports {pi_tx_clk}]	
set_false_path -from [get_ports {pi_spi_sck}]	

set_multicycle_path -from [get_clocks {clock_10_mhz}] -to [get_clocks {clock_48khz}] -setup -start 2
set_multicycle_path -from [get_clocks {clock_10_mhz}] -to [get_clocks {clock_48khz}] -hold -start 2		

set_multicycle_path -from [get_clocks {clock_10_mhz}] -to [get_clocks {clock_76p8MHz}] -setup -start 2
set_multicycle_path -from [get_clocks {clock_10_mhz}] -to [get_clocks {clock_76p8MHz}] -hold -start 2	
	
set_multicycle_path -from [get_clocks {clock_76p8MHz}] -to [get_clocks {clock_10_mhz}] -setup -start 2
set_multicycle_path -from [get_clocks {clock_76p8MHz}] -to [get_clocks {clock_10_mhz}] -hold -start 2		

# IO
set_false_path -from [get_ports {pi_spi_mosi}]
set_false_path -to [get_ports {pi_spi_miso}]
set_false_path -from [get_ports {pi_spi_ce[*]}]
set_false_path -to [get_ports {pi_rx_samples}]
set_false_path -to [get_ports {pi_rx_data[*]}]
set_false_path -from [get_ports {io_phone_*}]
set_false_path -to [get_ports {io_pa_exttr}]
set_false_path -to [get_ports {io_pa_inttr}]
set_false_path -to [get_ports {io_pwr_envpa}]
set_false_path -to [get_ports {io_pwr_envbias}]
set_false_path -from [get_ports {io_cw*}]
set_false_path -to [get_ports {pi_cw*}]
set_false_path -to [get_ports {pi_tx_ready}]
set_false_path -from [get_ports {pi_tx_data}]


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

set_max_delay -from radioberry_core:radioberry_core_i|ad9866:ad9866_i|rffe_ad9866_tx[4]	-to rffe_ad9866_tx[4] 10

## AD9866 Other IO
set_false_path -to [get_ports {rffe_ad9866_sclk}]
set_false_path -to [get_ports {rffe_ad9866_sdio}]
#set_false_path -from [get_ports {rffe_ad9866_sdo}]
set_false_path -to [get_ports {rffe_ad9866_sen_n}]
set_false_path -to [get_ports {rffe_ad9866_rst_n}]
set_false_path -to [get_ports {rffe_ad9866_mode}]
set_false_path -to [get_ports {rffe_ad9866_txquiet_n}]


## Additional timing constraints
set_max_delay -from radioberry_core:radioberry_core_i|control:control_i|qmillisec_count[*]	-to radioberry_core:radioberry_core_i|sync_one:sync_qmsec_pulse_ad9866|sync_chain[*] 3
set_max_delay -from radioberry_core:radioberry_core_i|control:control_i|debounce:de_phone_tip|clean_pb	-to radioberry_core:radioberry_core_i|sync:sync_ad9866_cw_keydown|sync_chain[1] 2
set_max_delay -from radioberry_core:radioberry_core_i|radio:radio_i|mix2:MIX1_3.mix2_2|nco2:nco2_i|sincos:sincos_i|coarserom:coarserom_i|altsyncram:rom_rtl_0|altsyncram_8h71:auto_generated|ram_block1a0~porta_address_reg0 -to radioberry_core:radioberry_core_i|radio:radio_i|mix2:MIX1_3.mix2_2|nco2:nco2_i|sincos:sincos_i|lpm_mult:sinmult|mult_u0t:auto_generated|mac_mult1~OBSERVABLEDATAA_REGOUT* 7


## Multicycle for FIR
set_multicycle_path -from [get_clocks {clock_153p6_mhz}] -to [get_clocks {clock_76p8MHz}] -setup -start 2
set_multicycle_path -from [get_clocks {clock_153p6_mhz}] -to [get_clocks {clock_76p8MHz}] -hold -start 2

## end of constraints