Hermes-Lite 2.x Gateware
========================

## 20200210_69p1 Release

 This version identifies as revision 69.1. Changes in this version are listed below. See the [updating gateware wiki page](https://github.com/softerhardware/Hermes-Lite2/wiki/Updating-Gateware) for more details. As this is a minor testing release, only gateware for the Hermes-Lite 2.0 build5 and later is released.

 * CWX is enabled for keyboard CW from PowerSDR. See this [this video](https://youtu.be/SyYBzUeinmw). The second receiver set to not mute during TX is used for sidetone. Please share if you now of a way to do this with a single receiver. Since a keyer is not required for this feature, there is no keyer in this gateware. The openhpsdr keyer is now an option that can be enabled in the github code if desired.

 * TX buffer is tuned for lower latency and (hopefully) better compatibility with software that sends lengthy 20 ms of samples at a timer.

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





