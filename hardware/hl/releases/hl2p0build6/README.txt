

February 25, 2018

This directory contains all files necessary to fabricate the Hermes-Lite 2.0build6 release. Elecrow is the preferred provider as they have and are developing expertise in the Hermes-Lite 2.0.

Only the gerber files in the .zip packages are required if just printed circuit boards are desired. Also, PCBs can be ordered directly online without requesting a bid.

The hermeslite2build6_manual.zip package contains gerber files with large holes present to facilitate manually soldering of the thermal pads. The hermeslite2build6.zip package doesn't contain these holes and is for automated assembly.

Changes since hl2beta5:

 * Extra notes and note errors fixed on schematic. No electrical changes.
 * LDMOS footprint changed so that PCB will always appear as 10cm by 10cm, not larger.
 * Added small cutout so that CW jack will sit flat on PCB.
 * Moved one via and converted optional 2x1 header DB6 to surface mount so that heat flow in inner layers away form the AD9866 is improved.
 * Updated version text on PCB.
 * Released two versions of gerber files, one with large holes for manual soldering of the thermal pads, one without such holes for automated assembly.

There are no electrical changes. In fact, all changes to the PCB are such that the hl5b5 stencil and BOMs may still be used.
