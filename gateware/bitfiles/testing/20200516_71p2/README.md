Hermes-Lite 2.x Gateware
========================

## 20200516_71p2 Release

 * Receive only hl2b5up_9rx release with 9 receivers. This is meant for data skimming. The final FIR filters are removed. Only 384kHz bandwidth will return meaningful data. Since only CIC filters are present, you will see droop at either extreme of the receiver bandwidth. Also, some aliasing at the extreme ends may occur. But there is still almost 200kHz of usable bandwidth in the center. This enough to cover most data frequencies within a band.

 * Pins used for fast LNA updates have tighter constraints. This is to address reports of LNA changes not occurring.
 * Support for TX/RX antenna selection using extra bit 7 on N2ADR board. 0x00	[13]	Control MCP23008 GP7 (I2C device on N2ADR filter board) (0=TX antenna, 1=RX antenna)
 * CW via external key can now be engaged even if in PTT mode.
 * CW via external key forces LNA to lowest gain if separate TX gain setting is not set.


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





