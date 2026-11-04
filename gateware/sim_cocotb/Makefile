# Runs every cocotb testbench under this directory.
#
# Every subdirectory holding a Makefile is a self-contained cocotb build (its
# own Makefile, its own sim_build/), so this one only fans out: one log per
# testbench in test-logs/, a PASS/FAIL line each, and a tally at the end.  A
# failing testbench does not cut the run short.
#
#   make                 run everything, serially
#   make -j8             the same, up to 8 testbenches at once
#   make rx2 eth_arp     just those two (no tally; a failure fails directly)
#   make summary         just re-print the tally from the last run
#   make clean           remove test-logs/ plus every test's build artefacts
#
# Variables are exported to the sub-makes, e.g. `make SIM=icarus` or
# `make EXTRA_ARGS=--trace` for a testbench whose Makefile omits --trace.
#
# Output is one `== dir` line, then its PASS or FAIL, per testbench, plus the
# tally; nothing a testbench itself prints comes through, stdout or stderr.  It
# all lands in test-logs/<dir>.log, which a FAIL line points at.  That keeps the
# output legible under -j, where interleaved simulators would be unreadable, and
# means -s buys nothing.

# Every directory holding a Makefile is a testbench; $(dir) leaves a trailing
# slash on each name, so strip it to keep logs and markers named <dir>.log.
SUBDIRS := $(sort $(patsubst %/,%,$(filter-out ./,$(dir $(wildcard */Makefile)))))

LOGDIR := test-logs

# eth_icmp's Makefile builds its RTL paths from the environment's PWD and has
# no `PWD = $(shell pwd)` line of its own, so `make -C eth_icmp` would resolve
# them against this directory.  Passing PWD explicitly gives the sub-make the
# same value `cd eth_icmp && make` would; every other test's own
# `PWD = $(shell pwd)` evaluates to the identical string.
#
# Expands $@, so it is only usable from the per-directory rule below.
SUBMAKE = PWD="$(CURDIR)/$@" $(MAKE) --no-print-directory -C $@

# Phony because every one of them is also a real directory, whose mere
# existence would otherwise make it look up to date.
.PHONY: all summary clean $(SUBDIRS)

# `all` runs the fan-out in a sub-make with -k so a testbench that fails does
# not cut the run short, then hands over to the report target, which is the
# only thing allowed to exit non-zero.  Naming directories directly instead
# (make rx2 eth_arp) has no report step, so there a failure fails that target.
all:
	@$(MAKE) -k --no-print-directory $(SUBDIRS); \
	 $(MAKE) --no-print-directory summary

# Report only; reads the markers, so it is safe (and cheap) any time after a
# run, and `make summary` alone will not re-run a single simulation.
summary:
	@ok=0; bad=""; \
	for d in $(SUBDIRS); do \
	  if [ -f $(LOGDIR)/$$d.pass ]; then ok=$$((ok+1)); \
	  else bad="$$bad $$d"; fi; \
	done; \
	echo ""; \
	echo "$$ok/$$(set -- $(SUBDIRS); echo $$#) test directories passed"; \
	if [ -n "$$bad" ]; then echo "failed:$$bad (logs in $(LOGDIR)/)"; exit 1; fi

$(LOGDIR):
	@mkdir -p $(LOGDIR)

# Order-only on $(LOGDIR) so `make -j` cannot race the mkdir.  Each recipe
# makes its own directory because -j would otherwise start a testbench writing
# its log before the mkdir rule had run.  The marker only ever says "pass" and
# is written after the log, so a run left interrupted reads as a failure.
$(SUBDIRS): | $(LOGDIR)
	@echo "== $@"
	@mkdir -p $(LOGDIR); \
	if $(SUBMAKE) >$(LOGDIR)/$@.log 2>&1; \
	then echo "PASS $@"; : >$(LOGDIR)/$@.pass; \
	else echo "FAIL $@ (see $(LOGDIR)/$@.log)"; rm -f $(LOGDIR)/$@.pass; exit 1; fi

clean:
	@for d in $(SUBDIRS); do \
	  $(MAKE) --no-print-directory -C $$d clean >/dev/null 2>&1 || true; \
	done
	@rm -rf $(LOGDIR)
	@echo "cleaned $(words $(SUBDIRS)) test directories"
