# Release notes

Starting on version 4.0.3, yast2-installation will read release notes from RPM
packages ([FATE#323273](https://fate.suse.com/323273)) relying on the new API
introduced in yast2-packager 4.0.5.

As a consequence, YaST2 will need to know which package contains release notes
for a given product. This relationship will be defined in the release notes package
specification using the tag `release-notes()`:

    Provides: release-notes() = openSUSE

The package should contain a set of files with the following name:
`RELEASE-NOTES.[lang].[format]`, where `lang` and `format` should be replaced by
language code and format. For instance:

* `RELEASE-NOTES.en_US.txt` English version of release notes for textmode interface.
* `RELEASE-NOTES.de_DE.rtf` German version of release notes for graphical interface.
* `RELEASE-NOTES.es.rtf` Spanish version of release notes for graphical
  interface. Note that it is possible to use a two characters language code
  which will be used as fallback for `es_ES`, `es_AR`, etc.

Those files could be placed under any directory, although they usually will
live under `/usr/share/doc/release-notes/[product]/`. For instance,
`/usr/share/doc/release-notes/openSUSE`.
