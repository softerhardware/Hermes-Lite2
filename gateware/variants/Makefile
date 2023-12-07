
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

release:
	$(MAKE) -C hl2b2_main
	$(MAKE) -C hl2b3to4_main
	$(MAKE) -C hl2b3to4_cicrx
	$(MAKE) -C hl2b5up_main
	$(MAKE) -C hl2b5up_6rx
	$(MAKE) -C hl2b5up_cicrx
	python3 release.py

# Check for unstaged and uncommitted changes, and fail with a message if there are any:
git_status:
	@git diff --ignore-matching-lines=LAST_QUARTUS_VERSION --exit-code >/dev/null || (echo You have unstaged changes && exit 1)
	@git diff --ignore-matching-lines=LAST_QUARTUS_VERSION --cached --exit-code >/dev/null || (echo You have staged but uncommitted changes && exit 1)
	@echo git status is clean

# Make the release and copy the RBF files to a new bitfiles/testing directory named using the date, version and git commit hash:
release_test: git_status release
	date=`date "+%Y%m%d"`; \
	gitrev=`git rev-parse --short HEAD`; \
	eval `sed -n 's/localparam.*VERSION_/VERSION_/p' ../rtl/hermeslite_core.v |sed 's/ =.* 8.d/=/'`; \
	dirname=../bitfiles/testing/"$${date}_$${VERSION_MAJOR}p$${VERSION_MINOR}_$${gitrev}"; \
	rm -rf $$dirname && mkdir $$dirname && \
	(cd release; tar cf - */*.rbf */*/*.rbf) | tar xf - -C $$dirname

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


.PHONY: all clean realclean radioberry radioberry-juice release
