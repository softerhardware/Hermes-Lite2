EESchema Schematic File Version 4
LIBS:endcap-cache
EELAYER 26 0
EELAYER END
$Descr USLetter 11000 8500
encoding utf-8
Sheet 1 1
Title "HL2 End Cap"
Date "2019-08-22"
Rev "1.0"
Comp "SofterHardware"
Comment1 "KF7O Steve Haynal"
Comment2 ""
Comment3 ""
Comment4 ""
$EndDescr
$Comp
L Connector:TestPoint MH1
U 1 1 5D58DD5D
P 1600 5350
F 0 "MH1" H 1658 5470 50  0000 L CNN
F 1 "3mm" H 1658 5379 50  0000 L CNN
F 2 "endcaplib:mh3mm" H 1800 5350 50  0001 C CNN
F 3 "~" H 1800 5350 50  0001 C CNN
	1    1600 5350
	1    0    0    -1  
$EndComp
$Comp
L Connector:TestPoint MH2
U 1 1 5D58DECC
P 2150 5350
F 0 "MH2" H 2208 5470 50  0000 L CNN
F 1 "3mm" H 2208 5379 50  0000 L CNN
F 2 "endcaplib:mh3mm" H 2350 5350 50  0001 C CNN
F 3 "~" H 2350 5350 50  0001 C CNN
	1    2150 5350
	1    0    0    -1  
$EndComp
$Comp
L Connector:TestPoint MH3
U 1 1 5D58DF0A
P 2700 5350
F 0 "MH3" H 2758 5470 50  0000 L CNN
F 1 "3mm" H 2758 5379 50  0000 L CNN
F 2 "endcaplib:mh3mm" H 2900 5350 50  0001 C CNN
F 3 "~" H 2900 5350 50  0001 C CNN
	1    2700 5350
	1    0    0    -1  
$EndComp
$Comp
L Connector:TestPoint MH4
U 1 1 5D58DF75
P 3250 5350
F 0 "MH4" H 3308 5470 50  0000 L CNN
F 1 "3mm" H 3308 5379 50  0000 L CNN
F 2 "endcaplib:mh3mm" H 3450 5350 50  0001 C CNN
F 3 "~" H 3450 5350 50  0001 C CNN
	1    3250 5350
	1    0    0    -1  
$EndComp
Wire Wire Line
	1600 5350 1600 5400
Wire Wire Line
	1600 5400 2150 5400
Wire Wire Line
	3250 5400 3250 5350
Wire Wire Line
	2700 5350 2700 5400
Connection ~ 2700 5400
Wire Wire Line
	2700 5400 3250 5400
Wire Wire Line
	2150 5350 2150 5400
Connection ~ 2150 5400
Wire Wire Line
	2150 5400 2425 5400
$Comp
L power:Earth #PWR0101
U 1 1 5D58E2C0
P 2425 5450
F 0 "#PWR0101" H 2425 5200 50  0001 C CNN
F 1 "Earth" H 2425 5300 50  0001 C CNN
F 2 "" H 2425 5450 50  0001 C CNN
F 3 "~" H 2425 5450 50  0001 C CNN
	1    2425 5450
	1    0    0    -1  
$EndComp
Wire Wire Line
	2425 5450 2425 5400
Connection ~ 2425 5400
Wire Wire Line
	2425 5400 2700 5400
$Comp
L Transistor_FET:IRLML6402 Q2
U 1 1 5D5E23C2
P 5400 2625
F 0 "Q2" V 5743 2625 50  0000 C CNN
F 1 "IRLML6402" V 5652 2625 50  0000 C CNN
F 2 "endcaplib:SOT23_3" H 5600 2550 50  0001 L CIN
F 3 "https://www.infineon.com/dgdl/irlml6402pbf.pdf?fileId=5546d462533600a401535668d5c2263c" H 5400 2625 50  0001 L CNN
	1    5400 2625
	0    1    -1   0   
$EndComp
$Comp
L Transistor_BJT:DTC144E Q1
U 1 1 5D5E26C3
P 5300 3225
F 0 "Q1" H 5487 3271 50  0000 L CNN
F 1 "DTC144E" H 5487 3180 50  0000 L CNN
F 2 "endcaplib:SOT23_3" H 5300 3225 50  0001 L CNN
F 3 "" H 5300 3225 50  0001 L CNN
	1    5300 3225
	1    0    0    -1  
$EndComp
$Comp
L Device:R R1
U 1 1 5D5E2A46
P 5100 2800
F 0 "R1" H 5170 2846 50  0000 L CNN
F 1 "10K" V 5100 2725 50  0000 L CNN
F 2 "endcaplib:SMD-0805" V 5030 2800 50  0001 C CNN
F 3 "~" H 5100 2800 50  0001 C CNN
	1    5100 2800
	1    0    0    -1  
$EndComp
Wire Wire Line
	5100 2525 5200 2525
Wire Wire Line
	5400 2825 5400 3000
Wire Wire Line
	5100 2950 5100 3000
Wire Wire Line
	5100 3000 5400 3000
Connection ~ 5400 3000
Wire Wire Line
	5400 3000 5400 3025
$Comp
L Connector:TestPoint TP1
U 1 1 5D5E2E29
P 4850 2525
F 0 "TP1" V 4925 2650 50  0000 C CNN
F 1 "Power" V 4850 2825 50  0000 C CNN
F 2 "TestPoint:TestPoint_Pad_D4.0mm" H 5050 2525 50  0001 C CNN
F 3 "~" H 5050 2525 50  0001 C CNN
	1    4850 2525
	0    -1   -1   0   
$EndComp
$Comp
L Connector:TestPoint TP2
U 1 1 5D5E2F38
P 4850 3225
F 0 "TP2" V 4925 3350 50  0000 C CNN
F 1 "Fan Control" V 4850 3625 50  0000 C CNN
F 2 "TestPoint:TestPoint_Pad_D4.0mm" H 5050 3225 50  0001 C CNN
F 3 "~" H 5050 3225 50  0001 C CNN
	1    4850 3225
	0    -1   -1   0   
$EndComp
$Comp
L Connector:TestPoint TP4
U 1 1 5D5E2FBA
P 5800 2525
F 0 "TP4" V 5725 2600 50  0000 L CNN
F 1 "Fan Power" V 5800 2700 50  0000 L CNN
F 2 "TestPoint:TestPoint_Pad_D4.0mm" H 6000 2525 50  0001 C CNN
F 3 "~" H 6000 2525 50  0001 C CNN
	1    5800 2525
	0    1    1    0   
$EndComp
$Comp
L power:Earth #PWR01
U 1 1 5D5E3078
P 5400 3525
F 0 "#PWR01" H 5400 3275 50  0001 C CNN
F 1 "Earth" H 5400 3375 50  0001 C CNN
F 2 "" H 5400 3525 50  0001 C CNN
F 3 "~" H 5400 3525 50  0001 C CNN
	1    5400 3525
	1    0    0    -1  
$EndComp
$Comp
L Connector:TestPoint TP5
U 1 1 5D5E3097
P 5800 3475
F 0 "TP5" V 5725 3550 50  0000 L CNN
F 1 "Ground" V 5800 3650 50  0000 L CNN
F 2 "TestPoint:TestPoint_Pad_D4.0mm" H 6000 3475 50  0001 C CNN
F 3 "~" H 6000 3475 50  0001 C CNN
	1    5800 3475
	0    1    1    0   
$EndComp
$Comp
L Connector:TestPoint TP3
U 1 1 5D5E3404
P 4850 3475
F 0 "TP3" V 4925 3600 50  0000 C CNN
F 1 "Ground" V 4850 3775 50  0000 C CNN
F 2 "TestPoint:TestPoint_Pad_D4.0mm" H 5050 3475 50  0001 C CNN
F 3 "~" H 5050 3475 50  0001 C CNN
	1    4850 3475
	0    -1   -1   0   
$EndComp
Wire Wire Line
	4850 2525 5100 2525
Connection ~ 5100 2525
Wire Wire Line
	5100 2525 5100 2650
Wire Wire Line
	5600 2525 5800 2525
Wire Wire Line
	5400 3425 5400 3475
Wire Wire Line
	4850 3475 5400 3475
Connection ~ 5400 3475
Wire Wire Line
	5400 3475 5400 3525
Wire Wire Line
	5800 3475 5400 3475
Wire Wire Line
	4850 3225 5050 3225
Text Notes 4850 2825 0    50   ~ 0
0805
Text Notes 5725 3025 0    50   ~ 0
SOT-23-3\nor\nSOT-323
$EndSCHEMATC
