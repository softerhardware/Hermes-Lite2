

import BOM

## Add ADNI to include assembly DNI parts that are required
optionset = set(["ADNI"])
##optionset = set([""])

bom = BOM.BOM("../n2adr.xml",optionset=optionset)

pre = """\\section*{N2ADR Filter Board E5 BOM}
Standard Build - \\today"""

bom.LaTeXPrint(pre,['Mouser','Digi-Key'])


