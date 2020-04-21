Hermes-Lite 2.x Gateware
========================

## 20200329_70p4 Release

 * Support for factory and application images in EEPROM. This adds more protection for bad gateware updates. See the [gateware wiki page](https://github.com/softerhardware/Hermes-Lite2/wiki/Updating-Gateware) for more details.
 * Support for separate TX and RX LNA gain settings. This helps with PureSignal and CW use. See the [protocol wiki page](https://github.com/softerhardware/Hermes-Lite2/wiki/Protocol) for more details, in particular address 0x0e.

### File Key

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





