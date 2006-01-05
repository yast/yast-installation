#
# Makefile.am for installation/startup
#
ystartupbindir=$(ystartupdir)/startup/arch/s390

install-data-local:
	-install -d -m 755 $(DESTDIR)/$(ystartupbindir)

ystartupbin_SCRIPTS =   \
	console.sh

EXTRA_DIST = $(ystartupbin_SCRIPTS)
