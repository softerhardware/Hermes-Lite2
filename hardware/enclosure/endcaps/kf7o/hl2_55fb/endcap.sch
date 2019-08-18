EESchema Schematic File Version 4
LIBS:endcap-cache
EELAYER 26 0
EELAYER END
$Descr USLetter 11000 8500
encoding utf-8
Sheet 1 1
Title "HL2 End Cap"
Date "2019-08-17"
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
$EndSCHEMATC
