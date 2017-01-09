
set_time_format -unit ns -decimal_places 3
create_clock -period 125MHz	  [get_ports phy_clk125]		-name phy_clk125

derive_clock_uncertainty
