# Makefile.am for installation/x11

module_DATA = \
	X11Version.ycp

client_DATA = \
	inst_x11.ycp

fvwmdir = /usr/X11R6/share/fvwm/
fvwm_DATA = \
	fvwmrc.notitle

EXTRA_DIST = $(client_DATA) $(module_DATA) $(fvwm_DATA)

YCPCFLAGS = -M ../modules

include $(top_srcdir)/Makefile.am.common
