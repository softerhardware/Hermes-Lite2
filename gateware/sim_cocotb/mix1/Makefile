SIM ?= verilator
TOPLEVEL_LANG ?= verilog
PWD=$(shell pwd)
TOPDIR=$(PWD)/../../rtl

#DUT
VERILOG_SOURCES += tb_mix1.sv
VERILOG_SOURCES += $(TOPDIR)/nco/mix1.v
VERILOG_SOURCES += $(TOPDIR)/nco/nco1.v
VERILOG_SOURCES += $(TOPDIR)/nco/sincos.v
VERILOG_SOURCES += $(TOPDIR)/nco/coarserom.v
VERILOG_SOURCES += $(TOPDIR)/nco/finerom.v
VERILOG_SOURCES += $(TOPDIR)/primitives/sim/multipliers.v

TOPLEVEL = tb_mix1

# mix1.v uses an undeclared implicit net clk_2x (see tb_mix1.sv), which
# Verilator flags with IMPLICIT; the wrapper defines and ties it to clk.
COMPILE_ARGS += -Wno-IMPLICIT

GPI_IMPL := vpi

export TOPLEVEL_LANG
MODULE=test_mix1

# coarserom/finerom use $readmemb with relative paths, so the ROM
# images must exist in the simulator's working directory.
ROM_IMAGES = sincos_coarse.txt sin_fine.txt

%.txt: $(TOPDIR)/nco/%.txt
	cp $< $@

CUSTOM_SIM_DEPS += $(ROM_IMAGES)

EXTRA_ARGS += --trace --trace-depth 2

include $(shell cocotb-config --makefiles)/Makefile.sim
