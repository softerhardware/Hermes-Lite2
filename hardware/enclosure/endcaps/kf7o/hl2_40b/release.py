

import os, sys, shutil


root = sys.argv[1]

os.system("mkdir -p {0}_v".format(root))
os.system("mkdir -p {0}_h".format(root))

li = [("-F_Cu.gbr","GTL"),("-B_Cu.gbr","GBL"),("-B_SilkS.gbr","GBO"),
  ("-F_Mask.gbr","GTS"),("-B_Mask.gbr","GBS"),(".drl","TXT"),("-Edge_Cuts.gbr","GML")]

for s,d in li:
  shutil.copyfile("gerber/endcap{0}".format(s),"{0}_v/{0}.{1}".format(root,d))
  shutil.copyfile("gerber/endcap{0}".format(s),"{0}_h/{0}.{1}".format(root,d))


shutil.copyfile("gerber/endcap-F_SilkS.gbr","{0}_h/{0}.GTO".format(root))
shutil.copyfile("gerber/endcap-Eco1_User.gbr","{0}_v/{0}.GTO".format(root))


