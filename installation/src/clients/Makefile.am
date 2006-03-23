# Makefile.am for installation/general

client_DATA =	$(wildcard *.ycp)

EXTRA_DIST = $(client_DATA)

install-data-local:
	-install -d -m 755 $(DESTDIR)/var/lib/YaST2

include $(top_srcdir)/Makefile.am.common
