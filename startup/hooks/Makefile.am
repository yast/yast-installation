#
# Makefile.am for installation/startup
#
ystartupbindir=$(ystartupdir)/startup/hooks

install-data-local:
	-install -d -m 755 $(DESTDIR)/$(ystartupbindir)

SUBDIRS = \
	postFirstCall postFirstStage postSecondCall postSecondStage \
	preFirstCall preFirstStage preSecondCall preSecondStage
