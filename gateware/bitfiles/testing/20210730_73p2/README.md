Hermes-Lite 2.x Gateware
========================

## 20210730_73p2 Testing Release

This is a testing release for these changes:

* Both KSZ9021 and KSZ9031 ethernet phys are support at 1Gbps and 100Mbps. LED D2 blinks twice as fast or about 3 times a second if a KSZ9021 is detected.

* This release fixes a bug in the features below. The features below are only enabled with PTT hang time is set to the maximum value, 31ms.
  * When the HL2 enters the error state of empty TX buffer, the HL2 remains in TX instead of going to RX. This inserts silent gaps in the TX signal.
  * When the HL2 receives a PTT off message from software, it immediately stops sending and does not send any remaining data in the TX buffer. This breaks transmit and receive stream accuracy useful for full duplex, but may avoid audio pops when a user hears the last bit of data that is transmitted. 

* Update the ATU functionality to match the protocol wiki page. Now the ATU can be put into bypass mode. Quisk implements this newer protocol


See the [gateware](https://github.com/softerhardware/Hermes-Lite2/wiki/Updating-Gateware) wiki page for more details on how to update the gateware. Most people will use the file root and suffix in bold below, hl2b5up_main.rbf, for programming over ethernet.

### Variants

* **hl2b5up_main - Main gateware for Hermes-Lite 2.0 build5 and later** Includes all programming file types. This is what most people will use. Use the hl2b5up_main.rbf file for network update with Quisk, SparkSDR or hermeslite.py.
* variants/hl2b3to4_main - Main gateware for Hermes-Lite 2.0 beta3 or beta4. Includes all programming file types.
* variants/hl2b2_main - Main gateware for Hermes-Lite 2.0 beta2. Includes all programming file types.
* variants/hl2b5_cicrx - 10RX only gateware for Hermes-Lite 2.0 build5 and later. This only supports 192kHz receivers. This uses only CIC filters and consequently only about 70kHz of the spectrum is usable. This is for multiband skimming.
* variants/hl2b3to4_cicrx - 10RX only gateware for Hermes-Lite 2.0 beta3 or beta4. This only supports 192kHz receivers. This uses only CIC filters and consequently only about 70kHz of the spectrum is usable. This is for multiband skimming.
* variants/hl2b5up_ak4951v3 - AK4951V3 companion board gateware for Hermes-Lite 2. build5 and later. This only support 3 receivers due to the increase in TX buffer size to support longer latencies.


### File Types

* **.rbf - Raw binary format for programming over ethernet using openhpsdr protocol 1**
* .jic - Nonvolatile EEPROM programming with Quartus
* .sof - Volatile FPGA-only programming with Quartus
* jic.jam - Nonvolatile EEPROM programming with JAM/STAPL player as used in the Raspberry Pi setup image
* sof.jam - Volatile FPGA-only programming with JAM/STAPL player as used in the Raspberry Pi setup image
* .svf - Volatile FPGA-only programming with urjtag or openocd

If your HL2 does not yet have gateware which supports network gateware updates and only a .rbf file is provided for your desired variant, first update to the main gateware and then update to your variant.




