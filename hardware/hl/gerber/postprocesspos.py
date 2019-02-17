
## DNI from BOM
dnistr = "B55 B104 B107 C42 C47 C54 C55 C58 C59 C79 C80 C82 C83 C85 C148 C149 CL1 CL2 CL3 CL4 CL5 CL6 CL7 CL8 CL10 CN7 CN8 CN9 CN10 D6 D7 DB1 DB2 DB3 DB6 DB7 DB8 DB9 DB11 DB12 DB13 DB14 DB15 DB17 DB20 DB23 DB27 J3 J4 J6 J7 J8 J12 J14 J16 J20 K2 R8 R9 R13 R16 R17 R36 R38 R60 R93 R96 R97 R98 R104 R112 R115 R117 R118 R119 R128 R129 R135 RF1 RF2 RF3 RF4 RF5 RF6 RF7 T3 X3"

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
