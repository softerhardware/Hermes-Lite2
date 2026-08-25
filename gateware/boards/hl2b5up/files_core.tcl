## Core integration and device primitives

set_global_assignment -name VERILOG_FILE ../../rtl/hermeslite_core.v
set_global_assignment -name VERILOG_FILE ../../rtl/fifos.v
set_global_assignment -name VERILOG_FILE ../../rtl/ad9866.v
set_global_assignment -name VERILOG_FILE ../../rtl/ad9866pll.v
set_global_assignment -name VERILOG_FILE ../../rtl/ad9866ctrl.v
set_global_assignment -name VERILOG_FILE ../../rtl/ethpll.v

set_global_assignment -name VERILOG_FILE ../../rtl/primitives/intel/multipliers.v
