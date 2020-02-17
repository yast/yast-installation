# The yupdate Script

This is a documentation for the `yupdate` helper script,
which is included in the YaST installer in SLE15-SP2/openSUSE
Leap 15.2 (or newer) and in the openSUSE Tumbleweed since
build 2020xxxx.

## The Introduction

**Problem**: You are developing a feature for the installer and you need to
test your changes frequently. For extra fun, the change is spread across
multiple repositories.

The YaST installation system is quite different to an
usual Linux installed system. The root filesystem
is stored in a RAM disk and most files are read-only.
That makes it quite difficult to modify the YaST installer
if you need to debug a problem or test a fix.

There are some possibilities for updating the YaST installer
(see [Alternative](#Alternative))
but they are usually not trivial and need special preparations.
For this reason we created a special `yupdate` script which makes
the process easier.

However, in some cases this easier way cannot be used, see the
[limitations](#limitations) section below.


## Self-update

After patching the installer the `yupdate` script disables
the YaST self-update feature because it could conflict with it
and overwrite the changes.

If you need some changes from the self-update then use the `startshell=1`
boot option, start the installer and allow the self-update step to finish,
then abort the installation and use the `ypdate` script to apply the
changes on top of the self-update.

##  Warning

:warning: **Patching the installer with the `yupdate` script makes
the installation unsupported!** :warning:

The script is intended for developers to test new features or bug fixes.

It can be used by customers for testing as well, but it should not be used
on production systems!

## Installation

The `yupdate` script should run in the inst-sys. Since SLE15-SP2/openSUSE
Leap 15.2, openSUSE Tumbleweed 2020xxxx, it ~~is~~ will be preinstalled.

For older releases, run:

```shell
curl https://raw.githubusercontent.com/yast/yast-installation/master/bin/yupdate > /usr/bin/yupdate
chmod +x /usr/bin/yupdate
```

You can also use this command to update the included script
to the latest version.

## Basic Use Cases

This script is intended to help in the following scenarios.

### Make the inst-sys Writable

As already mentioned, the files in the installation system are read only. To be
able to patch the installer the script must be able to make the files writable.
It does that automatically for the updated files, but maybe you would like to
use this feature also for some other non-YaST files.

To make a directory writable in the inst-sys run command

```shell
yupdate overlay create <dir>
```

This will create a writable overlay above the specified directory. If you do not
specify any directory it will create writable overlays for the default YaST
directories.

Then you can easily edit the files using the included `vim` editor
or by other tools like `sed` or overwrite by external files.

### Patch YaST from GitHub Sources

To update or install an YaST package directly from the GitHub source code
repository use command

```shell
yupdate patch <github_slug> <branch>
```

where `github_slug` is a `user`/`repository` name, if the `user` value is
missing the default "yast" is used. The `branch` in the source branch to
install, for example `master` or `SLE-15-SP2`.


#### Examples

```shell
# install the latest version of yast2-installation from upstream
yupdate patch yast-installation master
# install from a fork
yupdate patch my_fork/yast-installation my_branch
```

#### Notes

- Make sure that you use a branch compatible with the running inst-sys,
  installing the latest version in an older release might not work
  as expect, the installer might crash or behave unexpectedly.
- There is no dependency resolution, if the new installed package
  requires newer dependant packages then they must be installed manually.

### Patch YaST from Locally Modified Sources

Installing from GitHub sources is easy, but sometimes you do not want to
push every single change to GitHub, you would like to just use the current
files from you local Git checkout.

In that case run

```shell
rake server
```

in your YaST module Git checkout. This will run a web server providing source
tarball similar to the GitHub archive used in the previous case.

*Note: You need "yast-rake" Ruby gem version 0.2.37 or newer.*

Then run

```shell
yupdate patch <host_name>
```

where `<host_name>`  is the machine host name or the IP address where you run
the `rake server` task. To make it easier the rake task prints these values at
the start.

By default this will use port 8000, if the server uses another port just add
`:` followed by the port number.

*Note: Make sure the server port is open in the firewall configuration,
see the [documentation](https://github.com/yast/yast-rake/#server) for
more details.*

#### Patching Multiple Packages

The `yupdate patch` command installs the sources from all running `rake server`
servers. If you need to update sources from several packages you can just
run `rake server` in all of them and install them with a single `yupdate`
call.

### Patch YaST from a Generic Tarball Archive

This is similar to the previous cases, but the source tarball is not generated
dynamically by a server, but it is a statically hosted file.

Example:

```shell
yupdate patch http://myserver.example.com/test/yast2.tar.gz
```

## Other Commands

### Listing OverlayFS Mounts

To see the list of mounted OverlayFS run

```shell
yupdate overlay list
```

### Listing Updated Files

To see the list of changed files

```shell
yupdate overlay files
```

### Displaying Changes in the System

To see the applied changes to the system run

```shell
yupdate overlay diff
```

This will display a diff for all changed files, it does not report
deleted or new files.

### Restoring the System

To revert all changes run

```shell
yupdate overlay reset
```

This will remove *all* OverlayFS mounts and restore the system to the original
state.

## Limitations

- The script only works with Ruby source files, it cannot compile and
  install C/C++ or other sources (the compiler and development libraries
  are missing in the inst-sys)
- Works only with the packages which use `Rakefile` for installation,
  it does not work with autotools based packages (again, autoconf/automake
  are also missing in the inst-sys)

## Alternative

1. For all repos, run `rake osc:build`
2. Collect the resulting RPMs
3. Run a server, eg. with `ruby -run -e httpd -- -p 8888 .`
4. Type a loooong boot line to pass them all as DUD=http://....rpm
   (or write that into a file and use the [info](
   https://en.opensuse.org/SDB:Linuxrc#p_info) option
   or build a single DUD file from the RPMs with the [`mkdud`](
   https://github.com/wfeldt/mkdud) script)

## Implementation Details

### OverlayFS

To make the inst-sys directories writable we use the Linux OverlayFS
which can merge already existing file systems ("union filesystem").

See more details in the [Linux Kernel Documentation](
https://www.kernel.org/doc/Documentation/filesystems/overlayfs.txt).

### Installing the Files

For installing the sources the script uses the `rake install DESTDIR=...`
command and install the files into a temporary directory. Then it compares
the new files with the original files and if there is a change the old
file is rewritten by the new file.

This also skips some not needed files like documentation, manual pages,
editor backup files, etc...

This saves some memory as we do not need to shadow the not modified files
with the same content.

### Logging

The messages printed on the console are also saved in the `y2log` file.
That means it should be easy to find out that someone patched the installer
when analyzing logs from a bug report.
