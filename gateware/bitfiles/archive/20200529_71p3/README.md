Hermes-Lite 2.x Gateware
========================

## 20200529_71p3 Release

 * Fixed [Undocumented behaviour when ADDR 0x0 DATA 0x7 is set](https://github.com/softerhardware/Hermes-Lite2/issues/145)
 * Fixed [No Power on TX if First from CW](https://github.com/softerhardware/Hermes-Lite2/issues/144)
 * Added capability to reset and synchronize Versa clocks. More details to come.


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





