Hermes-Lite 2.x Gateware
========================

## 20200712_72p1 Release

This is an experimental release.

 * External TX inhibit has been disabled. Please test for relay chattering. This is to test if the external TX inhibit (R117 problem) is the cause for current relay chattering.
 * TX buffer size is doubled. Before the buffer size was 42ms. Now it is 85ms.

There are two protocol settings which affect how the TX buffer is used. First, the TX buffer latency at address 0x17 specifies how long the FPGA should wait in milliseconds after the first TX IQ sample is seen before starting transmit. The TX buffer always starts empty and this allows the TX buffer to fill to provide N ms of buffer time to accommodate UDP arrival jitter. Relays are engaged as soon as the first TX IQ sample is seen. So this should be set to at least 6ms to allow the relays to settle before real TX data is sent to the DAC. In the stock gateware, this latency can be adjusted from 0 to 31ms in increments of 1ms and defaults to 10ms. In this experimental gateware with doubled TX buffer sizes, TX buffer latency adjusts from 0 to 62 ms in increments of 2ms and defaults to 40ms.

If the TX buffer empties, the FPGA will remain in transmit (relays engaged) for CW or PTT hang time depending on if TX was initiated by CW or PTT, either software or local external. To prevent the relay from disengaging during TX, increase PTT hang time at address 0x17. The default in the stock gateware is 4ms. This can be set from 0 to 31ms. In this experimental gateware, the default is 6 ms and it can be set from 0 to 62ms in increments of 2ms. Note that during hang, TX and the relays are engaged but zeros are set to the DAC so you will hear stuttering in the TX signal but should not hear relay chatter.



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





