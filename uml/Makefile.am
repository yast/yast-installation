#
# Makefile.am for installation/uml
#

SUBDIRS = scripts

module_DATA =				\
	UML.ycp

client_DATA = uml.ycp			\
	uml_options_proposal.ycp	\
	uml_disks_proposal.ycp		\
	inst_uml_options.ycp		\
	inst_uml_disks.ycp		\
	inst_uml_kickoff.ycp

desktop_DATA = uml.desktop

EXTRA_DIST = $(module_DATA) $(client_DATA) $(desktop_DATA)

include $(top_srcdir)/Makefile.am.common
