

import BOM

optionset = set([])

## 'NOASSEMBLY' to include parts needed by not put on by assembly house

bom = BOM.BOM("../hermeslite.xml",optionset=optionset)


bom.CSVAssemblyPrint(['Mouser','Digi-Key'],ecid=True)


