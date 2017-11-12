

import BOM

optionset = set([])

## 'NOASSEMBLY' to include parts needed but not put on by assembly house

bom = BOM.BOM("../hermeslite.xml",optionset=optionset)

pre = """\\section*{Hermes-Lite 2.0beta5 BOM}
Standard Build - \\today"""

bom.LaTeXPrint(pre,['Mouser','Digi-Key'])


