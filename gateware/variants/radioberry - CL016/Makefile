## Quartus tools quartus_sh and quartus_cpf must be in your path

all: build/hermeslitejic.jam build/hermeslitesof.jam build/hermeslitesof.svf


build/hermeslite.sof:
	quartus_sh --flow compile hermeslite -c hermeslite

build/hermeslite.jic: build/hermeslite.sof
	quartus_cpf -c ../../boards/hl2b5up/ep4ce22.cof

build/hermeslitejic.jam: build/hermeslite.jic
	quartus_cpf -c build/hermeslite.jic build/hermeslitejic.jam

build/hermeslitesof.jam: build/hermeslite.sof
	quartus_cpf -c build/hermeslite.sof build/hermeslitesof.jam

build/hermeslitesof.svf: build/hermeslite.sof
	quartus_cpf -c -q 12.0MHz -g 3.3 -n p build/hermeslite.sof build/hermeslitesof.svf

clean:
	rm -rf build

realclean:
	rm -rf db incremental_db

.PHONY: all clean realclean
