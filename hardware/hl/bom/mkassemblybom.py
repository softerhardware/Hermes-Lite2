

import BOM

optionset = set([])

## 'NOASSEMBLY' to include parts needed by not put on by assembly house

bom = BOM.BOM("../hermeslite.xml",optionset=optionset)

pre = """\\section*{Hermes-Lite 2.0build9 BOM}
Assembly Build - \\today"""

bom.LaTeXAssemblyPrint(pre,['Mouser','Digi-Key'])


