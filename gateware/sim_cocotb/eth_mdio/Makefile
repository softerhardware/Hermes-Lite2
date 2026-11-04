SIM ?= verilator
TOPLEVEL_LANG ?= verilog
PWD=$(shell pwd)
TOPDIR=$(PWD)/../../rtl

#DUT (wrapper exposes the inout mdio_pin alongside a PHY-side driver)
VERILOG_SOURCES += $(TOPDIR)/ethernet/mdio.v
VERILOG_SOURCES += tb_mdio.v

TOPLEVEL = tb_mdio

COMPILE_ARGS += -Wno-WIDTHEXPAND -Wno-WIDTHTRUNC

GPI_IMPL := vpi

export TOPLEVEL_LANG
MODULE=test_mdio

EXTRA_ARGS += --trace --trace-depth 2

include $(shell cocotb-config --makefiles)/Makefile.sim
