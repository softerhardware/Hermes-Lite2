

import BOM

optionset = set(['NOSWCLK','REGPA','PA','LVDS25','ETH25','ETH','VERSA',
	'RXLPF','RXNPOL','TXLPF','TXPREAMP','TXSW','TXLP','LED','FRONTIO','ADC','THERMAL',
	'PATR','EXTPTT','EXTFILTER','VERSAOSC','CASE','PROGRAMMER'])

bom = BOM.BOM("../hermeslite.xml",optionset=optionset)

pre = """\\section*{Hermes-Lite 2.0beta2 BOM}
Standard Build - \\today"""

bom.LaTeXPrint(pre,['Mouser','Digi-Key'])


