## Ethernet / UDP-IP protocol stack

set_global_assignment -name VERILOG_FILE ../../rtl/ethernet/network.v
set_global_assignment -name VERILOG_FILE ../../rtl/ethernet/rgmii_recv.v
set_global_assignment -name VERILOG_FILE ../../rtl/ethernet/rgmii_send.v
set_global_assignment -name VERILOG_FILE ../../rtl/ethernet/ddio_in.v
set_global_assignment -name VERILOG_FILE ../../rtl/ethernet/ddio_out.v
set_global_assignment -name VERILOG_FILE ../../rtl/ethernet/mac_recv.v
set_global_assignment -name VERILOG_FILE ../../rtl/ethernet/mac_send.v
set_global_assignment -name VERILOG_FILE ../../rtl/ethernet/ip_recv.v
set_global_assignment -name VERILOG_FILE ../../rtl/ethernet/ip_send.v
set_global_assignment -name VERILOG_FILE ../../rtl/ethernet/udp_recv.v
set_global_assignment -name VERILOG_FILE ../../rtl/ethernet/udp_send.v
set_global_assignment -name VERILOG_FILE ../../rtl/ethernet/arp.v
set_global_assignment -name VERILOG_FILE ../../rtl/ethernet/icmp.v
set_global_assignment -name VERILOG_FILE ../../rtl/ethernet/icmp_fifo.v
set_global_assignment -name VERILOG_FILE ../../rtl/ethernet/dhcp.v
set_global_assignment -name VERILOG_FILE ../../rtl/ethernet/phy_cfg.v
set_global_assignment -name VERILOG_FILE ../../rtl/ethernet/mdio.v
set_global_assignment -name VERILOG_FILE ../../rtl/ethernet/crc32.v
