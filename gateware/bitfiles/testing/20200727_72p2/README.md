Hermes-Lite 2.x Gateware
========================

## 20200712_72p2 Release

This is an experimental release.

 * hl2b5up
   * Fixed problem with extra byte in packets. For people with any DHCP issues, please report if this make a difference for you.
   * Fixed clock domain crossing issue with ARP which caused it to be sent only after the first ARP request.
   * Switched to handshake clock domain crossing for many IP and MAC transfers. This saves hundreds of registers and permits a 10 RX gateware variant.
   * Added extended response for discovery. See the wiki protocol page.
   * Opened port 1025. Right now port 1025 should respond to discover requests.
  * variants/hl2b5up_cicrx
   * 10 receive-only gateware variant. Reductions in the network code freed resources for the 10th receiver. This gateware produces correct results only when run at 384kHz. There is only a CIC filter so you will see droop on the edges of the spectrum. For best results, center the receiver on the frequencies you wish to receive. There is about 100kHz of usable spectrum. This is intended for skimming, primarily with SparkSDR.

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





