
set_time_format -unit ns -decimal_places 3
create_clock -name phy_clk125 -period 125.000MHz	[get_ports phy_clk125]		

create_clock -name phy_rx_clk -period 8.000	-waveform {2 6} [get_ports {phy_rx_clk}]

#virtual base clocks on required inputs
create_clock -name virt_phy_rx_clk	-period 8.000

## run derive_pll_clocks -use_net_name in timing analyzer to generate template for below

create_generated_clock -source {ethernet_inst|network_inst|rgmii_send_inst|ethpll_inst|altpll_component|auto_generated|pll1|inclk[0]} -duty_cycle 50.00 -name clock_125MHz {ethernet_inst|network_inst|rgmii_send_inst|ethpll_inst|altpll_component|auto_generated|pll1|clk[0]}

create_generated_clock -source {ethernet_inst|network_inst|rgmii_send_inst|ethpll_inst|altpll_component|auto_generated|pll1|inclk[0]} -phase 90.00 -duty_cycle 50.00 -name clock_90_125MHz {ethernet_inst|network_inst|rgmii_send_inst|ethpll_inst|altpll_component|auto_generated|pll1|clk[1]}

create_generated_clock -source {ethernet_inst|network_inst|rgmii_send_inst|ethpll_inst|altpll_component|auto_generated|pll1|inclk[0]} -divide_by 50 -duty_cycle 50.00 -name clock_2_5MHz {ethernet_inst|network_inst|rgmii_send_inst|ethpll_inst|altpll_component|auto_generated|pll1|clk[3]}


## Create TX clock version based on pin output
create_generated_clock -name tx_output_clock -source [get_pins {ethernet_inst|network_inst|rgmii_send_inst|ethpll_inst|altpll_component|auto_generated|pll1|clk[1]}] [get_ports {phy_tx_clk}]



#************************************************************** 
# Set Input Delay
#**************************************************************

# If setup and hold delays are equal then only need to specify once without max or min 

#PHY Data in 
set_input_delay  -max 0.8  -clock virt_phy_rx_clk [get_ports {phy_rx[*] phy_rx_dv}]
set_input_delay  -min -0.8 -clock virt_phy_rx_clk -add_delay [get_ports {phy_rx[*] phy_rx_dv}]
set_input_delay  -max 0.8 -clock virt_phy_rx_clk -clock_fall -add_delay [get_ports {phy_rx[*] phy_rx_dv}]
set_input_delay  -min -0.8 -clock virt_phy_rx_clk -clock_fall -add_delay [get_ports {phy_rx[*] phy_rx_dv}]


#PHY PHY_MDIO Data in +/- 10nS setup and hold
set_input_delay  10  -clock clock_2_5MHz -reference_pin [get_ports phy_mdc] {phy_mdio}


#**************************************************************
# Set Output Delay
#**************************************************************

# If setup and hold delays are equal then only need to specify once without max or min 

#PHY
set_output_delay  -max 1.0  -clock tx_output_clock [get_ports {phy_tx[*] phy_tx_en}]
set_output_delay  -min -0.8 -clock tx_output_clock [get_ports {phy_tx[*] phy_tx_en}]  -add_delay
set_output_delay  -max 1.0  -clock tx_output_clock [get_ports {phy_tx[*] phy_tx_en}]  -clock_fall -add_delay
set_output_delay  -min -0.8 -clock tx_output_clock [get_ports {phy_tx[*] phy_tx_en}]  -clock_fall -add_delay

#PHY (2.5MHz)
set_output_delay  10 -clock clock_2_5MHz -reference_pin [get_ports phy_mdc] {phy_mdio}


#*************************************************************************************
# Set Clock Groups
#*************************************************************************************


set_clock_groups -asynchronous -group { \
					clock_125MHz \
					clock_90_125MHz \
					clock_2_5MHz \
					tx_output_clock \
				       } \
					-group {phy_rx_clk } 

#**************************************************************
# Set Maximum Delay
#************************************************************** 

set_max_delay -from clock_125MHz -to clock_125MHz 21
set_max_delay -from clock_125MHz -to tx_output_clock 3

set_max_delay -from clock_2_5MHz -to clock_125MHz 22 

#set_max_delay -from phy_rx_clk -to phy_rx_clk 10



#**************************************************************
# Set Minimum Delay
#**************************************************************

set_min_delay -from clock_90_125MHz -to tx_output_clock -2

#set_min_delay -from phy_rx_clk -to phy_rx_clk -4



#**************************************************************
# Set False Paths
#**************************************************************

# Set false path to generated clocks that feed output pins
set_false_path -to [get_ports {phy_mdc}]

# Set false paths to remove irrelevant setup and hold analysis 
set_false_path -fall_from  virt_phy_rx_clk -rise_to phy_rx_clk -setup
set_false_path -rise_from  virt_phy_rx_clk -fall_to phy_rx_clk -setup
set_false_path -fall_from  virt_phy_rx_clk -fall_to phy_rx_clk -hold
set_false_path -rise_from  virt_phy_rx_clk -rise_to phy_rx_clk -hold

set_false_path -fall_from [get_clocks clock_125MHz] -rise_to [get_clocks tx_output_clock] -setup
set_false_path -rise_from [get_clocks clock_125MHz] -fall_to [get_clocks tx_output_clock] -setup
set_false_path -fall_from [get_clocks clock_125MHz] -fall_to [get_clocks tx_output_clock] -hold
set_false_path -rise_from [get_clocks clock_125MHz] -rise_to [get_clocks tx_output_clock] -hold

