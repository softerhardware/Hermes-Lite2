Hermes-Lite 2.x Gateware
========================

## 20191028 Release

 This version identifies as revision 68. Changes in this version are listed below.

 * TX FIFO statistics are sent to the host PC. See the [wiki](https://github.com/softerhardware/Hermes-Lite2/wiki/Protocol).

 * UART frequency data compatible with the HR50 is sent on DB1 pin 3. See [wiki](https://github.com/softerhardware/Hermes-Lite2/wiki/IO) for details. Thanks to Taka JI1UDD for this RTL.

 * ATU interface compatible with ICOM AH-4. See [wiki](https://github.com/softerhardware/Hermes-Lite2/wiki/IO) for details. Thanks to Taka JI1UDD for this RTL.

 * A 6 receiver receive only hl2b5up gateware is included.

 * Regular releases for the smaller FPGA hl2b5upce15 will not be made. These are available upon request if needed.

 * Refactored the RTL to have a toplevel wrapper. Now there is a hermeslite_core and various toplevel hermeslite wrappers. This allows the core to have a superset of possible IO. The wrapper allows the core to connect a subset of the IO to the desired pins. This is to make it easier to support gateware variants with different IO assignments. See [hl2b5up_main](https://github.com/softerhardware/Hermes-Lite2/tree/master/gateware/variants/hl2b2_main) and [hl2b5up_6rx](https://github.com/softerhardware/Hermes-Lite2/tree/master/gateware/variants/hl2b2_6rx) for examples of variants.

 * The toplevel wrappers now uses more parameters to turn optional functionality on and off. This is an example foir how to add custom functionality. See extpa and exttuner in [control.v](https://github.com/softerhardware/Hermes-Lite2/blob/master/gateware/rtl/control.v).

 * Switched wide band data to 16-bit and added discovery reply status to indicate this as specified on the protocol wiki page.

 * Read support for i2c devices added. See the [wiki](https://github.com/softerhardware/Hermes-Lite2/wiki/Protocol#read-eeprom) for details.

 * Support for MCP4662 to store data as described [here](https://github.com/softerhardware/Hermes-Lite2/wiki/Protocol#configuration-eeprom).

 * Discovery includes EEPROM data as described [here](https://github.com/softerhardware/Hermes-Lite2/wiki/Protocol#metis-discovery-reply). Note that there was a slight change and the bias values are not sent in the discovery. This is because they are not required to be read from the EERPOM for any gateware purpose. Now that generic i2c read support exists, software can read the bias values through the i2c interface.

 * Grounding both tip and ring of the PTT/CW connector will cause EEPROM data to be ignored. This must occur when the unit is powered on and held for about 50ms. This can be done with a standard audio extension cable with tin foil on all contacts at one end.



### File Key

* hl2b2 - Hermes-Lite 2.0 beta2
* hl2b3to4 - Hermes-Lite 2.0 beta3 or beta4
* hl2b5up - Hermes-Lite 2.0 build5 and later
* hl2b5up_6rx - Hermes-Lite 2.0 build5 and later, 6 RX, no TX

* .jic - Nonvolatile EEPROM programming with Quartus
* .rbf - Raw binary format for programming over ethernet using openhpsdr protocol 1
* .sof - Volatile FPGA-only programming with Quartus
* jic.jam - Nonvolatile EEPROM programming with JAM/STAPL player
* sof.jam - Volatile FPGA-only programming with JAM/STAPL player
* .svf - Volatile FPGA-only programming with urjtag or openocd 





