#
# Makefile.am for y2m_inst/scripts
#

SUBDIRS = x11

sbindir = /sbin
sbin_SCRIPTS = yast2

ybin_SCRIPTS = YaST2 YaST2.start YaST2.firstboot check.boot yast2_kde	\
	ask_for_TERM_variable inst_setup_vnc yast2-funcs

EXTRA_DIST = $(sbin_SCRIPTS) $(ybin_SCRIPTS)

install-data-local:
	install -d -m 755 $(DESTDIR)$(ybindir)
	ln -snf $(DESTDIR)$(sbindir)/yast2 $(DESTDIR)$(sbindir)/zast2
	ln -snf $(DESTDIR)$(sbindir)/yast2 $(DESTDIR)$(sbindir)/YaST2
	ln -snf $(DESTDIR)$(sbindir)/yast2 $(DESTDIR)$(sbindir)/ZaST2
	ln -snf $(DESTDIR)$(sbindir)/yast2 $(DESTDIR)$(sbindir)/yast
	ln -snf $(DESTDIR)$(sbindir)/yast2 $(DESTDIR)$(sbindir)/zast
	ln -snf $(DESTDIR)$(sbindir)/yast2 $(DESTDIR)$(sbindir)/YaST
	ln -snf $(DESTDIR)$(sbindir)/yast2 $(DESTDIR)$(sbindir)/ZaST
	ln -snf $(DESTDIR)$(sbindir)/yast2 $(DESTDIR)$(sbindir)/zastì
	ln -snf $(DESTDIR)$(sbindir)/yast2 $(DESTDIR)$(sbindir)/ZaSTì
	ln -snf $(DESTDIR)$(sbindir)/yast2 $(DESTDIR)$(sbindir)/YaSTì
	ln -snf $(DESTDIR)$(sbindir)/yast2 $(DESTDIR)$(sbindir)/yastì
