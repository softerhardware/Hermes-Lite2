

import os


li = ["GBL","GBO","GBS","GML","GTL","GTO","GTS","TXT"]


oldroot = "endcap"
newroot = "hl2_40f"

for f in li:
	os.rename("{0}/{1}.{2}".format(newroot,oldroot,f),"{0}/{0}.{1}".format(newroot,f))

