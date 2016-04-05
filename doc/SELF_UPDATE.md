# Installer self-update

Starting on version 3.1.175, yast2-install is able to update itself during
system installation. This feature will help to solve problems with the
installation even after the media has been released. Check
[FATE#319716](https://fate.suse.com/319716) for a more in-depth rationale.

## Disabling updates

Self-update is enabled by default. However, it can be disabled setting
`self_update=0` in Linuxrc.

## Basic workflow

These are the basic steps performed by YaST in order to peform the update:

1. During installation, YaST will look automatically for a rpm-md repository
   containing the updates.
2. If updates are available, they will be downloaded. Otherwise, the process
   will be silently skipped.
3. The update will be applied to the installation system.
4. YaST will be restarted and the installation will be resumed.

## Update format

YaST will use RPM packages stored in a rpm-md repository, although they are
handled in a different way:

* All RPMs in the repository are considered (no "patch" metadata).
* RPMs are not installed in the usual way: they're uncompressed and no scripts
  are executed.
* No dependency checks are performed. RPMs are added in alphabetical order.

## Where to find updates

The URL of the update repository can be hard-coded in `control.xml` file or
specified setting `SelfUpdate` option in Linuxrc.

The URL can contain a variable `$arch` that will be replaced by the system's
architecture, such as `x86_64`, `s390x`, etc. You can find more information
in the [Arch module](http://www.rubydoc.info/github/yast/yast-yast2/Yast/ArchClass).

```xml
<globals>
  <self_update_url>http://updates.suse.com/sle12/$arch</self_update_url>
</globals>
```

## Security

Updates signatures will be checked by libzypp. If the signature is not
correct (or is missing), the user will be asked whether she/he wants to apply
the update (although it's a security risk).

## Self-update and user updates

Changes introduced by the user via Driver Updates (option `dud` in Linuxrc
command line) will take precedence. As you may know, user driver updates
are applied first (before the self-update is performed).

However, user changes will be re-applied on top of installer updates.