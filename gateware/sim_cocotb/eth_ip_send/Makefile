SIM ?= verilator
TOPLEVEL_LANG ?= verilog
PWD=$(shell pwd)
TOPDIR=$(PWD)/../../rtl

#DUT
VERILOG_SOURCES += $(TOPDIR)/ethernet/ip_send.v

TOPLEVEL = ip_send

COMPILE_ARGS += -Wno-WIDTHEXPAND -Wno-WIDTHTRUNC

GPI_IMPL := vpi

export TOPLEVEL_LANG
MODULE=test_ip_send

EXTRA_ARGS += --trace --trace-depth 2

include $(shell cocotb-config --makefiles)/Makefile.sim
