
## DNI from BOM
dnistr = "B55 B58 B65 B67 B82 B96 B104 B107 B112 B117 B121 C10 C11 C42 C47 C54 C55 C58 C59 C75 C76 C77 C78 C79 C80 C82 C83 C85 C148 C149 CL1 CL2 CL3 CL4 CN5 CN6 CN7 CN8 CN9 CN10 CN11 CN12 D6 D7 D8 D9 D10 D11 D13 D14 DB1 DB2 DB3 DB4 DB5 DB6 DB7 DB8 DB9 DB10 DB11 DB12 DB14 DB16 DB17 DB19 DB20 DB22 DB23 DB24 DB26 DB27 FB27 FB29 J3 J4 J5 J6 J7 J8 J12 J13 J16 J17 J18 J20 J23 Q7 R8 R9 R13 R16 R17 R18 R30 R31 R32 R33 R35 R36 R37 R38 R39 R40 R41 R45 R60 R83 R84 R85 R86 R87 R88 R89 R90 R93 R96 R97 R98 R103 R104 R112 R113 R114 R115 R116 R117 R118 R119 R128 R129 R135 RF3 U5 U18 X3"

dni = set(dnistr.split())

dni.update(["TP1","TP2","TP3","TP4","TP5","TP6","TP7","TP8","TP9"])


def PostProcess(fn):
	with open(fn, "r") as gfile:
		lines = gfile.readlines()

	with open(fn, "w") as gfile:
		for line in lines:
			li = line.split()
			if li[0] not in dni:
				gfile.write(line)

PostProcess( "hermeslite-top.pos" )
PostProcess( "hermeslite-bottom.pos")
