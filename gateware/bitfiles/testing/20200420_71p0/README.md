Hermes-Lite 2.x Gateware
========================

## 20200420_71p0 Release

 * Fix for CWX accumulating data in the TX buffer.
 * Fan now will turn off if low temperature is reached even if radio is not connected to software.
 * Temperature at which fan turns on increased to 37C, off at 35C.
 * Version incremented to 71 to facilitate testing of factory/application gateware slots. Note that if you haven't programmed anything in slot 2 yet, then you will have to manually power cycle the HL2 to see the first image in slot 2. You can program the last release, version 70, into slot 2, power cycle, and then program this new version 71 to check that no reboot is required once a valid gateware image is in slot 2.
 * Only build5 gateware is released as this is a testing release with another version coming soon.

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





