## Quartus tools quartus_sh and quartus_cpf must be in your path

hl2b5up/hl2b5up.sof:
	quartus_sh --flow compile hermeslite -c hl2b5up

hl2b5up/hl2b5up.jic: hl2b5up/hl2b5up.sof
	quartus_cpf -c hl2b5up.cof

hl2b5up/hl2b5upjic.jam: hl2b5up/hl2b5up.jic
	quartus_cpf -c hl2b5up/hl2b5up.jic hl2b5up/hl2b5upjic.jam

hl2b5up/hl2b5upsof.jam: hl2b5up/hl2b5up.sof
	quartus_cpf -c hl2b5up/hl2b5up.sof hl2b5up/hl2b5upsof.jam

hl2b5up: hl2b5up/hl2b5up.sof hl2b5up/hl2b5up.jic hl2b5up/hl2b5upjic.jam hl2b5up/hl2b5upsof.jam
	mkdir -p release/hl2b5up
	cp hl2b5up/hl2b5up.sof release/hl2b5up
	cp hl2b5up/hl2b5up.jic release/hl2b5up
	cp hl2b5up/hl2b5upjic.jam release/hl2b5up
	cp hl2b5up/hl2b5upsof.jam release/hl2b5up


hl2b3to4/hl2b3to4.sof:
	quartus_sh --flow compile hermeslite -c hl2b3to4

hl2b3to4/hl2b3to4.jic: hl2b3to4/hl2b3to4.sof
	quartus_cpf -c hl2b3to4.cof

hl2b3to4/hl2b3to4jic.jam: hl2b3to4/hl2b3to4.jic
	quartus_cpf -c hl2b3to4/hl2b3to4.jic hl2b3to4/hl2b3to4jic.jam

hl2b3to4/hl2b3to4sof.jam: hl2b3to4/hl2b3to4.sof
	quartus_cpf -c hl2b3to4/hl2b3to4.sof hl2b3to4/hl2b3to4sof.jam

hl2b3to4: hl2b3to4/hl2b3to4.sof hl2b3to4/hl2b3to4.jic hl2b3to4/hl2b3to4jic.jam hl2b3to4/hl2b3to4sof.jam
	mkdir -p release/hl2b3to4
	cp hl2b3to4/hl2b3to4.sof release/hl2b3to4
	cp hl2b3to4/hl2b3to4.jic release/hl2b3to4
	cp hl2b3to4/hl2b3to4jic.jam release/hl2b3to4
	cp hl2b3to4/hl2b3to4sof.jam release/hl2b3to4


hl2b2/hl2b2.sof:
	quartus_sh --flow compile hermeslite -c hl2b2

hl2b2/hl2b2.jic: hl2b2/hl2b2.sof
	quartus_cpf -c hl2b2.cof

hl2b2/hl2b2jic.jam: hl2b2/hl2b2.jic
	quartus_cpf -c hl2b2/hl2b2.jic hl2b2/hl2b2jic.jam

hl2b2/hl2b2sof.jam: hl2b2/hl2b2.sof
	quartus_cpf -c hl2b2/hl2b2.sof hl2b2/hl2b2sof.jam

hl2b2: hl2b2/hl2b2.sof hl2b2/hl2b2.jic hl2b2/hl2b2jic.jam hl2b2/hl2b2sof.jam
	mkdir -p release/hl2b2
	cp hl2b2/hl2b2.sof release/hl2b2
	cp hl2b2/hl2b2.jic release/hl2b2
	cp hl2b2/hl2b2jic.jam release/hl2b2
	cp hl2b2/hl2b2sof.jam release/hl2b2


hl2b5uphd/hl2b5uphd.sof:
	quartus_sh --flow compile hermeslite -c hl2b5uphd

hl2b5uphd/hl2b5uphd.jic: hl2b5uphd/hl2b5uphd.sof
	quartus_cpf -c hl2b5uphd.cof

hl2b5uphd/hl2b5uphdjic.jam: hl2b5uphd/hl2b5uphd.jic
	quartus_cpf -c hl2b5uphd/hl2b5uphd.jic hl2b5uphd/hl2b5uphdjic.jam

hl2b5uphd/hl2b5uphdsof.jam: hl2b5uphd/hl2b5uphd.sof
	quartus_cpf -c hl2b5uphd/hl2b5uphd.sof hl2b5uphd/hl2b5uphdsof.jam

hl2b5uphd: hl2b5uphd/hl2b5uphd.sof hl2b5uphd/hl2b5uphd.jic hl2b5uphd/hl2b5uphdjic.jam hl2b5uphd/hl2b5uphdsof.jam
	mkdir -p release/hl2b5uphd
	cp hl2b5uphd/hl2b5uphd.sof release/hl2b5uphd
	cp hl2b5uphd/hl2b5uphd.jic release/hl2b5uphd
	cp hl2b5uphd/hl2b5uphdjic.jam release/hl2b5uphd
	cp hl2b5uphd/hl2b5uphdsof.jam release/hl2b5uphd

hl2b3to4hd/hl2b3to4hd.sof:
	quartus_sh --flow compile hermeslite -c hl2b3to4hd

hl2b3to4hd/hl2b3to4hd.jic: hl2b3to4hd/hl2b3to4hd.sof
	quartus_cpf -c hl2b3to4hd.cof

hl2b3to4hd/hl2b3to4hdjic.jam: hl2b3to4hd/hl2b3to4hd.jic
	quartus_cpf -c hl2b3to4hd/hl2b3to4hd.jic hl2b3to4hd/hl2b3to4hdjic.jam

hl2b3to4hd/hl2b3to4hdsof.jam: hl2b3to4hd/hl2b3to4hd.sof
	quartus_cpf -c hl2b3to4hd/hl2b3to4hd.sof hl2b3to4hd/hl2b3to4hdsof.jam

hl2b3to4hd: hl2b3to4hd/hl2b3to4hd.sof hl2b3to4hd/hl2b3to4hd.jic hl2b3to4hd/hl2b3to4hdjic.jam hl2b3to4hd/hl2b3to4hdsof.jam
	mkdir -p release/hl2b3to4hd
	cp hl2b3to4hd/hl2b3to4hd.sof release/hl2b3to4hd
	cp hl2b3to4hd/hl2b3to4hd.jic release/hl2b3to4hd
	cp hl2b3to4hd/hl2b3to4hdjic.jam release/hl2b3to4hd
	cp hl2b3to4hd/hl2b3to4hdsof.jam release/hl2b3to4hd

halfduplex: hl2b5uphd hl2b3to4hd

all: hl2b5up hl2b3to4 hl2b2

clean:
	rm -rf hl2b2 hl2b3to4 hl2b3to4hd hl2b5up hl2b5uphd release

.PHONY: hl2b5up hl2b3to4 hl2b2 hl2b5uphd hl2b3to4hd halfduplex all clean
