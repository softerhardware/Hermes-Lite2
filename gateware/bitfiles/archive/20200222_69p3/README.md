Hermes-Lite 2.x Gateware
========================

## 20200222_69p3 Release

 * Control of TX buffer latencies added. See command addr 0x17. This is outside of the defined openhpsdr protocol1 and is intended for software that specifically supports the HL2. These latencies are set to good default values for software that does not wish to manage the TX buffer.
  * The default TX latency is 10ms. It should be at least 6ms to allow the relays to settle before TX signal starts. It can be set from 0 to 32ms.
  * There is also a PTT hang time. This specifies how long the HL2 stays in transmit after the buffer empties or PTT is released. The purpose of this hang time is to prevent the HL2 from leaving transmit, resulting in relay chatter, and starting the whole transmit process again if the TX buffer empties when set to very low latencies. The default is 4ms.

 * Fan control takes multiple readings to avoid spurious readings during transmit which may cause the fan to start unexpectedly.

 * CW key debounce no longer adds latency. The key status returned to the PC also has no added latency.

 * CW and CWX FSM are unified so that latencies and operation are the same for both modes. The new TX buffer latency register is what controls the latency for CW, CWX and IQ data. For external CW, software may wish to set this latency to 6ms, the lowest allowed by the TR relays.

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





