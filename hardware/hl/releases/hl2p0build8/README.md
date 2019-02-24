Hermes-Lite 2.0 Build8 Release
==============================


February 17, 2019. This directory contains all files necessary to fabricate the Hermes-Lite 2.0build8 release.

# Files

 * bom.standard.pdf - BOM in standard format for DIY assembly
 * ibom.html - Interactive BOM to help with DIY assembly, open with firefox ibom.html
 * bom.assembly.pdf - BOM organization as requested by assembly house
 * bom.assembly.xlsx - BOM type and organization as requested by assembly house
 * hermeslite.pdf - Schematic for this release
 * pcb/* - Gerber files names as requested by assembly house
 * pos/* - Position information to aid assembly, not guaranteed to be accurate for parts with more than two pins
 * stencil/* - Top and bottom stencil for DIY assembly

# Changes

## PCB

 * X2 footprint altered to only accept the smaller official oscillator to mitigate problems with heating large X2 pads.
 * Silkscreen updated to build8 and 2019 copyright.
 * Footprints updated with proper paste information to generate stencils.
 * Updated to KiCAD 5.02. Gerber files were compared carefully with older gerber files to make sure no errors were introduced.
 * Reverted back to single version with holes to manually solder hidden thermal pads. There proved to be no advantage to not have these.
 * Added pin 1 identifier for JTAG connectxor CN1 to silkscreen
 * Added two through hole pads connected to and near the main external power input to facilitate adding a switch

## BOM

 * R117, R118, R119 are now included. This solves problems with relay chatter.
 * DB7 is now included. This makes the unit ready to be used with a N2ADR companion filter board and facilitates testing. Those who do not want this may have to remove this male 20 by 1 connector.
 * K2 and T3 are now included for assembly. This completes the unit and makes it possible to test all functionality.
 * Switched power supply inductors to shielded. This reduces minor switching power supply spurs.
 * For many parts with no substitution allowed, there are now multiple alternate manufacturer part numbers. This provides more freedom to the assembly house.
