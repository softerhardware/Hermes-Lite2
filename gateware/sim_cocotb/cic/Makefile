SIM ?= verilator
TOPLEVEL_LANG ?= verilog
PWD=$(shell pwd)
TOPDIR=$(PWD)/../../rtl

COMPILE_ARGS+=+incdir+$(TOPDIR)/radio_openhpsdr1/firrom

COMPILE_ARGS+=+define+SIMULATION=1

#DUT
VERILOG_SOURCES += $(TOPDIR)/radio_openhpsdr1/cic.v
VERILOG_SOURCES += $(TOPDIR)/radio_openhpsdr1/cic_integrator.v
VERILOG_SOURCES += $(TOPDIR)/radio_openhpsdr1/cic_comb.v

TOPLEVEL = cic

GPI_IMPL := vpi

export TOPLEVEL_LANG
MODULE=testcic


EXTRA_ARGS += --trace --trace-depth 2

include $(shell cocotb-config --makefiles)/Makefile.sim

