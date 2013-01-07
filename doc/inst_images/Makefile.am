SUBDIRS = 

xml_files =  $(wildcard *.xml) $(wildcard examples/*.xml)

html_DATA = $(wildcard html/*.html) \
	    html/yast2docs.css

all-local: html/index.html

html/index.html: inst_images.xml
	XML_CATALOG_FILES=@XML_CATALOG@ \
	@XSLTPROC@ @XSLTPROC_FLAGS@ --xinclude \
	@STYLESHEET_HTML@ $<

html/yast2docs.css: html/index.html
	cp @STYLESHEET_CSS@ html
	cp -a `pkg-config --variable=yast2dir yast2-devtools`/data/docbook/images html

EXTRA_DIST =  $(xml_files)

CLEANFILES =  $(html_DATA)

clean-local:
	rm -rf html

install-data-local:
	mkdir -p $(DESTDIR)$(htmldir)
	cp -a $(srcdir)/html/images $(DESTDIR)$(htmldir)
