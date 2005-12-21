#
# Makefile.am for installation/startup
#
ystartupbindir=$(ystartupdir)/startup/arch/ia64

install-data-local:
	-install -d -m 755 $(DESTDIR)/$(ystartupbindir)

ystartupbin_SCRIPTS =   \
	x11.sh

EXTRA_DIST = $(ystartupbin_SCRIPTS)
