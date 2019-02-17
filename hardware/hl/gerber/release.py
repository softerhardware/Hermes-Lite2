

import os

os.rename("hermeslite-F.Cu.gbr","pcb/hermeslite2.GTL")
os.rename("hermeslite-B.Cu.gbr","pcb/hermeslite2.GBL")
os.rename("hermeslite-In1.Cu.gbr","pcb/hermeslite2.GL2")
os.rename("hermeslite-In2.Cu.gbr","pcb/hermeslite2.GL3")

os.rename("hermeslite-F.SilkS.gbr","pcb/hermeslite2.GTO")
os.rename("hermeslite-B.SilkS.gbr","pcb/hermeslite2.GBO")

os.rename("hermeslite-F.Mask.gbr","pcb/hermeslite2.GTS")
os.rename("hermeslite-B.Mask.gbr","pcb/hermeslite2.GBS")

os.rename("hermeslite.drl","pcb/hermeslite2.TXT")

os.rename("hermeslite-Edge.Cuts.gbr","pcb/hermeslite2.GML")

os.rename("hermeslite-top.pos","position/hermeslite2-top.pos")
os.rename("hermeslite-bottom.pos","position/hermeslite2-bot.pos")