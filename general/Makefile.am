#
# Makefile.am for installation/general
#

SUBDIRS = testsuite 

yncludedir = @yncludedir@/installation

ynclude_DATA = dialogs.ycp

client_DATA =					\
	inst_info.ycp				\
	inst_startup.ycp			\
	inst_mode.ycp				\
	inst_doit.ycp				\
	inst_finish.ycp				\
	inst_suseconfig.ycp			\
	inst_release_notes.ycp			\
	inst_congratulate.ycp			\
	installation.ycp

EXTRA_DIST = $(client_DATA) $(ynclude_DATA)

install-data-local:
	install -d -m 755 $(DESTDIR)/var/lib/YaST2
