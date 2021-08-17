YaST Installation Framework
===========================

[![Workflow Status](https://github.com/yast/yast-installation/workflows/CI/badge.svg?branch=master)](
https://github.com/yast/yast-installation/actions?query=branch%3Amaster)
[![Jenkins Status](https://ci.opensuse.org/buildStatus/icon?job=yast-yast-installation-master)](
https://ci.opensuse.org/view/Yast/job/yast-yast-installation-master/)
[![Coverage Status](https://coveralls.io/repos/github/yast/yast-installation/badge.svg?branch=master)](https://coveralls.io/github/yast/yast-installation?branch=master)

Description
============

This repository contains an installation framework based on the shared
functionality provided by [yast2](https://github.com/yast/yast-yast2/) project,
especially on [these libraries]
(https://github.com/yast/yast-yast2/tree/master/library/control/src/modules).

The framework typically calls different *experts in the field*, such as Network,
Storage or Users plug-ins to do the real job according to an installation
workflow described in a particular control file for:

- [openSUSE](https://github.com/yast/skelcd-control-openSUSE)
- [SLES](https://github.com/yast/skelcd-control-SLES)
- [SLED](https://github.com/yast/skelcd-control-SLED)

More subject-specific pieces of information can be found in the [doc](doc)
directory.

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
