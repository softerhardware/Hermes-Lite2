
all:
	$(MAKE) -C hl2b2_main
	$(MAKE) -C hl2b3to4_main
	$(MAKE) -C hl2b3to4_cicrx
	$(MAKE) -C hl2b5up_main
	$(MAKE) -C hl2b5up_6rx
	$(MAKE) -C hl2b5up_cicrx
	$(MAKE) -C hl2b5up_15ce
	$(MAKE) -C hl2b5up_ak4951v3
	$(MAKE) -C radioberry_cl025
	$(MAKE) -C radioberry_cl025_4000
	$(MAKE) -C radioberry_cl016
	$(MAKE) -C radioberry_cl016_4000
	$(MAKE) -C radioberry_juice_cl025
	
radioberry:
	$(MAKE) -C radioberry_cl025
	$(MAKE) -C radioberry_cl025_4000
	$(MAKE) -C radioberry_cl016
	$(MAKE) -C radioberry_cl016_4000

radioberry-juice:
	$(MAKE) -C radioberry_juice_cl025

clean:
	$(MAKE) -C hl2b2_main clean
	$(MAKE) -C hl2b3to4_main clean
	$(MAKE) -C hl2b3to4_cicrx clean
	$(MAKE) -C hl2b5up_main clean
	$(MAKE) -C hl2b5up_6rx clean
	$(MAKE) -C hl2b5up_cicrx clean
	$(MAKE) -C hl2b5up_15ce clean
	$(MAKE) -C hl2b5up_ak4951v3 clean
	$(MAKE) -C radioberry_cl025 clean
	$(MAKE) -C radioberry_cl016 clean

realclean:
	$(MAKE) -C hl2b2_main realclean
	$(MAKE) -C hl2b3to4_main realclean
	$(MAKE) -C hl2b3to4_cicrx realclean
	$(MAKE) -C hl2b5up_main realclean
	$(MAKE) -C hl2b5up_6rx realclean
	$(MAKE) -C hl2b5up_cicrx realclean
	$(MAKE) -C hl2b5up_15ce realclean
	$(MAKE) -C hl2b5up_ak4951v3 realclean
	$(MAKE) -C radioberry_cl025 realclean
	$(MAKE) -C radioberry_cl016 realclean


.PHONY: all clean realclean
