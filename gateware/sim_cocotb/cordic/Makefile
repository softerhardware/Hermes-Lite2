SIM ?= verilator
TOPLEVEL_LANG ?= verilog
PWD=$(shell pwd)
TOPDIR=$(PWD)/../../rtl

#DUT
VERILOG_SOURCES += tb_cordic.sv
VERILOG_SOURCES += $(TOPDIR)/radio_openhpsdr1/cordic.v

TOPLEVEL = tb_cordic

# cordic.v has benign width warnings on `frequency == 1'b0` / `phase <= 1'b0`
COMPILE_ARGS += -Wno-WIDTHEXPAND -Wno-WIDTHTRUNC

GPI_IMPL := vpi

export TOPLEVEL_LANG
MODULE=test_cordic

EXTRA_ARGS += --trace --trace-depth 2

include $(shell cocotb-config --makefiles)/Makefile.sim
