Hermes-Lite 2.x Gateware
========================

## 20200803_72p4 Release

This is an experimental release for testing two HL2s with synchronized coherent receivers.

 * See the [synchronization process](https://github.com/softerhardware/Hermes-Lite2/wiki/External-Clocks#synchronization-process) wiki pages for details on synchronizing two HL2s. Use synchronize_radios from the latest [hermeslite.py](https://github.com/softerhardware/Hermes-Lite2/tree/master/software/hermeslite) to synchronize RX1 radio1 with RX1 radio2 (sent to host computer as RX2 of radio1).
 * Normal functionality of pins 1-4 of DB1 are disabled. Instead, these are used for debug to confirm various signals inside the HL2 are truly synchronized. For example, after synchronizing two HL2, pin1 of both units should show an identical synchronized pulse on an oscilloscope.
 * Adds capability to turn watchdog off via run/stop command or standard protocol register. See the [protocol](https://github.com/softerhardware/Hermes-Lite2/wiki/Protocol) wiki page for details.

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





