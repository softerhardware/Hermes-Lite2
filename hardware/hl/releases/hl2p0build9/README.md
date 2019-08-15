Hermes-Lite 2.0 Build9 Release
==============================


August 15, 2019. This directory contains all files necessary to fabricate the Hermes-Lite 2.0build9 release.

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

 * CL1 and CL2 inset to match N2ADR board. Some rework in that area. These components are optional for external clocking.
 * Silkscreen updated to build9.
 * Opensource hardware logo added back to silkscreen.
 * Location of R13 and J2 swapped.
 * Location of R16 and J11 swapped.

## BOM

 * R13 and R16 now included and 10K. This allows FPGA control of switching frequency.
 * HS2 and HS7 added. These are Raspberry Pi heatsinks used on U2 and U7.
 * C84 increased to 390pF for better high frequency power output.
 * W1 wire type changed to no substitutions allowed. This must be "PFTE Teflon Silver Plated Wire 30AWG" commonly found on AliExpress. Lead length of T3 must be 3mm or less. Distance between top of PCB and bottom of T3 must be 3mm or less.
 
