## Hermes-Lite 2 (hl2b5up) source lists.
##
## Sourced by the hl2b5up_* variant .qsf files. Paths inside the subsystem
## lists are relative to the Quartus project directory (the variant dir).
##
## Receive chains are intentionally NOT listed here: each variant .qsf adds
## its own receiver implementation directly:
##   receiver_nco.v     - standard NCO front end   (main, 15ce, 6rx, bypassversa)
##   receiver_4000.v    - alternate receive chain  (4000)
##   receiver_ciconly.v - CIC-only chain           (cicrx)
##
## Deliberately excluded from the build (unreachable from hermeslite_core for
## this board family, files kept in-tree for reference):
##   rtl/radio_openhpsdr1/receiver.v          (+ rtl/radio_openhpsdr1/cordic.v,
##                                               only instantiated by receiver.v)
##   rtl/radio_openhpsdr1/receiver2/*         (uninstantiated alternate chain)
##   rtl/radio_openhpsdr1/qs1r/*              (uninstantiated QS1R port)
##   rtl/cdc_sync.v                           (uninstantiated CDC helper)

set script_dir [file dirname [file normalize [info script]]]

source [file join $script_dir files_core.tcl]
source [file join $script_dir files_ethernet.tcl]
source [file join $script_dir files_radio_hl2.tcl]
source [file join $script_dir files_control.tcl]
source [file join $script_dir files_boot.tcl]
