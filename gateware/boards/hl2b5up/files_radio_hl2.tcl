## Radio DSP: NCO/mixers, receive chain (CIC/varcic/FIR), transmit chain
## (FIR interpolation, CIC interpolation, CORDIC), VNA scanner and the
## optional EER envelope blocks (used by LRDATA=2 builds).
##
## Note: the receiver top (receiver_nco.v / receiver_4000.v /
## receiver_ciconly.v) is selected per-variant in the variant .qsf.

set_global_assignment -name VERILOG_FILE ../../rtl/radio_openhpsdr1/radio.v

# Receive DSP
set_global_assignment -name VERILOG_FILE ../../rtl/radio_openhpsdr1/cic.v
set_global_assignment -name VERILOG_FILE ../../rtl/radio_openhpsdr1/cic_comb.v
set_global_assignment -name VERILOG_FILE ../../rtl/radio_openhpsdr1/cic_integrator.v
set_global_assignment -name VERILOG_FILE ../../rtl/radio_openhpsdr1/varcic.v
set_global_assignment -name VERILOG_FILE ../../rtl/radio_openhpsdr1/firfilt.v
set_global_assignment -name VERILOG_FILE ../../rtl/radio_openhpsdr1/firram36.v
set_global_assignment -name VERILOG_FILE ../../rtl/radio_openhpsdr1/firrom/firromH.v
set_global_assignment -name VERILOG_FILE ../../rtl/radio_openhpsdr1/firrom/firromI_1024.v
set_global_assignment -name VERILOG_FILE ../../rtl/radio_openhpsdr1/vna_scanner.v

# Transmit DSP
set_global_assignment -name VERILOG_FILE ../../rtl/radio_openhpsdr1/cpl_cordic.v
set_global_assignment -name VERILOG_FILE ../../rtl/radio_openhpsdr1/FirInterp8_1024.v
set_global_assignment -name VERILOG_FILE ../../rtl/radio_openhpsdr1/firram36I_1024.v
set_global_assignment -name VERILOG_FILE ../../rtl/radio_openhpsdr1/CicInterpM5.v

# Transmit EER / envelope option (LRDATA=2)
set_global_assignment -name VERILOG_FILE ../../rtl/radio_openhpsdr1/FirInterp5_1025_EER.v
set_global_assignment -name VERILOG_FILE ../../rtl/radio_openhpsdr1/firram36I_205.v
set_global_assignment -name VERILOG_FILE ../../rtl/radio_openhpsdr1/firrom/firrom1_1025.v
set_global_assignment -name VERILOG_FILE ../../rtl/radio_openhpsdr1/counter.v
set_global_assignment -name VERILOG_FILE ../../rtl/radio_openhpsdr1/square.v
set_global_assignment -name VERILOG_FILE ../../rtl/radio_openhpsdr1/sqroot.v

# NCO
set_global_assignment -name VERILOG_FILE ../../rtl/nco/nco2.v
set_global_assignment -name VERILOG_FILE ../../rtl/nco/mix2.v
set_global_assignment -name VERILOG_FILE ../../rtl/nco/sincos.v
set_global_assignment -name VERILOG_FILE ../../rtl/nco/coarserom.v
set_global_assignment -name VERILOG_FILE ../../rtl/nco/finerom.v
