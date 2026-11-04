SIM ?= verilator
TOPLEVEL_LANG ?= verilog
PWD=$(shell pwd)
TOPDIR=$(PWD)/../../rtl

#DUT
VERILOG_SOURCES += $(TOPDIR)/ethernet/mac_send.v
VERILOG_SOURCES += $(TOPDIR)/ethernet/crc32.v

TOPLEVEL = mac_send

# the Metis code relies on implicit width extension in places
COMPILE_ARGS += -Wno-WIDTHEXPAND -Wno-WIDTHTRUNC

GPI_IMPL := vpi

export TOPLEVEL_LANG
MODULE=test_mac_send

include $(shell cocotb-config --makefiles)/Makefile.sim
