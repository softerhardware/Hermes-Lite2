Hermes-Lite 2.x Gateware
========================

## 20200119_69p0 Release

 This version identifies as revision 69.0. Changes in this version are listed below. See the [updating gateware wiki page](https://github.com/softerhardware/Hermes-Lite2/wiki/Updating-Gateware) for more details.

 * Bug fixed where PureSignal was not on proper receiver for 4 receiver gateware. See the [PureSignal wiki page](https://github.com/softerhardware/Hermes-Lite2/wiki/PureSignal) for details on how to setup and use PureSignal with the Hermes-Lite 2.

 * Fan PWM implemented. Modes are based on temperature:
  * Low speed turns on at 35C, off at 30C
  * Medium speed turns on at 40C, back to low speed at 35C
  * Full speed turns on at 45C, back to medium speed at 40C
  * TX disabled at 55C, enabled at 50C or by power cycling the unit

 * IO assignment updated so that all new IO signals connected to DB1. See the [IO wiki page](https://github.com/softerhardware/Hermes-Lite2/wiki/IO). Beta3to4 and beta2 have different IO connections but UART and fan are implemented for these builds. See the variant Verilog files hermeslite.v for pin assignments.

 * The [metis discovery reply](https://github.com/softerhardware/Hermes-Lite2/wiki/Protocol#metis-discovery-reply) now includes a variant ID to identify if this board is a hl2b5up, hl2b3and4 or hl2b2.


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





