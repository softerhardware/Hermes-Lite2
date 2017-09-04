

September 4, 2017

This directory contains all files necessary to fabricate the Hermes-Lite 2.0beta3 release. Quotes are included for complete turnkey assembly by two compaines in China. A run of 5 assembled boards was done with Elecrow with good results. Elecrow is the preferred provider. For Elecrow, www.elecrow.com, please contact jenny@elecrow.com and refer to web order #70280 to remind her of past Hermes-Lite work. For Makerfabs, www.makerfabs.com, please contact helen@makerfabs.com. 

Only the gerber files in the .zip package are required if just printed circuit boards are desired. Also, PCBs can be ordered directly online without corresponding with Jenny or Helen.

Below is the e-mail included when soliciting bids.


Dear Sirs,

Attached, please find files for fabrication of the Hermes-Lite2 software defined transceiver. I am interested in quotes for turnkey (you supply all parts) PCB fabrication and assembly of 1, 5, 10 or 50 units. This is an open source hardware project. More details are at www.hermeslite.com. This is a request for a prototype run, but eventually I would like to arrange with elecrow to produce these units and then for elecrow to sell directly to customers.  

***The PCB files are in the pcb subdirectory:

Top layer:				pcb/hermeslite2.GTL
inner layer 2:				pcb/hermeslite2.GL2
inner layer 3:				pcb/hermeslite2.GL3
Bottom layer:				pcb/hermeslite2.GBL
Solder Stop Mask top:		pcb/hermeslite2.GTS
Solder Stop Mask Bottom:	pcb/hermeslite2.GBS
Silk Top:					pcb/hermeslite2.GTO
Silk Bottom:				pcb/hermeslite2.GBO
NC Drill:					pcb/hermeslite2.TXT
Mechanical layer :			pcb/hermeslite2.GML


***Specifications for the PCB are:

Size: 10cmx10cm
Layers: 4
Solder Mask Color: Least Expensive
Surface Finish: Least Expensive Lead Free
Board Thickness: 1.6mm
Copper Weight: 1oz
Minimum Trace/Space: 0.2mm
Minimum Drill: 0.3mm
Gold Fingers: 0
Stencil: You supply
Ship To: USA via ShenzhenDHL


***The BOM files are in the bom subdirectory:

PDF format: bom/hermeslite2bom.pdf
Excel format: bom/hermeslite2bom.xlsx

Part ID is assigned from your list of free capacitors and resistors. Substitutions are allowed if the new part meets all specifications in the description field and there is a Y in the substition allowed column. For parts marked N (No) in Sub Okay field, no substitution is allowed unless agreed to in writing by steve@softerhareware.com. Both BOMs contain part links for each BOM line for more details.


***The Position files are in the position subdirectory:

Top: position/hermeslite2top.pos
Bottom: position/hermeslite2bot.pos

These files are for guidance only. Exact position of complex (>2 pin) components must be checked and verified.


Please let me know of any questions are ideas to reduce costs.


Best Regards,
