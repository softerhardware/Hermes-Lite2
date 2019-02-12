

import BOM

## Add ADNI to include assembly DNI parts that are required
optionset = set(["ADNI"])

bom = BOM.BOM("../hermeslite.xml",optionset=optionset)

pre = """\\section*{Hermes-Lite 2.0build8 BOM}
Standard Build - \\today"""

bom.LaTeXPrint(pre,['Mouser','Digi-Key'])


