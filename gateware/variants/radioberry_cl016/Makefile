## Quartus tools quartus_sh and quartus_cpf must be in your path

all: build/radioberry.sof

build/radioberry.sof:
	quartus_sh --flow compile radioberry -c radioberry

clean:
	rm -rf build

realclean:
	rm -rf db incremental_db

.PHONY: all clean realclean
