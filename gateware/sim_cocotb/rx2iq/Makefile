SIM ?= verilator
TOPLEVEL_LANG ?= verilog
PWD=$(shell pwd)
TOPDIR=$(PWD)/../../rtl

#DUT (the wrapper mirrors the myhdl-generated test_rx2.v used by
#sim/test_rx2IQ.py: dual cic + dual varcic I/Q chains)
VERILOG_SOURCES += tb_rx2iq.sv
VERILOG_SOURCES += $(TOPDIR)/radio_openhpsdr1/cordic.v
VERILOG_SOURCES += $(TOPDIR)/radio_openhpsdr1/cic.v
VERILOG_SOURCES += $(TOPDIR)/radio_openhpsdr1/cic_comb.v
VERILOG_SOURCES += $(TOPDIR)/radio_openhpsdr1/cic_integrator.v
VERILOG_SOURCES += $(TOPDIR)/radio_openhpsdr1/varcic.v

TOPLEVEL = tb_rx2iq

# cordic/cic/varcic have benign width warnings in their control logic
COMPILE_ARGS += -Wno-WIDTHEXPAND -Wno-WIDTHTRUNC

GPI_IMPL := vpi

export TOPLEVEL_LANG
MODULE=test_rx2iq

EXTRA_ARGS += --trace --trace-depth 2

include $(shell cocotb-config --makefiles)/Makefile.sim
