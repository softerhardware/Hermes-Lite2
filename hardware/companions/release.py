

import os, sys, shutil


root = sys.argv[1]

os.system("mkdir -p {0}".format(root))

li = [("-F.Cu.gbr","GTL"),("-B.Cu.gbr","GBL"),("-B.SilkS.gbr","GBO"),("-F.SilkS.gbr","GTO"),
  ("-F.Mask.gbr","GTS"),("-B.Mask.gbr","GBS"),(".drl","TXT"),("-Edge.Cuts.gbr","GML")]

for s,d in li:
  shutil.copyfile("gerber/{0}{1}".format(root,s),"{0}/{0}.{1}".format(root,d))


