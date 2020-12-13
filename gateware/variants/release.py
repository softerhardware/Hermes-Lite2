

import os
from shutil import copy2 as cp

subdirs = ["hl2b5up_main"]
subdirs_alt = ["hl2b3to4_main","hl2b2_main"]
subdirs_rbf = ["hl2b5up_cicrx","hl2b3to4_cicrx","hl2b5up_ak4951v3"]
#subdirs_radioberry = ["radioberry_cl016","radioberry_cl025"]

for subdir in subdirs:
  os.system("mkdir -p release/{0}".format(subdir))
  try:
    cp("{0}/build/hermeslite.sof".format(subdir),"release/{0}/{0}.sof".format(subdir))
    cp("{0}/build/hermeslite.rbf".format(subdir),"release/{0}/{0}.rbf".format(subdir))
    cp("{0}/build/hermeslite.jic".format(subdir),"release/{0}/{0}.jic".format(subdir))
    cp("{0}/build/hermeslitejic.jam".format(subdir),"release/{0}/{0}jic.jam".format(subdir))
    cp("{0}/build/hermeslitesof.jam".format(subdir),"release/{0}/{0}sof.jam".format(subdir))
    cp("{0}/build/hermeslitesof.svf".format(subdir),"release/{0}/{0}sof.svf".format(subdir))
  except:
    print("Failures for {0}".format(subdir))

for subdir in subdirs_alt:
  os.system("mkdir -p release/variants/{0}".format(subdir))
  try:
    cp("{0}/build/hermeslite.sof".format(subdir),"release/variants/{0}/{0}.sof".format(subdir))
    cp("{0}/build/hermeslite.rbf".format(subdir),"release/variants/{0}/{0}.rbf".format(subdir))
    cp("{0}/build/hermeslite.jic".format(subdir),"release/variants/{0}/{0}.jic".format(subdir))
    cp("{0}/build/hermeslitejic.jam".format(subdir),"release/variants/{0}/{0}jic.jam".format(subdir))
    cp("{0}/build/hermeslitesof.jam".format(subdir),"release/variants/{0}/{0}sof.jam".format(subdir))
    cp("{0}/build/hermeslitesof.svf".format(subdir),"release/variants/{0}/{0}sof.svf".format(subdir))
  except:
    print("Failures for {0}".format(subdir))

for subdir in subdirs_rbf:
  os.system("mkdir -p release/variants/{0}".format(subdir))
  try:
    cp("{0}/build/hermeslite.rbf".format(subdir),"release/variants/{0}/{0}.rbf".format(subdir))
  except:
    print("Failures for {0}".format(subdir))


#for subdir in subdirs_radioberry:
#  os.system("mkdir -p release/variants/{0}".format(subdir))
#  try:
#    cp("{0}/build/radioberry.sof".format(subdir),"release/variants/{0}/{0}.sof".format(subdir))
#    cp("{0}/build/radioberry.rbf".format(subdir),"release/variants/{0}/{0}.rbf".format(subdir))
#  except:
#    print("Failures for {0}".format(subdir))