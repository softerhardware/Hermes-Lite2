N2ADR Companion Filters E5 Build9 Release
=========================================


August 17, 2019. This directory contains all files necessary to fabricate the N2ADR companion filters board for the Hermes-Lite 2.0.

# Files

 * bom.diy.pdf - BOM in standard format for DIY assembly
 * ibom.html - Interactive BOM to help with DIY assembly, open with firefox ibom.html
 * bom.assembly.pdf - BOM organization as requested by assembly house
 * bom.assembly.xlsx - BOM type and organization as requested by assembly house
 * n2adr.pdf - Schematic for this release
 * pcb/* - Gerber files names as requested by assembly house
 * pos/* - Position information to aid assembly, not guaranteed to be accurate for parts with more than two pins
 * stencil/* - Top and bottom stencil for DIY assembly

# Changes

## PCB

 * Silkscreen updated to build9.
 * Opensource hardware logo added back to silkscreen.
 * Clearance for ground to trace on top layer reduced to 0.21mm. This should make impedance closer to 50 Ohms. This setting was lost in the build8 upgrade to Kicad 5.02.
 * Some minor rework to ensure more and better ground planes on top layer.
 * Board length reduced from 50mm to 49.9mm to ensure easier fit in case. 

## BOM

 * No changes to BOMs.
 
