# Makefile.am for installation/general

controldir = $(yast2dir)/control

control_DATA = \
	control.xml \
	control.dtd


EXTRA_DIST =  $(control_DATA)

install-data-local:
	install -d -m 755 $(DESTDIR)/var/lib/YaST2/control

include $(top_srcdir)/Makefile.am.common
