# Installation process overview

The purpose of this document is to offer some information about
how the installation process of SUSE and openSUSE works from a
technical point of view. It is, in no way, oriented to the end-user
although it could be easily understood for a regular Linux user.

Different installation modes are supported, ranging from a regular installation
to an unattended one. Also system update or repair are supported. You could
take a look at [yast-yast2
repository](https://github.com/yast/yast-yast2/blob/master/library/general/src/modules/Mode.rb)
to learn more about that. This document is mainly about `installation` and
`autoinstallation` modes.

## Overview

Although _YaST_ sits at the central point of the installation process, it is
not the only software involved.
[_Linuxrc_](https://en.opensuse.org/SDB:Linuxrc), which will be started just
before _YaST_, is another key player.

_Linuxrc_ sets up the hardware and initializes the installation process. It can
do very cool things and have a [lot of
options](https://en.opensuse.org/SDB:Linuxrc#Parameter_Reference) for you to
tweak. Newcomers should take a look at `startshell`, `netdevice`, `netsetup`
and, of course, `autoyast` options.

After the system is started, a script called `/sbin/inst_setup` is ran. That
script performs some initialization tasks and, at the end, calls _YaST first
stage_ (known as `initial`). This is the main part of the installation
workflow: disks are set up (partitions and filesystem), software is installed,
boot loader is prepared, etc. When the _first stage_ is over, the machine is
rebooted to get into _YaST second stage_ (known as `continue`) if needed.

That second stage is not always needed. As of SLE 12 and openSUSE 13.2 and
later, a regular installation is done just during the _YaST2 First Stage_ and
the second one is not used anymore. When it comes to AutoYaST, the [second
stage is used for system
configuration](https://www.suse.com/documentation/sles-12/singlehtml/book_autoyast/book_autoyast.html#overviewandconcept).

Let’s see the process in a more detailed way.

### Installer boot process

After the system boots, the first program to run is `/sbin/inst_setup`. It’s a
shell script that performs some initialization tasks and, at the end, it
invokes the _YaST2 first stage_.

Among `inst_setup` initialization tasks, we could highlight:

* Starting basic services like klog, syslog or nscd.
* Setting host and domain names.
* Managing YaST driver updates.
* Handling the SSH installation (letting the user start the process through `yast.ssh`).
* Registering the VNC service through SLP if needed.
* Handling the `STARTSHELL` parameter to launch a shell before starting YaST if
  it was requested by the user.

Unless SSH must be used to perform the installation, `inst_setup` will start
the __YaST2.First-Stage__ just executing `/sbin/yast`. Otherwise, the user will
launch _YaST_ calling `yast.ssh`.

### YaST2.First-Stage

At this stage, `/sbin/yast` is just a symbolic link to
`/usr/lib/YaST2/startup/YaST2.First-Stage`. The main purpose of this script is
to kick off the installation process (through `yast-installation`). After some
initialization work (described below), this script goes through a series of
steps defined scripts at `/usr/lib/YaST2/startup/First-Stage`.

So the workflow is something like:

* Import installation settings from `/etc/install.inf` as environment variables
  (`import_install_inf` at `/usr/lib/YaST2/startup/common/misc.sh`).
* Enable logging into `/var/log/YaST2/y2start.log`.
* Execute `preFirstStage` [hooks](https://github.com/yast/yast-yast2/blob/master/library/general/doc/Hooks.md).
* Execute the `FirstStage` (see stages/steps). Additional `preFirstCall` and `postFirstCall` hooks are called.
  _YaST_ gets called at this point.
* Execute `postFirstStage` hooks.

Finally, the script exits (returning the error code from YaST) and control is
returned to `/sbin/inst_setup`.

#### Stages/Steps

Maybe the use of the term _stage_ here could be somewhat confusing. You must
just take into account that the following _stages_ are just the _steps_
performed during the installation’s _First Stage_. We keep the term _stage_ to
refer to both of them just because it’s the way they’re called in the source
code.

If you want to know the nitty-gritty details of those steps, you could find them
at `/usr/lib/YaST2/startup/First-Stage`.

1. Hardware detection through `hwinfo`.
2. Umount `inst-sys` (`/var/adm/mount`).
3. Set up the language. Remember that you could specify a language through
   the Linuxrc parameter `language`.
4. Handle kernel parameters. A this time, it only copy `repair` to `install.inf` is present.
5. Configure the terminal (and save TERM to `/etc/install.inf`).
6. Set environment variables related to YaST log (size and max logs count).
7. Start YaST in installation mode (`yast-installation`) with
   `/usr/lib/YaST2/startup/YaST2.call installation initial`.
8. Umount partitions and write exit code at `/tmp/YaST2-First-Stage-Exit-Code`.

#### inst_worker_initial

For _YaST_, the installation is now in the `initial`
[stage](https://github.com/yast/yast-yast2/blob/master/library/general/src/modules/Stage.rb).
At this point, the `installation` client relies on
[`inst_worker_initial`](src/clients/inst_worker_initial.rb). You could take a
look at the documentation about [installation
clients](doc/installation_clients.md) to learn more.

Depending on the [installation
mode](https://github.com/yast/yast-yast2/blob/master/library/general/src/modules/Mode.rb),
which is set to `installation` by default, some initialization tasks are
performed and flow control is hand over to
[ProductControl](https://github.com/yast/yast-yast2/blob/master/library/control/src/modules/ProductControl.rb)
module, which is responsible of driving the installation process.

Just as a side note, if `/etc/install.inf` contains an `AutoYaST` entry, mode will be set to
`autoinstall` and the installation will be handled by _AutoYaST_.

### YaST2.Second-Stage

After the first reboot, the _YaST2.Second-Stage_ comes into action. It’s defined as a systemd
service (take a look at
[YaST2.Second-Stage.service](https://github.com/yast/yast-installation/blob/master/package/YaST2-Second-Stage.service)).
This service is ran only if a file `/var/lib/YaST2/runme_at_boot` exists.

The script is located at `/usr/lib/YaST2/startup/YaST2.Second-Stage` and, as _first stage_,
it performs some initializations tasks and then go through a series of steps defined as
scripts at `/usr/lib/YaST2/startup/Second-Stage`.

#### Initialization

* Disable splash screen.
* Import installation settings from `/etc/install.inf` as environment variables.
* Set up architecture variables.
* Prepare manpages and info files directories.
* Start startup logging at `/var/log/YaST2/y2start.log`.
* Execute `preSecondStage` [hooks](https://github.com/yast/yast-yast2/blob/master/library/general/doc/Hooks.md).
* Execute the `SecondStage` (see stages). Additional `preSecondCall` and `postSecondCall` hooks are executed.
  _YaST_ gets called at this point.
* Execute `postSecondStage` hooks.

#### Stages/steps

The scripts which perform these steps live in
`/usr/lib/YaST2/startup/Second-Stage`. They are responsible for:

* Setting up logging (including `syslogd`).
* If `/var/lib/autoinstall/autoconf/autoconf.xml` is found, then _AutoYaST_ is started
  (as `/usr/lib/YaST2/startup/YaST2.call installation continue`) and, after it exits,
  the second stage is over (next steps won’t be executed).
* Setting up language stuff (`LC_ALL` and `LANG` environment variables).
* Setting up virtual console.
* Starting services as `pcmcia` or `hald` (Hardware Abstraction Layer).
* Bringing up network (if configuration is found), starting a second shell and
  getting prepared for a VNC installation (if needed).
* Starting YaST. If installation is done through SSH, at this point the user
  must log in and launch YaST manually.
* Cleaning up things when installation is finished.

#### inst_worker_continue

The client which drives the second stage is
[`inst_worker_continue`](src/clients/inst_worker_continue.rb). Of course, it
relies on `ProductControl` as `inst_worker_initial` does.

### YaST2.call

During installation, _YaST_ is invoked through `YaST2.call` script. This script is
responsible for detecting the installation medium: Qt, SSH, VNC and ncurses.
It also checks requirements for selected medium and falls back to ncurses if they
are not met.

## The control file

_YaST_ installation process is really very flexible. What actions must be taken in
different modes and scenarios are described in the _control file_. _YaST_ searches for that file
in `/y2update/control.xml`, `/control.xml` and `/etc/YaST2/control.xml` and each SUSE product will
have their own file.

Quite nice [documentation](control-file.md) lives in this repository about
the content of these files.
