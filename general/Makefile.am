#
# Makefile.am for installation/general
#

SUBDIRS = include testsuite

ynclude_DATA = showlog_defines.ycp

client_DATA =					\
	inst_ask_config.ycp			\
	inst_hw_config.ycp			\
	inst_confirm_abort.ycp			\
	inst_doit.ycp				\
	inst_finish.ycp				\
	inst_mode.ycp				\
	inst_startup.ycp			\
	inst_suseconfig.ycp			\
	inst_congratulate.ycp			\
	inst_release_notes.ycp			\
	installation.ycp

EXTRA_DIST = $(client_DATA) $(ynclude_DATA)

install-data-local:
	install -d -m 755 $(DESTDIR)/var/lib/YaST2
