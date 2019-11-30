EESchema Schematic File Version 4
LIBS:psfeedback-cache
EELAYER 26 0
EELAYER END
$Descr USLetter 11000 8500
encoding utf-8
Sheet 1 1
Title "PureSignal Feedback"
Date "2019-11-29"
Rev "1.0"
Comp "SofterHardware"
Comment1 "KF7O Steve Haynal"
Comment2 ""
Comment3 ""
Comment4 ""
$EndDescr
$Comp
L Device:R_Small R3
U 1 1 5DE1B9F5
P 5225 3775
F 0 "R3" V 5150 3775 50  0000 C CNN
F 1 "470" V 5225 3775 39  0000 C CNN
F 2 "HERMESLITE:SMD-0805" H 5225 3775 50  0001 C CNN
F 3 "~" H 5225 3775 50  0001 C CNN
	1    5225 3775
	0    1    1    0   
$EndComp
$Comp
L Device:R_Small R4
U 1 1 5DE1BCF8
P 5375 3925
F 0 "R4" H 5450 3925 50  0000 C CNN
F 1 "1K" V 5375 3925 39  0000 C CNN
F 2 "HERMESLITE:SMD-0805" H 5375 3925 50  0001 C CNN
F 3 "~" H 5375 3925 50  0001 C CNN
	1    5375 3925
	1    0    0    -1  
$EndComp
$Comp
L Device:R_Small R2
U 1 1 5DE1BE08
P 5075 3925
F 0 "R2" H 5150 3925 50  0000 C CNN
F 1 "50" V 5075 3925 39  0000 C CNN
F 2 "HERMESLITE:SMD-0805" H 5075 3925 50  0001 C CNN
F 3 "~" H 5075 3925 50  0001 C CNN
	1    5075 3925
	1    0    0    -1  
$EndComp
$Comp
L Device:R_Small R1
U 1 1 5DE1BE3D
P 4925 3775
F 0 "R1" V 4850 3775 50  0000 C CNN
F 1 "0" V 4925 3775 39  0000 C CNN
F 2 "HERMESLITE:SMD-0805" H 4925 3775 50  0001 C CNN
F 3 "~" H 4925 3775 50  0001 C CNN
	1    4925 3775
	0    1    1    0   
$EndComp
$Comp
L hermeslite:BNC RF1
U 1 1 5DE4F533
P 4625 3775
F 0 "RF1" H 4625 4000 50  0000 C CNN
F 1 "BNC" H 4625 3925 50  0000 C CNN
F 2 "HERMESLITE:SMAEDGE" H 4625 3775 50  0001 C CNN
F 3 "" H 4625 3775 50  0000 C CNN
	1    4625 3775
	-1   0    0    -1  
$EndComp
$Comp
L hermeslite:RFD2b DB1
U 1 1 5DE4F7F3
P 5675 3875
F 0 "DB1" H 5546 3880 39  0000 R CNN
F 1 "RFD2b" H 5625 4075 39  0001 C CNN
F 2 "HERMESLITE:psfeedback" H 5675 3525 60  0001 C CNN
F 3 "" H 5675 3525 60  0000 C CNN
	1    5675 3875
	-1   0    0    -1  
$EndComp
Wire Wire Line
	5025 3775 5075 3775
Wire Wire Line
	5325 3775 5375 3775
Wire Wire Line
	5575 3975 5575 4075
Wire Wire Line
	5575 4075 5375 4075
Wire Wire Line
	4625 4075 4625 3975
Wire Wire Line
	5075 4025 5075 4075
Connection ~ 5075 4075
Wire Wire Line
	5075 4075 4625 4075
Wire Wire Line
	5375 4025 5375 4075
Connection ~ 5375 4075
Wire Wire Line
	5375 4075 5075 4075
Wire Wire Line
	4775 3775 4825 3775
Wire Wire Line
	5075 3825 5075 3775
Connection ~ 5075 3775
Wire Wire Line
	5075 3775 5125 3775
Wire Wire Line
	5375 3825 5375 3775
Connection ~ 5375 3775
Wire Wire Line
	5375 3775 5575 3775
$Comp
L power:GNDS #PWR0101
U 1 1 5DE4FB88
P 5075 4125
F 0 "#PWR0101" H 5075 3875 50  0001 C CNN
F 1 "GNDS" H 5080 3952 50  0001 C CNN
F 2 "" H 5075 4125 50  0001 C CNN
F 3 "" H 5075 4125 50  0001 C CNN
	1    5075 4125
	1    0    0    -1  
$EndComp
Wire Wire Line
	5075 4075 5075 4125
Text Notes 3975 4700 0    50   ~ 0
Configure as Pi or T attenuator\nKeep impedance presented to HL2 high, >300 Ohms\nhttps://chemandy.com/calculators/matching-pi-attenuator-calculator.htm\nhttps://chemandy.com/calculators/matching-t-attenuator-calculator.htm
$EndSCHEMATC
