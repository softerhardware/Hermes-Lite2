SIM ?= verilator
TOPLEVEL_LANG ?= verilog
PWD=$(shell pwd)
TOPDIR=$(PWD)/../../rtl

#DUT: the complete network module, exercised through its PHY pins
VERILOG_SOURCES += $(TOPDIR)/sync.v
VERILOG_SOURCES += $(TOPDIR)/cdc_sync.v
VERILOG_SOURCES += $(TOPDIR)/ethernet/crc32.v
VERILOG_SOURCES += $(TOPDIR)/ethernet/mdio.v
VERILOG_SOURCES += $(TOPDIR)/ethernet/phy_cfg.v
VERILOG_SOURCES += $(TOPDIR)/ethernet/dhcp.v
VERILOG_SOURCES += $(TOPDIR)/ethernet/arp.v
VERILOG_SOURCES += $(TOPDIR)/ethernet/icmp.v
VERILOG_SOURCES += $(TOPDIR)/ethernet/icmp_fifo.v
# icmp_fifo is a wrapper over the shared stream_fifo shell
VERILOG_SOURCES += $(TOPDIR)/fifos.v
VERILOG_SOURCES += $(TOPDIR)/ethernet/ip_recv.v
VERILOG_SOURCES += $(TOPDIR)/ethernet/ip_send.v
VERILOG_SOURCES += $(TOPDIR)/ethernet/udp_recv.v
VERILOG_SOURCES += $(TOPDIR)/ethernet/udp_send.v
VERILOG_SOURCES += $(TOPDIR)/ethernet/mac_recv.v
VERILOG_SOURCES += $(TOPDIR)/ethernet/mac_send.v
VERILOG_SOURCES += $(TOPDIR)/ethernet/rgmii_recv.v
VERILOG_SOURCES += $(TOPDIR)/ethernet/rgmii_send.v
VERILOG_SOURCES += $(TOPDIR)/ethernet/ddio_in.v
VERILOG_SOURCES += $(TOPDIR)/ethernet/ddio_out.v
VERILOG_SOURCES += $(TOPDIR)/ethernet/network.v
# Altera megafunction simulation library (altddio_*, dcfifo)
VERILOG_SOURCES += /home/shaynal/altera_lite/25.1std/quartus/eda/sim_lib/altera_mf.v
# wrapper + MDIO PHY model
VERILOG_SOURCES += $(PWD)/tb_network.v

TOPLEVEL = tb_network

# --timing for the vendor models; the usual width/case lint waivers of this RTL
COMPILE_ARGS += --timing -Wno-fatal -Wno-PROCASSWIRE -Wno-CASEINCOMPLETE \
                -Wno-WIDTHEXPAND -Wno-WIDTHTRUNC

GPI_IMPL := vpi

export TOPLEVEL_LANG
MODULE=test_network

include $(shell cocotb-config --makefiles)/Makefile.sim
