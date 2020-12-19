Hermes-Lite 2.x Gateware
========================

## 20201121_72p6 Release

This is an experimental release with added debug instrumentation to look at issues with relay clicks and TX buffer over/underflows. It is intended for software developers and technical people interested in tuning and measuring HL2 network performance. The extra debug instrumentation will only be enabled in this release.  

 * Start your HL2 software and set to one receiver at 384kHz. A higher sample rate and larger number of receivers will send more debug packets per second for higher debug resolution but larger debug file sizes.
 * In Hermes-Lite2/software/hermeslite, use "python3 -i debug.py" to start the debug tool in an interactive Python shell.
 * When ready to make measurements, enter "d.vcd()"
 * Enable TX via the HL2 software, usually via tune for 1 second on.
 * In the python terminal, enter "ctrl-c" to stop the debug capture.
 * This debug tool generates a value change dump or debug.vcd file. View it using [GTKwave](http://gtkwave.sourceforge.net/) "gtkwave debug.vcd debug.gtkw"
 * You can start debug capture again in the python terminal with "d.vcd()"

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





