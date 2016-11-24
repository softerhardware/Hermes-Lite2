

import BOM

optionset = set(['NOSWCLK','NOREGPA','LVDS25','ETH25','ETH','VERSA',
	'RXLPF','RXNPOL','TXLPF','TXPREAMP','TXLP','LED','FRONTIO',
	'EXTPTT','EXTFILTER','VERSAOSC','PROGRAMMER'])

bom = BOM.BOM("../hermeslite.xml",optionset=optionset)

pre = """\\section*{Hermes-Lite 2.0beta2 BOM}
No PA Build - \\today"""


bom.LaTeXPrint(pre,['Mouser','Digi-Key'])


