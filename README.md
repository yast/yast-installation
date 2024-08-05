YaST Installation Framework
===========================

[![Workflow Status](https://github.com/yast/yast-installation/workflows/CI/badge.svg?branch=master)](
https://github.com/yast/yast-installation/actions?query=branch%3Amaster)
[![OBS](https://github.com/yast/yast-installation/actions/workflows/submit.yml/badge.svg)](https://github.com/yast/yast-installation/actions/workflows/submit.yml)
[![Coverage Status](https://coveralls.io/repos/github/yast/yast-installation/badge.svg?branch=master)](https://coveralls.io/github/yast/yast-installation?branch=master)

Description
============

This repository contains an installation framework based on the shared
functionality provided by [yast2](https://github.com/yast/yast-yast2/) project,
especially on [these libraries](https://github.com/yast/yast-yast2/tree/master/library/control/src/modules).

The framework typically calls different *experts in the field*, such as Network,
Storage or Users plug-ins to do the real job according to an installation
workflow described in a particular control file for:

- [openSUSE](https://github.com/yast/skelcd-control-openSUSE)
- [SLES](https://github.com/yast/skelcd-control-SLES)
- [SLED](https://github.com/yast/skelcd-control-SLED)

More subject-specific pieces of information can be found in the [doc](doc)
directory.

- [URL handling in the installer](doc/url.md) for an overview of the URLs
  supported in various places, including `cd:`, `cifs:`, `device:`, `disk:`,
  `dvd:`, `file:`, `ftp:`, `hd:`, `http:`, `https:`, `iso:`, `label:`, `nfs:`,
  `rel:`, `relurl:`, `repo:`, `slp:`, `smb:`, `tftp:`, `usb:`.

Live Installation
-----------------

The standard and supported way for openSUSE/SLE installation is
to boot directly into the installation program, without anything else running.

An *unsupported* alternative is to boot a Live CD/Live USB and start the
installation from its desktop.

### History

There used to be a separate package [yast2-live-installer][] which was
dropped from SLES-12-SP3 in 2016/17: [FATE321360][] (non-public link).

Then Live Installation was brought back in yast2-installation (this repo)
around 2019/2020 but [the status is a bit
unclear](https://bugzilla.suse.com/show_bug.cgi?id=1155545#c18).

[yast2-live-installer]: https://github.com/yast/yast-live-installer
[FATE321360]: https://w3.suse.de/~lpechacek/fate-archive/321360.html

### Status

A Jira epic [PM-1565] (non-public link) exists to clarify: "The
possibility to Install directly from LiveCD was dead and now it's resurrected,
but can't work without a lot of effort".

There's a matching team Trello card [PM-1565-PBI][] (non-public link), not yet
scheduled to be worked on.

[PM-1565]: https://jira.suse.com/browse/PM-1565
[PM-1565-PBI]: https://trello.com/c/ueqrCN8I/3630-improve-live-installation-usability-and-behavior

Development
===========

This module is developed as part of YaST. See the
[development documentation](http://yastgithubio.readthedocs.org/en/latest/development/).


Getting the Sources
===================

To get the source code, clone the GitHub repository:

    $ git clone https://github.com/yast/yast-installation.git

If you want to contribute into the project you can
[fork](https://help.github.com/articles/fork-a-repo/) the repository and clone your fork.


Contact
=======

If you have any question, feel free to ask at the [development mailing
list](http://lists.opensuse.org/yast-devel/) or at the
[#yast](https://web.libera.chat/#yast) IRC channel on libera.chat.
