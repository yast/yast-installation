# Makefile.am for installation/general
#

# process the current directory first
# (to ensure control.rng file is generated before it is
# used in the examples subdirectory)
SUBDIRS = . docs tests examples

controldir = $(yast2dir)/control

control_DATA = \
	control.xml \
	control.rnc \
	control.rng

xml_files = \
	control.SLED.xml \
	control.SLES.xml \
	control.openSUSE.xml \
	add-on-template_installation.xml

# Note: The control.glade -> control.xml symlink is required to make xgettext
# auto-detect the type of this file (glade) so it will extract all
# <label>..</label> tags. The symlink is created in the toplevel
# configure.in.in file upon "autoconf" (via "make -f Makefile.cvs").
# Unfortunately, CVS doesn't support checking in symlinks - it would duplicate
# the file. 

# Distribute also the generated control.rng file, the reason is that "trang"
# is a Java tool which adds huge dependency in OBS.
#
# The conversion happens during "make package" when building the tarball.
# The RNG file gets automatically updated after any change by the "control.rng"
# rule below.
#
# At build time the RNG file from tarball will have a newer time stamp
# and thus it will not need rebuild/update making "trang" unnecessary.
EXTRA_DIST =  $(control_DATA) $(product_DATA) $(xml_files) control.rng

include $(top_srcdir)/Makefile.am.common

control.rng: control.rnc
	trang -I rnc -O rng control.rnc control.rng

# checks only those control files that belong to this package
check-local: control.rng
	xmllint --relaxng control.rng --noout $(filter %.xml, $(xml_files) $(control_DATA))
