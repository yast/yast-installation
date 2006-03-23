# /.../
# Copyright (c) 2003 SuSE Linux AG Nuernberg, Germany.  All rights reserved.
# Author: Marcus Schäfer <ms@suse.de>, 2003
#
# Texing documentation stuff for 
# IBM Retail project
#
all:
	rm -f *.dvi *.idx *.toc *.log
	latex stage.tex
	latex stage.tex
	rm -f *.idx *.toc *.log *.bmt *.aux *.mtc*
	dvips stage.dvi
	dvipdf stage.dvi

clean:
	rm -f *.dvi *.idx *.toc *.log *.ps *.pdf
	rm -f *.aux *.mtc* *.out

dvi:
	xdvi stage.dvi
