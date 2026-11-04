SIM ?= verilator
TOPLEVEL_LANG ?= verilog
GPI_IMPL := vpi

VERILOG_SOURCES += $(PWD)/../../rtl/sync.v
VERILOG_SOURCES += $(PWD)/../../rtl/ethernet/icmp.v
VERILOG_SOURCES += $(PWD)/../../rtl/ethernet/icmp_fifo.v
# Altera megafunction simulation library (models altddio_*, dcfifo, ...)
VERILOG_SOURCES += /home/shaynal/altera_lite/25.1std/quartus/eda/sim_lib/altera_mf.v

# --timing is needed by the vendor megafunction models; PROCASSWIRE because
# icmp.v drives its output dst_unreachable procedurally without declaring
# it as reg (accepted by Quartus)
COMPILE_ARGS += --timing -Wno-fatal -Wno-PROCASSWIRE

TOPLEVEL = icmp
MODULE = test_icmp

include $(shell cocotb-config --makefiles)/Makefile.sim
