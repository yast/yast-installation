# Makefile.am for installation/general

controldir = /usr/share/YaST2/control

control_DATA = control.xml


EXTRA_DIST =  $(control_DATA)

install-data-local:
	install -d -m 755 $(DESTDIR)/var/lib/YaST2/control

include $(top_srcdir)/Makefile.am.common
