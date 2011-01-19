#
# Makefile.am for installation/control/examples
#

include $(top_srcdir)/Makefile.am.common

xml_files =  $(wildcard *.xml)

EXTRA_DIST = $(xml_files)

# checks only those control files that belong to this package
check-local:
	xmllint --relaxng ../control.rng --noout $(xml_files)
