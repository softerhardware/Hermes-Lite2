Hermes-Lite 2.x Gateware
========================

## 20201107_72p5 Release

This is an experimental release for testing changes to CWX and the new band voltage select for PA. 

 * FAN PWM switchable to be band voltage select for external PA. Enabled and disabled via dither. Thanks to Mi0BOT.
 * CWX accepts preTX signal on I[3]. This should only be used to engage TX earlier than possible with TX buffer latency for external peripherals.
 * CWX made safer to avoid some possible bugs.
 * Watchdog timeout increased to \~10 seconds.
 *  

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





