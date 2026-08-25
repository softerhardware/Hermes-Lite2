## Protocol layer and board control

# OpenHPSDR protocol packer/parser
set_global_assignment -name VERILOG_FILE ../../rtl/dsopenhpsdr1.v
set_global_assignment -name VERILOG_FILE ../../rtl/usopenhpsdr1.v

# CDC primitives
set_global_assignment -name VERILOG_FILE ../../rtl/sync.v

# Board control plane
set_global_assignment -name VERILOG_FILE ../../rtl/control.v
set_global_assignment -name VERILOG_FILE ../../rtl/led_flash.v
set_global_assignment -name VERILOG_FILE ../../rtl/debounce.v
set_global_assignment -name VERILOG_FILE ../../rtl/slow_adc.v
set_global_assignment -name VERILOG_FILE ../../rtl/i2c_master.v
set_global_assignment -name VERILOG_FILE ../../rtl/i2c_bus2.v
set_global_assignment -name VERILOG_FILE ../../rtl/i2c.v
set_global_assignment -name VERILOG_FILE ../../rtl/extamp.v
set_global_assignment -name VERILOG_FILE ../../rtl/exttuner.v

# CW keying
set_global_assignment -name VERILOG_FILE ../../rtl/cw_basic.v
set_global_assignment -name VERILOG_FILE ../../rtl/cw_openhpsdr.v
set_global_assignment -name VERILOG_FILE ../../rtl/iambic.v

# Inter-board link
set_global_assignment -name VERILOG_FILE ../../rtl/hl2link.v
set_global_assignment -name VERILOG_FILE ../../rtl/hl2link_app.v
