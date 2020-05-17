Hermes-Lite 2.x Gateware
========================

## 20200516_71p2 Release

 * Receive only hl2b5up_9rx release with 9 receivers. This is meant for data skimming. The final FIR filters are removed. Only 384kHz bandwidth will return meaningful data. Since only CIC filters are present, you will see droop at either extreme of the receiver bandwidth. Also, some aliasing at the extreme ends may occur. But there is still almost 200kHz of usable bandwidth in the center. This enough to cover most data frequencies within a band.


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





