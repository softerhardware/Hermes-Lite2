Hermes-Lite 2.x Gateware
========================

## 20200803_72p3 Release

This is an experimental release.

 * hl2b5up
   * Adds full command and control support including responses for port 1025. See [hermeslite.py](https://github.com/softerhardware/Hermes-Lite2/tree/master/software/hermeslite).
   * Increases TX buffer size to 4096 IQ entries, like 72p1 or twice the default.


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





