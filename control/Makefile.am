# Makefile.am for installation/general

controldir = $(yast2dir)/control

control_DATA = \
	control.xml \
	control.dtd

# Note: The control.glade -> control.xml symlink is required to make xgettext
# auto-detect the type of this file (glade) so it will extract all
# <label>..</label> tags. The symlink is created in the toplevel
# configure.in.in file upon "autoconf" (via "make -f Makefile.cvs").
# Unfortunately, CVS doesn't support checking in symlinks - it would duplicate
# the file. 


EXTRA_DIST =  $(control_DATA)

install-data-local:
	install -d -m 755 $(DESTDIR)/var/lib/YaST2/control

include $(top_srcdir)/Makefile.am.common
