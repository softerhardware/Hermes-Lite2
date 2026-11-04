SIM ?= verilator
TOPLEVEL_LANG ?= verilog
PWD=$(shell pwd)
TOPDIR=$(PWD)/../../rtl

#DUT
VERILOG_SOURCES += $(TOPDIR)/ethernet/udp_recv.v

TOPLEVEL = udp_recv

COMPILE_ARGS += -Wno-WIDTHEXPAND -Wno-WIDTHTRUNC -Wno-CASEINCOMPLETE

GPI_IMPL := vpi

export TOPLEVEL_LANG
MODULE=test_udp_recv

EXTRA_ARGS += --trace --trace-depth 2

include $(shell cocotb-config --makefiles)/Makefile.sim
