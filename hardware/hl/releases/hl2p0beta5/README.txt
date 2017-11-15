

November 14, 2017

This directory contains all files necessary to fabricate the Hermes-Lite 2.0beta5 release. Elecrow is the preferred provider. For Elecrow, www.elecrow.com, please contact jenny@elecrow.com and refer to web order #70280 to remind her of past Hermes-Lite work. For Makerfabs, www.makerfabs.com, please contact helen@makerfabs.com. 

Only the gerber files in the .zip package are required if just printed circuit boards are desired. Also, PCBs can be ordered directly online without corresponding with Jenny or Helen.

Below is the e-mail included when soliciting bids.


Dear Jenny,

Thank you for your production of 5 Hermes-Lite2beta3 units for web order #70280. All the units were good and I am very happy with your work. I have made some changes and would like to order 10 Hermes-Lite2beta5 units. Beta5 is similar to beta3, but there are updates to all design files.

Can you also provide the following two services?

*** Ship direct to customer. You provide me with price to build 10 units and shipping weight for 1 unit. I send buyers price and they pay you price and shipping cost directly. Shipping costs are calculated as already on your web page for buyer's selected shipping method and unit weight. Once you receive payment for 10 units, you begin production and ship directly to buyer when ready.

*** Functional testing of units. I can provide tests and simple equipment to do power-on tests and basic functional testing. You test each board. Test per board will take less than 5 minutes.  

Please let me know if you can provide these services.


Attached, please find files for fabrication of the Hermes-Lite2 Beta5 software defined transceiver. I am interested in a quote for turnkey (you supply all parts) PCB fabrication and assembly of 10 units. This is an open source hardware project. More details are at www.hermeslite.com. This is a request for a prototype run, but eventually I would like to arrange with elecrow to produce these units and then for elecrow to sell directly to customers. If there are no changes required in this beta5 run, I would like to start production of 20-50 units every 3 months beginning in 2018.

***The PCB files are in the pcb subdirectory:

Top layer:					pcb/hermeslite2.GTL
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

These files are for guidance only. Exact position of complex components with more than 2 pins must be checked and verified.


Please let me know of any questions are ideas to reduce costs.


Best Regards,
