#
# Makefile.am for installation/x11
#

client_DATA = \
	inst_x11.ycp

fvwmdir = $(prefix)/X11R6/share/fvwm/
fvwm_DATA = \
	fvwmrc.yast2

EXTRA_DIST = $(client_DATA) $(fvwm_DATA)

YCPCFLAGS = -M ../modules

include $(top_srcdir)/Makefile.am.common
