Hermes-Lite 2.x Gateware
========================

## 20191013 Release

 This version identifies as revision 68. Changes in this version are listed below.

 * TX FIFO statistics are sent to the host PC. See the wiki protocol page.

 * UART frequency data compatible with the H50 is sent on DB1 pin 3. Thanks to Taka for this RTL.

 * A 6 receiver receive only hl2b5up gateware is included.

 * Regular releases for the beta2 (hl2b2) and smaller FPGA hl2b5upce15 will not be made. These are available upon request if needed.


### File Key

* hl2b3to4 - Hermes-Lite 2.0 beta3 or beta4
* hl2b5up - Hermes-Lite 2.0 build5 and later
* hl2b5up_6rx - Hermes-Lite 2.0 build5 and later, 6 RX, no TX

* .jic - Nonvolatile EEPROM programming with Quartus
* .rbf - Raw binary format for programming over ethernet using openhpsdr protocol 1
* .sof - Volatile FPGA-only programming with Quartus
* jic.jam - Nonvolatile EEPROM programming with JAM/STAPL player
* sof.jam - Volatile FPGA-only programming with JAM/STAPL player
* .svf - Volatile FPGA-only programming with urjtag or openocd 





