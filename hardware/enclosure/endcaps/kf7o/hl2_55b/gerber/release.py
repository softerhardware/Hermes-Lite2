

import os

os.rename("endcap-F.Cu.gbr","pcb/endcap.GTL")
os.rename("endcap-B.Cu.gbr","pcb/endcap.GBL")

os.rename("endcap-F.SilkS.gbr","pcb/endcap_v.GTO")
os.rename("endcap-Eco1.User.gbr","pcb/endcap_h.GTO")
os.rename("endcap-B.SilkS.gbr","pcb/endcap.GBO")

os.rename("endcap-F.Mask.gbr","pcb/endcap.GTS")
os.rename("endcap-B.Mask.gbr","pcb/endcap.GBS")

os.rename("endcap.drl","pcb/endcap.TXT")

os.rename("endcap-Edge.Cuts.gbr","pcb/endcap.GML")


#os.rename("endcap-top.pos","position/endcap-top.pos")
#os.rename("endcap-bottom.pos","position/endcap-bot.pos")

os.rename("endcap-F.Paste.gbr","stencil/endcap-F.Paste.gbr")
os.rename("endcap-B.Paste.gbr","stencil/endcap-B.Paste.gbr")
os.rename("endcap-Dwgs.User.gbr","stencil/endcap-DWgs.User.gbr")
