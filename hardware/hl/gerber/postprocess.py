import re
## These values change if KiCAD's global solder mask expansion is changed.
## Current, the global solder mask expansion is expected to be 0.1mm

frontsilk = 'hermeslite-F.Mask.gbr',{
'0.801000':'0.000000',
'0.802000':'0.000000',
'0.803000':'0.700000',
'0.800000':'0.700000'}

backsilk  = 'hermeslite-B.Mask.gbr',{
'0.700000':'0.000000',
'0.801000':'0.000000',
'0.802000':'0.700000',
'0.803000':'0.000000',
'0.800000':'0.700000'}

frontcopper = 'hermeslite-F.Cu.gbr',{
'0.601000':'0.600000',
'0.602000':'0.600000',
'0.603000':'0.600000'}

backcopper = 'hermeslite-B.Cu.gbr',{
'0.601000':'0.600000',
'0.602000':'0.600000',
'0.603000':'0.600000'}


def PostProcess( (fn,d) ):
	with open(fn, "r") as gfile:
		lines = gfile.readlines()

	with open(fn, "w") as gfile:
		for line in lines:
			m = re.match('\%ADD(.*)C,(.*)\*\%',line)
			if m:
				if m.group(2) in d:
					line = "%ADD{0}C,{1}*%\n".format(m.group(1),d[m.group(2)])
					print "Replaced:",fn,line
			gfile.write(line)


PostProcess( frontsilk )
PostProcess( backsilk )
PostProcess( frontcopper )
PostProcess( backcopper )

