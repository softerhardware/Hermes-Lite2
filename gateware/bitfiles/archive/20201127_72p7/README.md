Hermes-Lite 2.x Gateware
========================

## 20201127_72p7 Release

This is an experimental 10 receiver CIC-only release. It runs at only 192kHz. The bandwidth is halved from past cicrx releases to reduce CPU and network loads. It is intended to be used for 10 band skimming with SparkSDR. Only install it if you wish to skim many bands with SparkSDR. There is no transmit in this gateware.

### Notes

See the [gateware](https://github.com/softerhardware/Hermes-Lite2/wiki/Updating-Gateware) wiki page for more details on how to update the gateware.

Most people will use the file root and suffix in bold below, hl2b5up_main.rbf, for programming over ethernet.

* hl2b2 - Hermes-Lite 2.0 beta2
* hl2b3to4 - Hermes-Lite 2.0 beta3 or beta4
* **hl2b5up - Hermes-Lite 2.0 build5 and later**
* hl2b5up_6rx - Hermes-Lite 2.0 build5 and later, 6 RX, no TX

* .jic - Nonvolatile EEPROM programming with Quartus
* **.rbf - Raw binary format for programming over ethernet using openhpsdr protocol 1**
* .sof - Volatile FPGA-only programming with Quartus
* jic.jam - Nonvolatile EEPROM programming with JAM/STAPL player
* sof.jam - Volatile FPGA-only programming with JAM/STAPL player
* .svf - Volatile FPGA-only programming with urjtag or openocd 





