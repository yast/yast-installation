# Installer Self-update

Starting on version 3.1.175, yast2-install is able to update itself during
system installation. This feature will help to solve problems with the
installation even after the media has been released. Check
[FATE#319716](https://fate.suse.com/319716) for a more in-depth rationale.

## Disabling Updates

Self-update is enabled by default. However, it can be disabled by setting
`self_update=0` boot option.

## Basic Workflow

These are the basic steps performed by YaST in order to perform the update:

1. During installation, YaST will look automatically for a rpm-md repository
   containing the updates.
2. If updates are available, they will be downloaded. Otherwise, the process
   will be silently skipped.
3. The update will be applied to the installation system.
4. YaST will be restarted and the installation will be resumed.

### Language Selection

The self-update step is executed before selecting the language
(`inst_complex_welcome` client). That means the self-update progress and
the errors which happens during the self-update process are by default displayed
in English.

To use another language also for the self-update press `F2` in the DVD boot menu
and select the language from the list. Or use the `language` boot option, e.g.
`language=de_DE`.


## Update Format

YaST will use RPM packages stored in a rpm-md repository, although they are
handled in a different way:

* All RPMs in the repository are considered (no "patch" metadata).
* RPMs are not installed in the usual way: they're uncompressed and no scripts
  are executed.
* No dependency checks are performed. RPMs are added in alphabetical order.

## Where to Find the Updates

The URL of the update repository is evaluated in this order:

1. The `SelfUpdate` boot option
2. The AutoYaST profile - in AutoYaST installation only, use the
   `/general/self_update_url` XML node:

   ```xml
   <general>
     <self_update_url>http://example.com/updates/$arch</self_update_url>
   </general>
   ```
3. Registration server (SCC/SMT), not available in openSUSE. The URL of the
   registration server which should be used is determined via:
   1. The `regurl` boot parameter
   2. AutoYaST profile ([reg_server element](https://www.suse.com/documentation/sles-12/singlehtml/book_autoyast/book_autoyast.html#CreateProfile.Register)).
   3. SLP lookup (this behavior applies to regular and AutoYaST installations):
      * If at least one server is found it will ask the user to choose one.
      * In AutoYaST mode SLP is skipped unless enabled in the profile in the
        registration section (see [documentation](https://www.suse.com/documentation/sles-12/singlehtml/book_autoyast/book_autoyast.html#idm140139881100304)).
        AutoYaST expects that only one server is reported by SLP, if more
        servers are found it is considered as an error and user interaction is
        required just like in manual installation.
   4. Default SUSE Customer Center API (`https://scc.suse.com/`).
4. Hard-coded in the `control.xml` file on the installation medium (thus it
   depends on the base product):

   ```xml
   <globals>
     <self_update_url>http://updates.suse.com/sle12/$arch</self_update_url>
   </globals>
   ```

The first suitable URL will be used. There are two exceptions:

* Of course, if no update URL is found then the self-update is skipped.
* If SCC/SMT provides multiple URLs, they will be all used.

The URL can contain a variable `$arch` that will be replaced by the system's
architecture, such as `x86_64`, `s390x`, etc. You can find more information
in the [Arch module](http://www.rubydoc.info/github/yast/yast-yast2/Yast/ArchClass).

### Actual URLs

When using registration servers, the regular update URLs have the form
`https://updates.suse.com/SUSE/Updates/$PRODUCT/$VERSION/$ARCH/update` where
- PRODUCT is like OpenStack-Cloud, SLE-DESKTOP, SLE-SDK, SLE-SERVER,
- VERSION (for SLE-SERVER) is like 12, 12-SP1,
- ARCH is one of aarch64 i586 ia64 ppc ppc64 ppc64le s390x x86_64

For the self-update the *PRODUCT* is replaced
with *PRODUCT*-INSTALLER, producing these repository paths
under https://updates.suse.com/
- /SUSE/Updates/SLE-DESKTOP-INSTALLER/12-SP2/x86_64/update
- /SUSE/Updates/SLE-SERVER-INSTALLER/12-SP2/aarch64/update
- /SUSE/Updates/SLE-SERVER-INSTALLER/12-SP2/ppc64le/update
- /SUSE/Updates/SLE-SERVER-INSTALLER/12-SP2/s390x/update
- /SUSE/Updates/SLE-SERVER-INSTALLER/12-SP2/x86_64/update

## Security

Updates signatures will be checked by libzypp. If the signature is not
correct (or is missing), the user will be asked whether she/he wants to apply
the update (although it's a security risk).

When using AutoYaST, this behavior can be modified including the
[/general/signature-handling](https://www.suse.com/documentation/sles-12/singlehtml/book_autoyast/book_autoyast.html#idm140139881381840)
section in the profile.

On the other hand, if SLP discovery is enabled, a popup is displayed to choose the
server to use. SLP by default does not use any authentication, everybody on the
local network can announce a registration server.

## Self-update and User Updates

Changes introduced by the user via Driver Updates (`dud` boot option) will take
precedence. As you may know, user driver updates are applied first (before the
self-update is performed).

However, the user changes will be re-applied on top of the installer updates.

## Resume installation

Any client called before the self-update step is responsible to remember its state (if
needed) and automatically going to the next dialog after the YaST restart.
Once the self-update step is reached again it will remove the restarting flag.

The self-update step is called very early in the workflow, for the self-update
step only configured network is needed. That is configured either by `linuxrc`
or by the `setup_dhcp` YaST client which does not need to remember any state.

## Supported URL Schemes

Currently only HTTP/HTTPS and FTP URL schemes are supported for downloading
the updates. Some additional schemes might work but are not tested and therefore
not supported.

## Error handling

Errors during the installer update are handled as described below:

* If network is not available, the installer update will be skipped.
* If the network is configured but the installer updates repository or the
  registration server are not reachable:
  * in a regular installation/upgrade, YaST2 will offer the possibility
    to check/adjust the network configuration.
  * in an AutoYaST installation/upgrade, a warning will be shown.
* If the updates repository is found but it is empty or not valid:
  * in the case that the URL was specified by the user (using the *SelfUpdate* boot
    option or through the *self_update_url* element in an AutoYaST profile), an
    error message will be shown.
  * if the URL was not specified by the user, the installer will skip the update
    process (it will assume that no updates are available).
* If something goes wrong trying to fetch and apply the update, the user will be
  notified.
