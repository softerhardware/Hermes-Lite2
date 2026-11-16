
all:
	$(MAKE) -C hl2b5up_main
	$(MAKE) -C hl2b5up_6rx
	$(MAKE) -C hl2b5up_cicrx

release:
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

clean:
	$(MAKE) -C hl2b5up_main clean
	$(MAKE) -C hl2b5up_6rx clean
	$(MAKE) -C hl2b5up_cicrx clean

realclean:
	$(MAKE) -C hl2b5up_main realclean
	$(MAKE) -C hl2b5up_6rx realclean
	$(MAKE) -C hl2b5up_cicrx realclean


.PHONY: all clean realclean release
