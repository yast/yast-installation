#
# Makefile.am 
#
STYLESHEET_FO=$(ydatadir)/docbook/stylesheets/customize-fo.xsl
STYLESHEET_HTML=$(ydatadir)/docbook/stylesheets/customize-html.xsl
COMPONENT=control-doc

htmldir = $(docdir)/$(COMPONENT)

html: html/index.html html/susebooks.css

pdf: clean.xml $(COMPONENT).pdf

validate:
	xmllint --xinclude --valid --noout $(COMPONENT).xml

$(COMPONENT).fo: $(COMPONENT).xml
	xsltproc --xinclude -o $(COMPONENT).fo $(STYLESHEET_FO)  $(COMPONENT).xml

$(COMPONENT).pdf: $(COMPONENT).fo
	fop -q $(COMPONENT).fo $(COMPONENT).pdf


html/susebooks.css:
	cp $(ydatadir)/docbook/css/susebooks.css html
	cp -a $(ydatadir)/docbook/images html

clean.xml: control-section.xml
	xmllint --xinclude --noent --dropdtd -o $@ $<
	cp $@ control-section_mod.xml
	

html/index.html: clean.xml
	xsltproc --xinclude $(STYLESHEET_HTML) $(COMPONENT).xml

html_DATA = $(wildcard html/*) 

EXTRA_DIST = *.xml $(html_DATA)

CLEANFILES = CATALOG.local *.out *.aux *.dvi *.tex *.ps *.pdf *.log *.dsl *.fo clean.xml

clean-local:
	rm -rf html/*.html
