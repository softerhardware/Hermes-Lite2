EESchema Schematic File Version 4
LIBS:hl2-panel-cache
EELAYER 26 0
EELAYER END
$Descr A4 11693 8268
encoding utf-8
Sheet 1 1
Title ""
Date ""
Rev ""
Comp ""
Comment1 ""
Comment2 ""
Comment3 ""
Comment4 ""
$EndDescr
$Comp
L Mechanical:MountingHole_Pad H1
U 1 1 5D313F4C
P 2350 1650
F 0 "H1" H 2450 1701 50  0000 L CNN
F 1 "MountingHole_Pad" H 2450 1610 50  0000 L CNN
F 2 "hl2-panel:Oval_Mounting_Hole" H 2350 1650 50  0001 C CNN
F 3 "~" H 2350 1650 50  0001 C CNN
	1    2350 1650
	1    0    0    -1  
$EndComp
$Comp
L Mechanical:MountingHole_Pad H2
U 1 1 5D313F66
P 2350 1950
F 0 "H2" H 2450 2001 50  0000 L CNN
F 1 "MountingHole_Pad" H 2450 1910 50  0000 L CNN
F 2 "hl2-panel:Oval_Mounting_Hole" H 2350 1950 50  0001 C CNN
F 3 "~" H 2350 1950 50  0001 C CNN
	1    2350 1950
	1    0    0    -1  
$EndComp
$Comp
L Mechanical:MountingHole_Pad H3
U 1 1 5D313F82
P 2350 2250
F 0 "H3" H 2450 2301 50  0000 L CNN
F 1 "MountingHole_Pad" H 2450 2210 50  0000 L CNN
F 2 "hl2-panel:Oval_Mounting_Hole" H 2350 2250 50  0001 C CNN
F 3 "~" H 2350 2250 50  0001 C CNN
	1    2350 2250
	1    0    0    -1  
$EndComp
$Comp
L Mechanical:MountingHole_Pad H4
U 1 1 5D313FA0
P 2350 2550
F 0 "H4" H 2450 2601 50  0000 L CNN
F 1 "MountingHole_Pad" H 2450 2510 50  0000 L CNN
F 2 "hl2-panel:Oval_Mounting_Hole" H 2350 2550 50  0001 C CNN
F 3 "~" H 2350 2550 50  0001 C CNN
	1    2350 2550
	1    0    0    -1  
$EndComp
$Comp
L power:GND #PWR0101
U 1 1 5D314005
P 2100 2950
F 0 "#PWR0101" H 2100 2700 50  0001 C CNN
F 1 "GND" H 2105 2777 50  0000 C CNN
F 2 "" H 2100 2950 50  0001 C CNN
F 3 "" H 2100 2950 50  0001 C CNN
	1    2100 2950
	1    0    0    -1  
$EndComp
Wire Wire Line
	2350 1750 2100 1750
Wire Wire Line
	2100 1750 2100 2050
Wire Wire Line
	2350 2050 2100 2050
Connection ~ 2100 2050
Wire Wire Line
	2100 2050 2100 2350
Wire Wire Line
	2350 2350 2100 2350
Connection ~ 2100 2350
Wire Wire Line
	2100 2350 2100 2650
Wire Wire Line
	2350 2650 2100 2650
Connection ~ 2100 2650
Wire Wire Line
	2100 2650 2100 2950
$EndSCHEMATC
