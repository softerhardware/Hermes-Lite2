set_time_format -unit ns -decimal_places 3

create_clock -name rb-phy-clk -period 16.67ns [get_ports {ftd_clk_60 ftd_tx_fifo_full}]

create_clock -name rffe_ad9866_clk76p8 -period 76.800MHz [get_ports rffe_ad9866_clk76p8]
																																							 
create_generated_clock -name i2c_clk -source [get_ports {ftd_clk_60}] -divide_by 24 [get_registers radioberry_juice_core:radioberry_juice_core_i\|control:control_i\|clk_div:t1\|clk_track]

create_clock -name fan_clk -period 10.000MHz [get_registers {radioberry_juice_core:radioberry_juice_core_i|control:control_i|FAN.band_volts_enabled}]

create_clock -name virt_ad9866_rxclk_rx -period 153.600MHz
create_clock -name virt_ad9866_rxclk_tx -period 153.600MHz

derive_pll_clocks

derive_clock_uncertainty 

set_clock_groups -asynchronous \
						-group {	rb-phy-clk i2c_clk}\
						-group { \
									clock_153p6_mhz rffe_ad9866_clk76p8 clk_ad9866 clk_internal clk_ad9866_slow fan_clk\
								}
				
# CLOCK						

set_multicycle_path -from [get_clocks {rb-phy-clk}] -to [get_clocks {rb-phy-clk}] -setup -start 2
set_multicycle_path -from [get_clocks {rb-phy-clk}] -to [get_clocks {rb-phy-clk}] -hold -start 2	

set_multicycle_path -from [get_clocks {rb-phy-clk}] -to [get_clocks {i2c_clk}] -setup -start 8
set_multicycle_path -from [get_clocks {rb-phy-clk}] -to [get_clocks {i2c_clk}] -hold -end 2

set_multicycle_path -from {radioberry_juice_core_i|ad9866pll_inst|altpll_component|auto_generated|pll1|clk[3]} -to [get_clocks {fan_clk}] -setup -start 2
set_multicycle_path -from {radioberry_juice_core_i|ad9866pll_inst|altpll_component|auto_generated|pll1|clk[3]} -to [get_clocks {fan_clk}] -hold -start 2	

set_multicycle_path -from [get_clocks {fan_clk}] -to {radioberry_juice_core_i|ad9866pll_inst|altpll_component|auto_generated|pll1|clk[3]} -setup -start 2
set_multicycle_path -from [get_clocks {fan_clk}] -to {radioberry_juice_core_i|ad9866pll_inst|altpll_component|auto_generated|pll1|clk[3]} -hold -start 2	

set_multicycle_path -from [get_clocks {clk_internal}] -to [get_clocks {clk_ad9866_slow}] -setup -start 2
set_multicycle_path -from [get_clocks {clk_internal}] -to [get_clocks {clk_ad9866_slow}] -hold -start 2		

set_multicycle_path -from {radioberry_juice_core_i|ad9866pll_inst|altpll_component|auto_generated|pll1|clk[3]} -to [get_clocks {rb-phy-clk}] -setup -end 8
set_multicycle_path -from {radioberry_juice_core_i|ad9866pll_inst|altpll_component|auto_generated|pll1|clk[3]} -to [get_clocks {rb-phy-clk}] -hold -end 20	

set_multicycle_path -from {radioberry_juice_core_i|ad9866pll_inst|altpll_component|auto_generated|pll1|clk[3]} -to [get_clocks {i2c_clk}] -setup -end 8
set_multicycle_path -from {radioberry_juice_core_i|ad9866pll_inst|altpll_component|auto_generated|pll1|clk[3]} -to [get_clocks {i2c_clk}] -hold -end 20	
	
set_multicycle_path -from [get_clocks {clk_ad9866}] -to [get_clocks {clk_internal}] -setup -start 2
set_multicycle_path -from [get_clocks {clk_ad9866}] -to [get_clocks {clk_internal}] -hold -start 2	

set_multicycle_path -from [get_clocks {rb-phy-clk}] -to {radioberry_juice_core_i|ad9866pll_inst|altpll_component|auto_generated|pll1|clk[0]} -setup -start 8
set_multicycle_path -from [get_clocks {rb-phy-clk}] -to {radioberry_juice_core_i|ad9866pll_inst|altpll_component|auto_generated|pll1|clk[0]} -hold -end 20

set_multicycle_path -from [get_clocks {rb-phy-clk}] -to {radioberry_juice_core_i|ad9866pll_inst|altpll_component|auto_generated|pll1|clk[3]} -setup -start 8
set_multicycle_path -from [get_clocks {rb-phy-clk}] -to {radioberry_juice_core_i|ad9866pll_inst|altpll_component|auto_generated|pll1|clk[3]} -hold -start 20

set_multicycle_path -from [get_clocks {i2c_clk}] -to {radioberry_juice_core_i|ad9866pll_inst|altpll_component|auto_generated|pll1|clk[3]} -setup -start 12
set_multicycle_path -from [get_clocks {i2c_clk}] -to {radioberry_juice_core_i|ad9866pll_inst|altpll_component|auto_generated|pll1|clk[3]} -hold -start 20

set_multicycle_path -from {radioberry_juice_core_i|ad9866pll_inst|altpll_component|auto_generated|pll1|clk[1]} -to {radioberry_juice_core_i|ad9866pll_inst|altpll_component|auto_generated|pll1|clk[0]} -setup -start 2
set_multicycle_path -from {radioberry_juice_core_i|ad9866pll_inst|altpll_component|auto_generated|pll1|clk[1]} -to {radioberry_juice_core_i|ad9866pll_inst|altpll_component|auto_generated|pll1|clk[0]} -hold -start 1

# IO
set_false_path -to [get_ports {send_immediately_ftd_n}]
set_false_path -from [get_ports {io_phone_*}]
set_false_path -to [get_ports {io_pa_exttr}]
set_false_path -to [get_ports {io_pa_inttr}]
set_false_path -to [get_ports {io_pwr_envpa}]
set_false_path -to [get_ports {io_pwr_envbias}]
set_false_path -to [get_ports {io_s*}]
set_false_path -from [get_ports {io_s*}]


## radioberry phy interface
set_input_delay -add_delay -clock { rb-phy-clk } -max 9ns [get_ports {ftd_tx_fifo_full}]
set_input_delay -add_delay -clock { rb-phy-clk } -min 0ns [get_ports {ftd_tx_fifo_full}]

set_input_delay -add_delay -clock { rb-phy-clk } -max 9ns [get_ports {ftd_data[*]}]
set_input_delay -add_delay -clock { rb-phy-clk } -min 0ns [get_ports {ftd_data[*]}]

set_output_delay -add_delay -clock { rb-phy-clk } -max 9ns [get_ports {ftd_data[*]}]
set_output_delay -add_delay -clock { rb-phy-clk } -min 0ns [get_ports {ftd_data[*]}]

set_input_delay -add_delay -clock { rb-phy-clk } -max 9ns [get_ports {ftd_rx_fifo_empty}]
set_input_delay -add_delay -clock { rb-phy-clk } -min 0ns [get_ports {ftd_rx_fifo_empty}]

set_output_delay -add_delay -clock { rb-phy-clk } -max 9ns [get_ports {read_rx_fifo_ftd_n}]
set_output_delay -add_delay -clock { rb-phy-clk } -min 0ns [get_ports {read_rx_fifo_ftd_n}]

set_output_delay -add_delay -clock { rb-phy-clk } -max 9ns  [get_ports {write_tx_fifo_ftd_n}]
set_output_delay -add_delay -clock { rb-phy-clk } -min 0ns  [get_ports {write_tx_fifo_ftd_n}]

set_output_delay -add_delay -clock { rb-phy-clk } -max 9ns  [get_ports {output_enable_ftd_n}]
set_output_delay -add_delay -clock { rb-phy-clk } -min 0ns  [get_ports {output_enable_ftd_n}]



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

set_max_delay -from radioberry_juice_core:radioberry_juice_core_i|ad9866:ad9866_i|rffe_ad9866_tx[4]	-to rffe_ad9866_tx[4] 10

## AD9866 Other IO
set_false_path -to [get_ports {rffe_ad9866_sclk}]
set_false_path -to [get_ports {rffe_ad9866_sdio}]
set_false_path -to [get_ports {rffe_ad9866_sen_n}]
set_false_path -to [get_ports {rffe_ad9866_rst_n}]
set_false_path -to [get_ports {rffe_ad9866_mode}]
set_false_path -to [get_ports {rffe_ad9866_txquiet_n}]


## Additional timing constraints

set_false_path -from [get_clocks {radioberry_juice_core_i|ad9866pll_inst|altpll_component|auto_generated|pll1|clk[1]}] -to [get_clocks {radioberry_juice_core_i|ad9866pll_inst|altpll_component|auto_generated|pll1|clk[1]}]

set_max_delay -from radioberry_juice_core:radioberry_juice_core_i|dsiq_fifo:dsiq_fifo_i|recovery_flag_d1	-to radioberry_juice_core:radioberry_juice_core_i|control:control_i|iresp[15] 2
set_max_delay -from radioberry_juice_core:radioberry_juice_core_i|radio:radio_i|tx_state.CWHANG	-to radioberry_juice_core:radioberry_juice_core_i|control:control_i|iresp[32] 2
set_max_delay -from radioberry_juice_core:radioberry_juice_core_i|radio:radio_i|tx_state.CWTX	-to radioberry_juice_core:radioberry_juice_core_i|control:control_i|iresp[32] 2
set_max_delay -from radioberry_juice_core:radioberry_juice_core_i|ad9866:ad9866_i|rxclip	-to radioberry_juice_core:radioberry_juice_core_i|sync:syncio_rxclip|sync_chain[1] 2
set_max_delay -from radioberry_juice_core:radioberry_juice_core_i|dsiq_fifo:dsiq_fifo_i|rd_count[*]	   -to radioberry_juice_core:radioberry_juice_core_i|control:control_i|iresp[*] 14
set_max_delay -from radioberry_juice_core:radioberry_juice_core_i|control:control_i|dsiq_sample	       -to radioberry_juice_core:radioberry_juice_core_i|sync_pulse:sync_pulse_dsiq_sample|sync_chain[2] 2
set_max_delay -from radioberry_juice_core:radioberry_juice_core_i|control:control_i|rxclrstatus	       -to radioberry_juice_core:radioberry_juice_core_i|sync_pulse:sync_rxclrstatus_ad9866|sync_chain[2] 2
set_max_delay -from radioberry_juice_core:radioberry_juice_core_i|control:control_i|millisec_count[*]  -to radioberry_juice_core:radioberry_juice_core_i|sync_one:sync_msec_pulse_eth|sync_chain[*] 5
set_max_delay -from radioberry_juice_core:radioberry_juice_core_i|control:control_i|qmillisec_count[*] -to radioberry_juice_core:radioberry_juice_core_i|sync_one:sync_msec_pulse_eth|sync_chain[*] 6
set_max_delay -from radioberry_juice_core:radioberry_juice_core_i|control:control_i|qmillisec_count[*] -to radioberry_juice_core:radioberry_juice_core_i|sync_one:sync_qmsec_pulse_ad9866|sync_chain[*] 6
set_max_delay -from radioberry_juice_core:radioberry_juice_core_i|control:control_i|debounce:de_phone_tip|clean_pb	        -to radioberry_juice_core:radioberry_juice_core_i|sync:sync_ad9866_cw_keydown|sync_chain[1] 2
set_max_delay -from radioberry_juice_core:radioberry_juice_core_i|radio:radio_i|mix2:MIX4_5.mix2_4|nco2:nco2_i|sincos:sincos_i|coarserom:coarserom_i|altsyncram:rom_rtl_0|altsyncram_8h71:auto_generated|ram_block1a0~porta_address_reg0 -to radioberry_juice_core:radioberry_juice_core_i|radio:radio_i|mix2:MIX4_5.mix2_4|nco2:nco2_i|sincos:sincos_i|lpm_mult:sinmult|mult_u0t:auto_generated|mac_mult1~OBSERVABLEDATAA_REGOUT5 8
set_max_delay -from radioberry_juice_core:radioberry_juice_core_i|radio:radio_i|mix2:MIX4_5.mix2_4|nco2:nco2_i|sincos:sincos_i|coarserom:coarserom_i|altsyncram:rom_rtl_0|altsyncram_8h71:auto_generated|ram_block1a0~porta_address_reg0 -to radioberry_juice_core:radioberry_juice_core_i|radio:radio_i|mix2:MIX4_5.mix2_4|nco2:nco2_i|sincos:sincos_i|lpm_mult:sinmult|mult_u0t:auto_generated|mac_mult1~OBSERVABLEDATAA_REGOUT4 8
set_max_delay -from radioberry_juice_core:radioberry_juice_core_i|radio:radio_i|mix2:MIX4_5.mix2_4|nco2:nco2_i|sincos:sincos_i|coarserom:coarserom_i|altsyncram:rom_rtl_0|altsyncram_8h71:auto_generated|ram_block1a0~porta_address_reg0 -to radioberry_juice_core:radioberry_juice_core_i|radio:radio_i|mix2:MIX4_5.mix2_4|nco2:nco2_i|sincos:sincos_i|lpm_mult:sinmult|mult_u0t:auto_generated|mac_mult1~OBSERVABLEDATAA_REGOUT11 8
set_max_delay -from radioberry_juice_core:radioberry_juice_core_i|radio:radio_i|mix2:MIX1_3.mix2_2|adcq[*]	-to radioberry_juice_core:radioberry_juice_core_i|radio:radio_i|mix2:MIX1_3.mix2_2|i_data_d[*] 10
set_max_delay -from radioberry_juice_core:radioberry_juice_core_i|radio:radio_i|mix2:MIX1_3.mix2_2|adcq[*]	-to radioberry_juice_core:radioberry_juice_core_i|radio:radio_i|mix2:MIX1_3.mix2_2|q_data_d[*] 10

## Multicycle for FIR
set_multicycle_path -from [get_clocks {clock_153p6_mhz}] -to [get_clocks {clk_ad9866}] -setup -start 2
set_multicycle_path -from [get_clocks {clock_153p6_mhz}] -to [get_clocks {clk_ad9866}] -hold -start 2

## end of constraints