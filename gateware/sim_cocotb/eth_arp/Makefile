SIM ?= verilator
TOPLEVEL_LANG ?= verilog
PWD=$(shell pwd)
TOPDIR=$(PWD)/../../rtl

#DUT
VERILOG_SOURCES += $(TOPDIR)/ethernet/arp.v
VERILOG_SOURCES += $(TOPDIR)/sync.v

TOPLEVEL = arp

COMPILE_ARGS += -Wno-WIDTHEXPAND -Wno-WIDTHTRUNC -Wno-CASEINCOMPLETE

GPI_IMPL := vpi

export TOPLEVEL_LANG
MODULE=test_arp

EXTRA_ARGS += --trace --trace-depth 2

include $(shell cocotb-config --makefiles)/Makefile.sim
