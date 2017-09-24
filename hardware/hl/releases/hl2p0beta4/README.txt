# Hermes-Lite2 Beta4 Release

September 23, 2017

This directory contains all files necessary to fabricate the Hermes-Lite 2.0beta4 release. See the beta3 [README.txt](https://github.com/softerhardware/Hermes-Lite2/tree/master/hardware/hl/releases/hl2p0beta3) for details on organizing an assembled group buy.

## Files

* hermeslite2beta4.zip - Full submission for PCB and PCB assembly
* hermeslite2beta4pcb.zip - Only gerber files for PCB fabrication
* bom.assembly.pdf - BOM used for assembly bids
* bom.standard.pdf - BOM used for hand builds
* hermeslite.pdf - Schematic

## Changes from Hermes-Lite2 Beta3

* R55 now 120 Ohms to not overdrive PA.
* To adjust LED bright and connect to 3.3V supply, R30,R31,R32,R33 now DNI, R133,R134 now 270Ohm, R131,R132 now 10K.
* Added 4.7K R95 and R101 to properly switch PE4259.
* Added FB22 to reduce noise on slow ADC U13.
* Converted B118 to Q6 power decoupling and moved near Q6 to reduce noise on temperature readings.
* To increase accuracy and range, temperature and current analog signals are routed directly to slow ADC U13. R111 converted to J30 JNC. B95 to C91 100pF. R108 to 270Ohm. B93 to C90 100pF. R109 to 1K.
* As U18 will perform better for FWD/REV power on filter board, U18 and surrounding components now DNI. Can still be included if desired. R104,B67,R103,D10,R113,R115,B117,R114,D11,R116,U18,B96 now DNI.
* Since B62152A4X30 core for T3 may conduct if enamel coating of wire degrades, FEP or PFTE wire of AWG24 is specified on schematic.
* Added vias to bypass ain1 and ain2 on U18 opamp.
* B106 moved slightly to make more room for nut and bolt near LDMOS devices.
* Assembly BOM specifies no substitutions for filter caps to avoid 10M power drop.
* Better tie off for unused op amps in U18.
* Added C92 22uF right at T3 for better Vpa filtering.
* Added 6th hole to SMA footprint to support setback right angle 3-pin 0.1 inch connector.
* Nudged CN12 closer to CN11 to align exactly to 0.1 inch grid.


