Product Installation Control
============================

Functionality
-------------

The product control enables customization of the installation makes it
possible to enable and disable features during installation in the final
installed product. It controls the workflow and what is really shown to
the user during installation.

Beside workflow configuration, other system variables are configurable
and can be predefined by the system administrator, to name a few: the
software selection, environment settings such as language, time zone and
keyboard can be configured and would override default variables provided
with shipped products.

The idea of having a pre-defined installation workflow and pre-defined
system settings provides a middle ground between manual installation and
automated installation.

The product configuration file is provided as a text file on the
installation media and defines various settings needed during
installation. The following is a list of supported configuration
options:

-   Workflow

    Replaces the static workflow list with a configurable list using the
    product configuration file. Entire sections of the workflow can be
    skipped.

    For example, it is possible to set the language variable in the
    configuration file if the installation language is to be forced for
    some reason, eg. if an IT department wants to force French
    installations, say in Quebec, Canada, then the entire dialogue can
    be skipped. If the IT department is to recommend some settings but
    still give the user the choice to change the default settings, the
    language dialogue will be shown with French preselected.

    If none of the above options is used, the default dialogue settings
    are shown.

-   Proposals

    As with the workflow, proposals are also configurable. For example,
    certain products would skip some proposals. In the proposal screen
    the pre-configured settings can be shown with the possibility to
    change them or with inactive links if the configuration is to be
    forced.

-   System Variables

    Let the user define system variables like language, keyboard, time
    zone, window manager, display manager etc. The defined variables
    will be used as defaults in the respective dialogues.

-   Package Selections and additional individual packages

    Define what base package selection and add-on selections should be
    used for the installation. Additionally provide the possibility to
    define a list of additional packages. All packages and selections
    can be selected depending on the architecture using a special
    architecture attribute in the configuration file.

-   Partitioning

    Integrates flexible partitioning into configuration file, instead of
    the separate file currently used.

-   Scripting and Hooks

    To customize installation further more, hooks and special slots can
    be defined where the user can execute scripts. For example, scripts
    can be executed at the very beginning of the installation (After
    processing the configuration file), in the installation system
    before initial boot, in the chroot-ed environment and after initial
    boot and before/after every step in the workflow. Scripting
    languages supported during installation are currently Shell, Perl.

Implementation
--------------

The control file is implemented in simple structured XML syntax which so
far has been used for automated installation . The XML structure used
can be mapped easily to YaST data structures and all data types
available in YaST are supported for easy data access and manipulation.

The primary use of the control file is to configure the workflow of the
installation and it offers the possibility to predefine a certain setup,
but it also defines product installation features and other product
related variables.

> **Note**
>
> Note that the control file is not an optional tool to help customize
> installation, it is required during installation and without the file,
> installation may fail or lead to unexpected results. Control file on installed
> system located in `/etc/YaST2/control.xml` is owned by ${PRODUCT}-release
> package.

During installation, *linuxrc* searches for a file named
`control.xml` on the installation medium (CD, NFS, FTP..) and copies the
file into the installation system and makes the file available to YaST.
YaST then starts and looks for the control file in 3 location before it
starts with the installation workflow:

0.  custom control file - runtime specified control file. Used only in special
    cases like wagon upgrade work-flow.

1.  `/y2update/control.xml`

    File in special directory to update installer on-fly. Needed only for
    work-arounds and customer specific solutions.

2.  `/control.xml`

    Usually the file is in top directory after it has been copied by
    linuxrc and during initial installation phase.

3.  `/etc/YaST2/control.xml`

    This is the location where release package installs the file of
    installed product.

One of the main reasons for using the control is to provide non YaST
developers the ability to change the installation behavior and customize
various settings without the need to change and re-build YaST packages.

The control files for some SUSE products are maintained at
yast2-installation source tree in directory `control`.

Configuration
-------------

### Workflows

Using the control file, multiple workflows can be defined for different
modes and installation stages. Thus, the element *workflows* in the
control file evaluates to a list of workflows.

Beside defining what YaST clients should be executed during
installation, the workflow configuration also let you specify the wizard
steps and how they should appear during graphical installation.

A workflow list element is a map with the following elements:

-   *label*

    The label of the workflow as it appears on the left side of the
    wizard. For example *Base Installation*

-   *defaults*

    The default arguments to the clients. This is a map element.

-   *stage*

    This options defines the stage or phase of installation.. Possible
    values are *initial* for the initial stage and *continue* for the
    workflow of the installation after reboot

-   *mode*

    Defines installation mode. Several modes are available, most
    important modes are:

    -   installation

    -   update

    -   autoinst

-   *modules*

    This is the actual workflow and is a list of elements describing the
    order in which the installation should proceed.

    A module element is a map with the following configuration options:

    -   name: The name of the module. All installation clients and
        modules have a unified prefix (inst\_) which can be ommited
        here. Name is ofted used as ID, so it better be inique within the whole
        control file. That is why we have execute parameter, see below. For
        example, if the YaST file for the module is called *inst\_test*, then
        the name in the control file is *test*

    -   label: The label of the module in the step dialog. This is an
        optional element. If it is not set, the label of the previous
        module is used.

    -   arguments: The arguments for the module is a comma separated
        list which can accept booleans and symbols.

    -   execute: If it is needed to call script that does not start with 
        *inst_* or you need to call the same script several times with
        different *name* parameter.

The following listing shows a typical installation workflow:

```
    <workflows config:type="list">
        <workflow>
            <!-- 'label' is what the user will see -->
            <label>Base Installation</label>
            <!-- default settings for all modules -->
            <defaults>
                <!-- arguments for the clients -->
                <arguments>false,false</arguments>
                <!-- allowed architectures "all", "i386", "i386,ia64,x86_64", see
                  Arch module in yast-yast2 for all possible options  -->
                <archs>all</archs>
            </defaults>
            <stage>initial</stage>
            <mode>installation,update</mode>
            <modules  config:type="list">
                <module>
                    <name>info</name>
                    <arguments>false,true</arguments>
                </module>
                <module>
                    <name>proposal</name>
                    <arguments>true,true,`ini</arguments>
                    <label>Installation Settings</label>
                </module>
                <module>
                    <name>do_resize</name>
                    <update config:type="boolean">false</update>
                    <archs>i386,x86_64,ia64</archs>
                    <label>Perform Installation</label>
                </module>
                <module>
                    <name>prepdisk</name>
                    <!-- Multiple modules with the same 'label' will be
                         collapsed to one single user-visible step.
                         The step is considered finished when the last module
                         with the same 'label' is finished.  -->
                    <label>Perform Installation</label>
                </module>
                <module>
                    <name>kickoff</name>
                    <label>Perform Installation</label>
                </module>
                <module>
                    <name>rpmcopy</name>
                    <label>Perform Installation</label>
                </module>
                <module>
                    <name>finish</name>
                    <label>Perform Installation</label>
                </module>
            </modules>
        </workflow>
    </workflows>
```

### Proposals

Part of the installation workflows are proposal screens, which consists
of group of related configuration settings. For example *Network*,
*Hardware* and the initial *Installation* proposal.

If you want for some reason to add or modify a proposal, which is
discourged because of configuration dependencies, then this would be
possible using the control file.


```
    <proposal>
        <type>network</type>
        <stage>continue,normal</stage>
        <proposal_modules config:type="list">
            <proposal_module>lan</proposal_module>
            <proposal_module>dsl</proposal_module>
            <proposal_module>isdn</proposal_module>
            <proposal_module>modem</proposal_module>
            <proposal_module>proxy</proposal_module>
            <proposal_module>remote</proposal_module>
        </proposal_modules>
    </proposal>
```

The proposal in the above listing is displayed in the so called
*continue* mode which is the second phase of the installation. The
proposal consists of different configuration options which are controled
using a special API.

Currently, proposals names and captions are fixed and cannot be changed. It
is not possible to create a special proposal screen, instead those
available should be used: *network*, *hardware*, *service*. All proposal script
names are listed without *_proposal* suffix. If a *proposed_module* is called
*example*, then installer looks for *example_proposal* script.

In the workflow, the proposals are called as any workflow step with an
additional argument identifying the proposal screen to be started.
(*\`net* for network, *\`hw* for hardware and *\`service* for service
proposals. The following examples shows how the network proposal is
called as a workflow step:

```
    <module>
        <label>Network</label>
        <name>proposal</name>
        <arguments>true,true,`net</arguments>
    </module>
```

### Installation and Product Variables

It is possible to define some installation variables (language,
timezone, keyboard,.. ) and force them in the proposal. User will still
be able to change them however.

The following variables can be set:

-   Timezone

-   Language

-   Keyboard

-   Auto Login (not recommended for multi-user environments and server
    installations)

-   IO Scheduler

    Default is *as*.

-   Desktop Scheduler

the following example shows all options above

```
    <globals>
        <enable_autologin config:type="boolean">true</enable_autologin>
        <language>de_DE</language>
        <timezone>Canada/Eastern</timezone>
        <use_desktop_scheduler config:type="boolean">true</use_desktop_scheduler>
        <io_scheduler>as</io_scheduler>
    </globals>
```
### Special Installation and Product Variables

These options usually enable or disable some installation feature.

-   (boolean) *enable\_firewall* - firewall will proposed as either
    enabled or disabled in the network proposal.

-   (boolean) *enable\_clone* - clonning feature will be either enabled
    or disabled.

-   (boolean) *skip\_language\_dialog* - the language dialog might be
    skipped (if language already selected).

-   (boolean) *show\_online\_repositories* - either shows or hides the
    "online repositories" feature check-box.

-   (boolean) *root\_password\_as\_first\_user* - automatically selects
    or deselects the checkbox that makes Users configuration to set the
    password entered for a first user also for the user root. If not
    defined, default is *false*

-   (boolean) *enable\_autoconfiguration* - enables a check box in
    dialog that offers to switch the automatic configuration either on
    or off. Default is false.

-   (boolean) *autoconfiguration\_default* - defines a default value
    whether to use the automatic configuration. It works even if
    *enable\_autoconfiguration* is turned off, but user would not be
    able to change it. Default is false.

-   (string) *base\_product\_license\_directory* - directory where the
    base-product licenses are stored (license.txt, license.de\_DE.txt,
    ...).

-   (boolean) *rle\_offer\_rulevel\_4* - defines whether runlevel 4
    should be offered in Runlevel Editor. Defaul value is *false* if not
    set.

-   (boolean) *enable\_kdump* - defines whether kdump is proposed as
    *enabled* in installation proposal. *kdump\_proposal* client call
    has to be added into [proposal](#control_proposals) otherwise this
    variable does not have any effect.

-   (boolean) *write\_hostname\_to\_hosts* - defines whether the
    currently assigned hostname is written to /etc/hosts with IPv4
    address 127.0.0.2. Defaul value is *false* if not set.

-   (boolean) *default\_ntp\_setup* - NTP configuration proposes a
    default ntp server if set to *true*. Default value is *false*.

-   (string) *polkit\_default\_privs* - Adjusts
    */etc/sysconfig/security/POLKIT\_DEFAULT\_PRIVS* to the defined
    value. If not set or empty, sysconfig is untouched.

-   (boolean) *require\_registration* - Require registration of add-on
    product (ignored in the base product).

### Installation Helpers

In the *globals* section, there are also helper variables for the
installation and debugging:

-   *save\_instsys\_content* - is a list of entries that should be
    copied from the installation system to the just installed system
    before first stage is finished and system reboots to the second
    stage.

    This example shows how content of the */root/* directory is copied
    to the */root/inst-sys/* directory on the installed system:

```
    <globals>
        <save_instsys_content config:type="list">
            <save_instsys_item>
                <instsys_directory>/root/</instsys_directory>
                <system_directory>/root/inst-sys/</system_directory>
            </save_instsys_item>
        </save_instsys_content>
    </globals>
```

-   (boolean) *debug\_workflow* - defines whether steps with the very
    same name in workflow should not be collapsed. If *true* steps are
    not collapsed and a step ID is added after the step name. The
    default is *false*. This feature should be off in the production
    phase.

-   (boolean) *debug\_deploying* - defines whether deploying should
    write more debug logs and some more debugging features in the
    workflow. The default is *false*. This feature should be off in the
    production phase.

### Importing Files from Previous Installation

Even if users are performing new reinstallation of their system,
installation process can backup some files or directories before their
disks are formatted and restore them after the installation. For
instance, SSH keys are reused.

Typically, there is only one system previously installed, if there are
more systems, the one with the newest access time to required files is
chosen.

See the example:

```
    <globals>
        <copy_to_system config:type="list">
            <copy_to_system_item>
                <!-- Files are restored directly to "/" after installation -->
                <copy_to_dir>/</copy_to_dir>

                <!-- Files that must be all present on the previous system -->
                <mandatory_files config:type="list">
                    <file_item>/etc/ssh/ssh_host_key</file_item>
                    <file_item>/etc/ssh/ssh_host_key.pub</file_item>
                </mandatory_files>

                <!-- Files thay may be present and are used if exist -->
                <optional_files config:type="list">
                    <file_item>/etc/ssh/ssh_host_dsa_key</file_item>
                    <file_item>/etc/ssh/ssh_host_dsa_key.pub</file_item>
                    <file_item>/etc/ssh/ssh_host_rsa_key</file_item>
                    <file_item>/etc/ssh/ssh_host_rsa_key.pub</file_item>
                </optional_files>
            </copy_to_system_item>

            <copy_to_system_item>
                <!--
                    Files are restored to a special directory
                    (and used by YaST later)
                -->
                <copy_to_dir>/var/lib/YaST2/imported/userdata/</copy_to_dir>

                <!--
                    They finally appear as
                        "/var/lib/YaST2/imported/userdata/etc/shadow"
                        "/var/lib/YaST2/imported/userdata/etc/passwd" ...
                -->
                <mandatory_files config:type="list">
                    <file_item>/etc/shadow</file_item>
                    <file_item>/etc/passwd</file_item>
                    <file_item>/etc/login.defs</file_item>
                    <file_item>/etc/group</file_item>
                </mandatory_files>
            </copy_to_system_item>
        </copy_to_system>
    </globals>
```

In the *globals* section, there is a *copy\_to\_system* list of
*copy\_to\_system\_item* entries.

Every *copy\_to\_system\_item* entry consists of:

-   (string) *copy\_to\_dir* - files are finally stored into the
    mentioned directory, they additionally keep their path in the
    previous filesystem, e.g., file */etc/file* copied to directory
    */var/lib/YaST2/* will be finally stored as
    */var/lib/YaST2/etc/file*

-   (list) *mandatory\_files* - list of (string) *file\_item* entries,
    one entry for one file or directory; these files are mandatory and
    must all exist on the source system; if any of the files are
    missing, such system is skipped

-   (list) *optional\_files* - list of (string) *file\_item* entries,
    one entry for one file or directory; files are optional and are
    copied if they exist; missing files are skipped

### Automatic Configuration

This is another feature defined in *globals* section. *Automatic
Configuration* is called via the script *inst\_automatic\_configuration*
at the end of the second stage installation. Having the configuration in
control file enables this function for another modes and makes it very
well configurable.

This is an example of AC setup:

```
    <productDefines  xmlns="http://www.suse.com/1.0/yast2ns"
        xmlns:config="http://www.suse.com/1.0/configns">
        <globals>

            <!-- List of steps in AC -->
            <automatic_configuration config:type="list">

                <!-- One step definition -->
                <ac_step>
                    <text_id>ac_1</text_id>
                    <type>scripts</type>
                    <ac_items config:type="list">
                        <ac_item>initialization</ac_item>
                        <ac_item>hostname</ac_item>
                        <ac_item>netprobe</ac_item>
                        <ac_item>rpmcopy_secondstage</ac_item>
                    </ac_items>
                    <icon>yast-lan</icon>
                </ac_step>

                <ac_step>
                    <text_id>ac_3</text_id>
                    <type>proposals</type>
                    <ac_items config:type="list">
                        <ac_item>x11</ac_item>
                        <ac_item>printer</ac_item>
                        <ac_item>sound</ac_item>
                        <ac_item>tv</ac_item>
                    </ac_items>
                    <icon>yast-hwinfo</icon>
                </ac_step>

            </automatic_configuration>
        </globals>

        <texts>

            <!-- Label used during AC, uses "text_id" from "ac_step" -->
            <ac_1><label>Initialization...</label><ac_1>
            <ac_3><label>Configuring hardware...</label><ac_3>

        </texts>
    </productDefines>
```

AC setup *automatic\_configuration* consists of list of several
*ac\_step* definitions. On definition for one AC step. These steps can
be compared to sets of scripts or sets of installation proposals, e.g.,
*network proposal* that consists of *lan*, *modem*, ... and *firewall*
proposals which might depend on each others proposals.

Every single *ac\_step* consists of

-   *text\_id* - which is the very same ID as used in
    [texts](#control_texts) (you have to define the AC label there).

-   *type* - defines how the AC step items will be handled. Possible
    values are *scripts* or *proposals*. More types cannot be mixed
    within one AC step. All *scripts* are called only once one by one,
    all *proposals* in one AC step are called first with *MakeProposal*
    parameter then again all with *Write* parameter.

-   *ac\_items* - is a list of scripts or proposals each in a separate
    *ac\_item*.

    For scripts an *ac\_item* is a name of YaST client script without
    *inst\_* prefix, e.g., *firewall* would call *inst\_firewall*
    script.

    For proposals an *ac\_item* is a name of YaST proposal without
    *\_proposal* suffix, e.g., *firewall* would call
    *firewall\_proposal*.

-   *icon* - plain icon filename (from 22x22 directory) without suffix
    and without any explicit directory name, e.g., *yast-network*.

### Software

In the *software* section you can define how is the selection of
software handled during installation or update.

This is a list of supported entries in *software*:

-   *default\_desktop* - defines a desktop selected by default by the
    installation.

Additionally, you can configure how updating of packages should be
performed. The following options are available:

-   *delete\_old\_packages*

    Do not delete old RPMs when updating.

-   *delete\_old\_packages\_reverse\_list*

    Inverts the *delete\_old\_packages* rule for products defined as
    list of regular expressions matching installed product name
    (SuSE-release).

```
    <!-- Delete old packages of all products but OES, SLES 9, SLE 10 and SLD 10 -->
    <software>
    <delete_old_packages config:type="boolean">true</delete_old_packages>
    <delete_old_packages_reverse_list config:type="list">
        <regexp_item>^UnitedLinux .*$</regexp_item>
        <regexp_item>^Novell Open Enterprise Server Linux.*</regexp_item>
        <regexp_item>^SUSE (LINUX|Linux) Enterprise Server 9$</regexp_item>
        <regexp_item>^SUSE (LINUX|Linux) Enterprise Server 9 .*$</regexp_item>
        <regexp_item>^SUSE (LINUX|Linux) Enterprise Server 10.*$</regexp_item>
        <regexp_item>^SUSE (LINUX|Linux) Enterprise Desktop 10.*$</regexp_item>
        <!-- Don't forget to define product itself (Service Pack) -->
        <regexp_item>^SUSE (LINUX|Linux) Enterprise Server 10 SP.*$</regexp_item>
        <regexp_item>^SUSE (LINUX|Linux) Enterprise Desktop 10 SP.*$</regexp_item>
    </delete_old_packages_reverse_list>
    </software>
```


-   *silently\_downgrade\_packages*

    Allows packager to downgrade installed packages during upgrade
    workflow.

-   *silently\_downgrade\_packages\_reverse\_list*

    Inverts the *silently\_downgrade\_packages* rule for products
    defined as list of regular expressions matching installed product
    name (SuSE-release).

```
    <!-- For SLES10, packages are not downgraded -->
    <software>
    <silently_downgrade_packages config:type="boolean">true</silently_downgrade_packages>
    <silently_downgrade_packages_reverse_list config:type="list">
        <regexp_item>^SUSE (LINUX|Linux) Enterprise Server 10.*$</regexp_item>
    </silently_downgrade_packages_reverse_list>
    </software>
```

-   *only\_update\_selected*

    One can update (only update packages already installed) or upgrade
    (also install new packages with new functionality). For example,
    SLES should do "update", not "upgrade" by default

-   *only\_update\_selected\_reverse\_list*

    Inverts the *only\_update\_selected* for products defined as list of
    regular expressions matching installed product name (SuSE-release).

```
    <!--
    Only update packages but install new packages
    when upgrading any SUSE Linux or openSUSE
    -->
    <software>
        <only_update_selected config:type="boolean">true</only_update_selected>
        <only_update_selected_reverse_list config:type="list">
            <regexp_item>^SUSE Linux [0-9].*</regexp_item>
            <regexp_item>^openSUSE [0-9].*</regexp_item>
        </only_update_selected_reverse_list>
    </software>
```

The other option defines how product upgrading in general is defined.

-   *products\_supported\_for\_upgrade*

    List of known products supported for upgrade (SuSE-release). Old
    releases or other distributions will report warning.
```
    <software>
        <products_supported_for_upgrade config:type="list">
            <regexp_item>^Novell LINUX Desktop 9.*</regexp_item>
            <regexp_item>^SUSE LINUX Enterprise Server 10.*</regexp_item>
            <regexp_item>^SUSE LINUX Enterprise Desktop 10.*</regexp_item>
            <regexp_item>^openSUSE .*</regexp_item>
        </products_supported_for_upgrade>
    </software>
```

All products (regular expressions) are matching the string which can be
found in */etc/\*-release* file.

Regular expressions in \<regexp\_item\>s can contain standard regular
expressions, such as

-   The circumflex *\^* and the dollar sign *\$* as boundary characters
    for strings

-   asterisk *\**, plus *+* and question mark *?* for repeating or
    existency

-   dot *.* for wild-card character

-   square brackets *[]* for list of possible characters

-   circle brackets *()* for listing possibilities

-   special all-locale class-expressions *[:alnum:]*, *[:alpha:]*,
    *[:blank:]*, *[:cntrl:]*, *[:digit:]*, *[:graph:]*, *[:lower:]*,
    *[:print:]*, *[:punct:]*, *[:space:]*, *[:upper:]*, *[:xdigit:]*

These regular expressions are evaluated as [POSIX regex]
(www.regular-expressions.info/posix.html).

-   *online\_repos\_preselected*

    Online Repositories are pre-selected by default to be used. This
    item can change the default behavior.

### Supported Desktops

This part defines not only all the desktops for Desktop Selection dialog
during installation but also the
[default\_desktop](#software_default_desktop) must be defined

Example of supported desktops:

```
    <productDefines  xmlns="http://www.suse.com/1.0/yast2ns"
        xmlns:config="http://www.suse.com/1.0/configns">
        <software>

            <supported_desktops config:type="list">

                <one_supported_desktop>
                    <name>gnome</name>
                    <desktop>gnome</desktop>
                    <label_id>desktop_gnome</label_id>
                    <logon>gdm</logon>
                    <cursor>DMZ</cursor>
                    <packages>gdm</packages>
                    <order config:type="integer">1</order>
                    <patterns>gnome x11 base</patterns>
                    <icon>pattern-gnome</icon>
                    <description_id>description_gnome</description_id>
                </one_supported_desktop>

                <one_supported_desktop>
                    <name>kde</name>
                    <desktop>kde4</desktop>
                    <!-- Generic ID used in texts below -->
                    <label_id>desktop_kde</label_id>
                    <logon>kdm4</logon>
                    <cursor>DMZ</cursor>
                    <packages>kde4-kdm</packages>
                    <order config:type="integer">1</order>
                    <patterns>kde x11 base</patterns>
                    <icon>pattern-kde4</icon>
                    <!-- Generic ID used in texts below -->
                    <description_id>description_kde</description_id>
                </one_supported_desktop>

            </supported_desktops>

        </software>

        <texts>

            <desktop_gnome><label>GNOME</label></desktop_gnome>
            <!-- See 'desktop_kde' in 'supported_desktops' -->
            <desktop_kde><label>KDE 4.1</label></desktop_kde>

            <description_gnome><label>Some description</label></description_gnome>
            <!-- See 'description_kde' in 'supported_desktops' -->
            <description_kde><label>Some description</label></description_kde>

        </texts>
    </productDefines>
```

Section *supported\_desktops* contains list of one or more
*one\_supported\_desktop* sections.

-   (string) *name*

    Unique ID.

-   (string) *desktop*

    Desktop to start (gnome, kde4, kde, xfce, ...).

-   (string) *label\_id*

    Text ID used for desktop selection label.

-   (string) *logon*

    Logon manager to start (gdm, kdm4, kdm3, xdm, ...).

-   (string) *cursor*

    Cursor theme.

-   (string) *packages*

    (whitespace-separated).

-   (integer) *order*

    Numeric order or the desktop in Desktop Selection dialog. Number *1*
    is reserved for major desktops that are displayed with description
    (*description\_id* is required). If the very same *order* is used
    for more than one desktops, they are sorted alphabetically.

-   (string) *patterns*

    Patterns to select for the desktop (whitespace-separated).

-   (string) *icon*

    Icon used in Desktop Selection dialog, just a name of an icon from
    \$current\_theme/icons/64x64/apps/ directory, without *.png* suffix.

-   (string) *description\_id*

    Text ID used for desktop selection label.

### System Scenarios

System scenarios contain definition of dialog *inst\_scenarios* in the
first stage installation. It offeres several base-scenarios but only one
of them can be selected as the selected one.

Example of configured scenarios:

```
    <productDefines  xmlns="http://www.suse.com/1.0/yast2ns"
        xmlns:config="http://www.suse.com/1.0/configns">
        <software>

            <!-- list of supported scenarios -->
            <system_scenarios config:type="list">

                <!-- one scenario -->
                <system_scenario>
                    <!-- 'id' matches the text 'scenario_game_server' -->
                    <id>scenario_game_server</id>
                    <!-- space-separated list of patterns -->
                    <patterns>game_server-pattern high-load-server</patterns>
                    <!--  plain icon filename (from 32x32 directory) without suffix -->
                    <icon>yast-system</icon>
                </system_scenario>

                <system_scenario>
                    <id>scenario_web_server</id>
                    <patterns>web_server-pattern</patterns>
                    <icon>yast-http-server</icon>
                </system_scenario>

                <system_scenario>
                    <id>scenario_nfs_server</id>
                    <patterns>nfs_server-pattern</patterns>
                    <icon>yast-nfs-server</icon>
                </system_scenario>

            </system_scenarios>

            <!-- this scenario (id) is selected by default -->
            <default_system_scenario>scenario_nfs_server</default_system_scenario>

        </software>

        <texts>

            <!-- dialog caption -->
            <scenarios_caption><label>Server Base Scenario</label></scenarios_caption>
            <!-- informative text between caption and listed scenarios -->
            <scenarios_text><label>SUSE Linux Enterprise Server offers several base scenarios.
    Choose the one that matches your server the best.</label></scenarios_text>

            <!-- matches the 'id' of one 'system_scenario' -->
            <scenario_game_server><label>Game Server</label></scenario_game_server>
            <scenario_web_server><label>Web Server</label></scenario_web_server>
            <scenario_nfs_server><label>NFS Server</label></scenario_nfs_server>

        </texts>
    </productDefines>
```

System scenarios are defined inside the *software* section. Section
*system\_scenarios* consists of several *system\_scenario* definitions.
Every single *system\_scenario* consists of:

-   *id* - unique identificator of a selection.

-   *patterns* - space-separated list of patterns covering the software
    scenario.

-   *icon* - plain icon filename (from 32x32 theme directory) without
    suffix.

Selection labels must be defined in [texts](#control_texts) section.
Scenarios *id*s are used as link identificators.

```
    <software>
    <system_scenario>
        <id></id>
    </system_scenario>
    </software>

    <texts>
    <><label>Some Label</label></>
    </texts>
```

Section *software* also contains optional *default\_system\_scenario*
that defines id of the default scenario.

There are some important texts that has to be defined for the dialog
layout

-   *scenarios\_caption* - used as a dialog caption for the Scenarios
    dialog.

-   *scenarios\_text* - used as an informative text describing the
    available selections below.

### Partitioning

If present, the partition proposal will be based on the data provided in
the control file.

#### Algorithm for Space Allocation

Space allocation on a disk happens in the following order. First all
partition get the size allocated that is determined by the size
parameter of the partition description. If a disk cannot hold the sum of
these sizes this disk is not considered for installation. If all demands
by the size parameter are fulfilled and there is still space available
on the disk, the partitions which have a parameter "percent" specified
are increased until the size demanded by by "percent" is fulfilled. If
there is still available space on the disk (this normally only can
happen if the sum of all percent values are below 100), all partitions
that are specified with a size of zero are enlarged as far as possible.
If a "maxsize" is specified for a partition, all enlargement are only
done up to the specified maxsize.

If more than one of the available disks is eligible to hold a certain
partition set, the disk is selected as follows. If there is a partition
allocated on that disk that has its size specified by keywords "percent"
or by "size=0" and does not have a "maxsize" value set then the desired
size for this partition is considered to be unlimited. If a partition
group contains a partition which an unlimited desired size, the disk
that maximizes the partition size for the unlimited partitions is
selected. If all partitions in a partition group are limited in size
then the smallest disk that can hold the desired sizes of all partitions
is selected for that partition group.

If there are multiple partition groups the the partition group with the
lowest number (means highest priority) get assigned its disk first.
Afterward the partition group with the next priority gets assigned a the
optimal disk from the so far unassigned disks.

#### Configuration Options

The following elements are global to all disks and partitions:

Possible values
:   true|false

Default value
:   true

Description
:   If set to false the partition suggestion tries to use gaps on the
    disks or to re-use existing partitions. If set to true then the
    partition suggestion prefers removal of existing partitions.

Possible values
:   true|false

Default value
:   false

Description
:   If set to false YaST2 will not remove some special partitions (e.g.
    0x12 Compaq diagnostics, 0xde Dell Utility) if they exists on the
    disk even if prefer\_remove is set to true. If set to true YaST2
    will remove even those special partitions.

    > **Caution**
    >
    > Caution: Since some machines are not even bootable any more when
    > these partitions are removed one should really know what he does
    > when setting this to true

Possible values
:   comma separated list of reiser, xfs, fat, vfat, ext2, ext3, jfs,
    ntfs, swap

Default value
:   Empty list

Description
:   Partitions that contain filesystems in that list are not deleted
    even if prefer\_remove is set to true.

Possible values
:   comma separated list of possible partition ids

Default value
:   Empty list

Description
:   Partitions that have a partition id that is contained in the list
    are not deleted even if prefer\_remove is set to true.

Possible values
:   comma separated list of possible partition numbers

Default value
:   Empty list

Description
:   Partitions that have a partition number that is contained in the
    list are not deleted even if prefer\_remove is set to true.

To configure individual partitions and disks, a list element is used
with its items describing how should the partitions be created and
configured

The attributes of such a partition are determined by several elements.
These elements are described in more detail later.

> **Note**
>
> If there is a blank or a equal sign (=) contained in an option value,
> the values has to be surrounded by double quotes ("). Values that
> describe sizes can be followed by the letters K, M, G. (K means
> Kilobytes, M Megabytes and G Gigabytes).

Example
:   \<mount\>swap\</mount\>

Description
:   This entry describes the mount point of the partition. For a swap
    partition the special value "swap" has to be used.

Example
:   \<fsys\>reiser\</fsys\>

Description
:   This entry describes the filesystem type created on this partition.
    Possible Filesystem types are: reiser, ext2, ext3, xfs, vfat, jfs,
    swap If no filesystem type is given for a partition, reiserfs is
    used.

Example
:   \<formatopt\>reiser\<formatopt\>

Description
:   This entry describes the options given to the format command.
    Multiple options have to be separated by blanks. There must not be a
    blank between option letter and option value. This entry is
    optional.

Example
:   \<fstopt\>acl,user\_xattr\<fstopt\>

Description
:   This entry describes the options written to `/etc/fstab`. Multiple
    options have to be separated by comma. This entry is optional.

Example
:   \<label\>emil\<label\>

Description
:   If the filesystem can have a label, the value of the label is set to
    this value.

Example
:   \<id\>0x8E\<id\>

Description
:   This keyword makes it possible to create partitions with partition
    ide other than 0x83 (for normal filesystem partitions) or 0x82 (for
    swap partitions). This make it possible to create LVM or MD
    partitions on a disk.

Example
:   \<size\>2G\<size\>

Description
:   This keyword determines the size that is at least needed for a
    partition. A size value of zero means that YaST2 should try to make
    the partition as large as possible after all other demands regarding
    partition size are fulfilled. The special value of "auto" can be
    given for the `/boot` and swap partition. If auto is set for a /boot
    or swap partition YaST2 computes a suitable partition size by
    itself.

Example
:   \<percent\>30\<percent\>

Description
:   This keyword determines that a partition should be allocated a
    certain percentage of the available space for installation on a
    disk.

Example
:   \<maxsize\>4G\<maxsize\>

Description
:   This keyword limits the maximal amount of space that is allocated to
    a certain partition. This keyword is only useful in conjunction with
    a size specification by keyword "percent" or by an entry of
    "size=0".

Example
:   \<increasable config:type="boolean"\>true\<increasable\>

Default
:   false

Description
:   After determining the optimal disk usage the partition may be
    increased if there is unallocated space in the same gap available.
    If this keyword is set, the partition may grow larger than specified
    by the maxsize and percent parameter. This keyword is intended to
    avoid having unallocated space on a disk after partitioning if
    possible.

Example
:   \<disk\>2\<disk\>

Description
:   This keyword specifies which partitions should be placed on which
    disks if multiple disks are present in the system. All partitions
    with the same disk value will be placed on the same disk. The value
    after the keyword determines the priority of the partition group.
    Lower numbers mean higher priority. If there are not enough disks in
    the system a partition group with lower priority is assigned a
    separate disks before a partition group with higher priority. A
    partition without disk keyword is implicitly assigned the highest
    priority 0.

If in the example below the machine has three disks then each of the
partition groups gets on a separate disk. So one disk will hold `/var`,
another disk will hold /home`` and another disk will hold `/`, `/usr`
and` /opt`. If in the above example the machine has only two disks then
`/home` will still be on a separate disk (since it has lower priority
than the other partition groups) and `/`, `/usr`, `/opt` and `/var` will
share the other disk.

If there is only one disk in the system of course all partitions will be
on that disk. To make the flexible partitioning possible,
*use\_flexible\_partitioning* option must be se to *true* and
*partitions* must be surrounded with *flexible\_partitioning* tag.

```
    <partitioning>
        <use_flexible_partitioning config:type="boolean">true</use_flexible_partitioning>

        <flexible_partitioning>
            <partitions config:type="list">
                <partition>
                    <disk config:type="integer">3</disk>
                    <mount>/var</mount>
                    <percent config:type="integer">100</percent>
                </partition>
                <partition>
                    <disk config:type="integer">2</disk>
                    <mount>/</mount>
                    <size>1G</size>
                </partition>
                <partition>
                    <disk config:type="integer">2</disk>
                    <mount>/usr</mount>
                    <size>2G</size>
                </partition>
                <partition>
                    <disk config:type="integer">2</disk>
                    <mount>/opt</mount>
                    <size>2G</size>
                </partition>
               <partition>
                    <disk config:type="integer">1</disk>
                    <mount>/home</mount>
                    <percent config:type="integer">100</percent>
                </partition>
            </partitions>
        </flexible_partitioning>
    </partitioning>
```

A more complete example with other options is shown below:

```
    <partitioning>
        <use_flexible_partitioning config:type="boolean">true</use_flexible_partitioning>

        <flexible_partitioning>
            <partitions config:type="list">
                <partition>
                    <disk config:type="integer">2</disk>
                    <mount>swap</mount>
                    <size>auto</size>
                </partition>
                <partition>
                    <disk config:type="integer">1</disk>
                    <fstopt>defaults</fstopt>
                    <fsys>reiser</fsys>
                    <increasable config:type="boolean">true</increasable>
                    <mount>/</mount>
                    <size>2gb</size>
                </partition>
                <partition>
                    <disk config:type="integer">2</disk>
                    <fstopt>defaults,data=writeback,noatime</fstopt>
                    <fsys>reiser</fsys>
                    <increasable config:type="boolean">true</increasable>
                    <mount>/var</mount>
                    <percent config:type="integer">100</percent>
                    <size>2gb</size>
                </partition>
            </partitions>
        </flexible_partitioning>

        <prefer_remove config:type="boolean">true</prefer_remove>
        <remove_special_partitions config:type="boolean">false</remove_special_partitions>
    </partitioning>
```

### Hooks

It is possible to add hooks before and after any workflow step for
further customization of the installed system and to to perform
non-standard tasks during installation.

Two additional elements define custom script hooks:

-   prescript: Executed before the module is called.

-   postscript: Executed after the module is called.

Both script types accept two elements, the interpreter used (shell or
perl) and the source of the scripts which is embedded in the XML file
using CDATA sections to avoid confusion with the XML syntax. The
following example shows how scripts can be embedded in the control file:

```
    <module>
        <name>info</name>
        <arguments>false,true</arguments>
        <prescript>
            <interpreter>shell</interpreter>
            <source>
<![CDATA[#!/bin/sh
touch /tmp/anas
echo anas > /tmp/anas
]]>
            </source>
        </prescript>
    </module>
```

### Texts

Some kind of texts can be, of course, placed in several parts of the
control file but they wouldn't be translated. This control file section
makes it possible to mark some texts for translation.

The structure is rather easy:

```
    <texts>
        <!-- Unique tag that identifies the text -->
        <some_text_id>
            <label>Some XML-escaped text: &lt;b&gt;bold &lt;/b&gt;.</label>
        </some_text_id>

        <congratulate>
            <label>&lt;p&gt;&lt;b&gt;Congratulations!&lt;/b&gt;&lt;/p&gt;</label>
        </congratulate>
    </texts>
```

Translated texts can be got using *ProductControl.GetTranslatedText
(text\_id)* call.

CONTROL-SECTION
Add-on Product Installation Workflow Specification
==================================================

Introduction
------------

### Product dependency

Everywhere, product B depends on product A, there is no dependency
related to product C. A, B and C are add-on products.

### Order of updates of the workflow/wizard

If there are two add-on products which want to insert their steps into
the same location of the installation workflow (or proposal), they are
inserted in the same order as the products are added. A must be added
before B (otherwise adding B fails), steps of A are always prior to
steps of B.

### Steps/Proposal Items Naming

In order to avoid collisions of internal names of proposal items or
sequence steps, all items should have its internal name prefixed by the
add-on product name.

### Update possibilities

#### Insert an item into proposal

Item is always added at the end of the proposal. Multiple items are
possible.

#### Remove an item from proposal

Specified item(s) are removed from proposal. Useful when add-on product
extends functionality of the base product. If product B wants to remove
an item of product A, must specify the name of the product as well.
Product C cannot remove items of products A or B (and vice versa),
product A cannot remove items of product B.

#### Replace an item in proposal

Usable in the same cases as the case above. If an item has been replaced
by another item(s) of product A before applying changes of product B,
the item(s) of product A will be replaced by item(s) of product B. Items
of product C cannot be replaced by items of product A or B (and vice
versa), such combination of products cannot be installed at the same
time.

#### Insert steps to installation sequence

Before each step of base product installation, additional step can be
inserted (eg. another proposal). For the order of additionally added
steps, the same rules as for items of proposal will be applied.

#### Append steps to installation sequence

The steps can be appended at the end of installation sequence.

#### Remove and replace steps in installation sequence

The same rules for removing and replacing steps of the installation
workflow as for proposal items will be applied.

#### Add, remove, replace items in inst\_finish.ycp

The same rules as for steps of the installation workflow are valid here.
There will be some points in the inst\_finish where performing
additional actions makes sense (at least one before moving SCR to chroot
and one after).

#### Replace whole second-stage workflow

Add-on product may replace whole second stage of installation. It should
be used only in rare cases, as there is no possibility to merge two
workflows completely written from scratch. If a product replaces the
workflow, all changes of all products which replaced it before (in case
of installation of multiple products) are gone. Add-on products selected
after this product update the new workflow (which may not work, as the
steps usually have different naming). This is perfectly OK if there are
dependencies between add-on products.

The workflow can be replaced only for specified installation mode. If it
is replaced, it must be replaced for all architectures.

#### Adding a new proposal

New proposal can be added, as the proposal handling routines are
generic. The information which is for current product in control.xml
file has to be provided, and the proposal must be added as a step into
the installation workflow. Basically, adding proposal has two steps:

-   defining the proposal (name, items,...)

-   adding a new step to the workflow referring to the new added
    proposal

#### Replace or remove whole proposal

Is possible as replacing or removing a step of the installation
workflow.

### File layout

#### Add-on Product CD

There will be following files in the root directory of the add-on
product's CD:

-   servicepack.tar.gz – tarball with files which are needed for the
    installation, both together with base product and separatelly.
    Special files inside this tarball:

    -   installation.xml – the control file of the add-on product

    -   the whole tarball or installation.xml can be missing if add-on
        product doesn't provide any custom installer, in this case, only
        its packages are added to the package manager dialog, and
        packages/patterns/... required by the product are selected by
        the solver

-   (optional) setup.sh – script which starts the installation
    automatically once the CD is in the drive

-   (optional) files needed to make the CD bootable (kernel, initrd,
    isolinux,...)

-   (optional) `y2update.tgz` can contain all files that are needed for
    installation itself. Both for first stage installation and also for the
    running system.

#### Workflow Adaptation

There is only a single control file to describe both an add-on and
standalone product installation. It is called installation.xml. In
principle, it contains a diff description containing the changes to be
applied to the installation workflow plus a workflow, which is used for
standalone product installation. The reason why both installation
methods are stored in a single file is that the product features has to
be shared as well as some proposals and clients can be reused.

The proposals which are defined for standalone installation are also
available for the installation together with the base product. They
don't have to be defined twice.

The files are located in the top directory of the add-on product
installation source.

### Diff File Format

Because there were no really usable open source XML diff tools (the
existing ones are typically written in Java), we define a special
purpose file format aimed to cover the cases as described in the
previous chapter.

In principle, the format is a list of directives to be applied to the
existing control.xml. In principle, the file is a control file defining
its own proposals, workflows etc. The control file has a special
section, which defines changes to the existing workflow and proposals.

```
    <?xml version="1.0"?>
    <productDefines  xmlns="http://www.suse.com/1.0/yast2ns"
        xmlns:config="http://www.suse.com/1.0/configns">
        <!-- .mo-file must be in installation tarball -->
        <textdomain>OES</textdomain>
        <!-- these options override base product's ones -->
        <globals>
            <additional_kernel_parameters></additional_kernel_parameters>
        </globals>
        <software>
            <selection_type config:type="symbol">auto</selection_type>
        </software>
        <partitioning>
            <root_max_size>10G</root_max_size>
        </partitioning>
        <network>
            <force_static_ip config:type="boolean">false</force_static_ip>
            <network_manager>laptop</network_manager>
        </network>
        <!-- base product's list is preserved, these are appended -->
        <clone_modules config:type="list">
            <clone_module>printer</clone_module>
        </clone_modules>
        <proposals config:type="list">
      <!-- put proposals for standalone product installation here -->
        </proposals>
      <!-- workflow for standalone product installation -->
        <workflows config:type="list">
            <workflow>
                <defaults>
                    <archs>all</archs>
                </defaults>
                <label>Preparation</label>
                <!-- mode and stage must be set this way -->
                <mode>installation</mode>
                <stage>normal</stage>
                <modules config:type="list">
                    <module>
                         <label>License Agreement</label>
                         <name>license</name>
                         <enable_back>no</enable_back>
                         <enable_next>yes</enable_next>
                    </module>
                </modules>
            </workflow>
        </workflows>
        <!-- stuff for installation together with base products -->
        <update>
            <proposals config:type="list">
                <proposal>
                    <label>OES Installation Settings</label>
                    <mode>installation,demo,autoinstallation</mode>
                    <stage>initial</stage>
                    <name>initial</name>
                    <enable_skip>no</enable_skip>
                    <append_modules config:type="list">
                        <append_module>module_1</append_module>
                        <append_module>module_2</append_module>
                    </append_modules>
                    <remove_modules config:type="list">
                        <remove_module>module_3</remove_module>
                        <remove_module>module_4</remove_module>
                    </remove_modules>
                    <replace_modules config:type="list">
                        <replace_module>
                            <replace>old_module</replace>
                            <new_modules config:type="list">
                                <new_module>module_5</new_module>
                                <new_module>module_6</new_module>
                            </new_modules>
                        </replace_module>
                    </replace_modules>
                </proposal>
            </proposals>
            <workflows config:type="list">
                <workflow>
                    <defaults>
                        <archs>all</archs>
                        <enable_back>no</enable_back>
                        <enable_next>no</enable_next>
                    </defaults>
                    <mode>installation</mode>
                    <stage>initial</stage>
                    <append_modules config:type="list">
                        <module>
                            <heading>yes</heading>
                            <label>OES configuration</label>
                        </module>
                        <module>
                            <label>Perform Installation</label>
                            <name>a1_netsetup</name>
                        </module>
                        <module>
                            <label>Perform Installation</label>
                            <name>a2_netprobe</name>
                        </module>
                    </append_modules>
                    <remove_modules config:type="list">
                        <remove_module>finish</remove_module>
                    </remove_modules>
                    <insert_modules config:type="list">
                        <insert_module>
                            <before>perform</before>
                            <modules config:type="list">
                                 <module>
                                 <label>Perform Installation</label>
                                    <name>i1_netprobe</name>
                                </module>
                            </modules>
                        </insert_module>
                    </insert_modules>
                    <replace_modules config:type="list">
                        <replace_module>
                            <replace>language</replace>
                            <modules config:type="list">
                                 <module>
                                 <label>Perform Installation</label>
                                    <name>r1_language</name>
                                </module>
                            </modules>
                        </replace_module>
                    </replace_modules>
                </workflow>
            </workflows>
            <inst_finish>
                <before_chroot config:type=”list”>
                    <module>before_chroot_1</module>
                    <module>before_chroot_2</module>
                </before_chroot>
                <after_chroot config:type=”list”>
                    <module>after_chroot_1</module>
                    <module>after_chroot_2</module>
                </after_chroot>
                <before_umount config:type=”list”>
                    <module>before_umount_1</module>
                    <module>before_umount_2</module>
                </before_umount>
            </inst_finish>
        </update>
    </productDefines>
```

### Setting a text domain

Text domain is important for YaST to handle translations properly. The
appropriate set of .mo-files must be present to have the texts related
to the control file translated.

```
    <textdomain>OES</textdomain>
```

### Defining proposals and workflow for standalone installation

The proposals are defined the same way as for the base product. The
workflow for the standalone installation must have the mode and stage
set

```
    <mode>installation</mode>
    <stage>normal</stage>
```

### Proposal modification

The label of the proposal can be modified. The mode, stage, and proposal
name has to be specified, other options (enable\_skip, architecture) are
optional. The modes, stages, and architectures do not

```
    <proposal>
        <label>OES Installation Settings</label>
        <mode>installation,demo,autoinstallation</mode>
        <stage>initial</stage>
        <name>initial</name>
        <enable_skip>no</enable_skip>
        [.....]
    </proposal>
```


### Appending an item at the end of proposal

Adding an item to a proposal is possible at the end only. If the
proposal has tabs, the items are added to a newly created tab.

```
    <append_modules config:type="list">
        <append_module>module_1</append_module>
        <append_module>module_2</append_module>
    </append_modules>
```

### Removing an item from a proposal

```
    <remove_modules config:type="list">
        <remove_module>module_3</remove_module>
        <remove_module>module_4</remove_module>
    </remove_modules>
```

### Replacing an item of a proposal

The replacement is available in 1:N mode – one client is to be replaced
by one or more new clients. If you need M:N use remove and replace
together.

```
    <replace_modules config:type="list">
        <replace_module>
        <replace>old_module</replace>
        <new_modules config:type="list">
            <new_module>module_5</new_module>
            <new_module>module_6</new_module>
        </new_modules>
        </replace_module>
    </replace_modules>
```

### Workflow updates

The workflow to update is identified the same way as other workflows.
The archs, modes, and installation don't need tobe alligned to the same
groups as in the base product workflows.
```
    <workflow>
        <defaults>
        <archs>all</archs>
        <enable_back>no</enable_back>
        <enable_next>no</enable_next>
        </defaults>
        <mode>installation</mode>
        <stage>initial</stage>
        [...]
    </workflow>
```

### Append steps to the end of installation sequence

```
    <append_modules config:type="list">
        <module>
        <heading>yes</heading>
        <label>OES configuration</label>
        </module>
        <module>
        <label>Perform Installation</label>
        <name>a1_netsetup</name>
        </module>
        <module>
        <label>Perform Installation</label>
        <name>a2_netprobe</name>
        </module>
        [...]
    </append_modules>
```

### Insert steps to installation sequence
```
    <insert_modules config:type="list">
        <insert_module>
        <before>perform</before>
        <modules config:type="list">
            <module>
            <label>Perform Installation</label>
            <name>i1_netprobe</name>
            </module>
            [...]
        </modules>
        </insert_module>
    </insert_modules>
```

### Remove steps from installation sequence
```
    <remove_modules config:type="list">
        <remove_module>finish</remove_module>
        [...]
    </remove_modules>
```

### Replace steps in installation sequence
```
    <replace_modules config:type="list">
        <replace_module>
        <replace>language</replace>
        <modules config:type="list">
            <module>
            <label>Perform Installation</label>
            <name>r1_language</name>
            </module>
            [...]
        </modules>
        </replace_module>
    </replace_modules>
```

### Add items in inst\_finish.ycp

In CODE 10, the last step of an installation commonly known as
inst\_finish has been modularized, so it's possible to control the
clients started at the end of the 1st stage. In principle, this phase
runs in a chroot environment – all system access is done via chrooted
process.

There are 3 cases that an add-on product can modify the workflow...

#### Before chroot

```
    <inst_finish_stages config:type="list">
    <before_chroot>
        <label>Copy Theme</label>
        <steps config:type="list">
        <step>copy_theme</step>
        [...]
        </steps>
    </before_chroot>
    </inst_finish_stages>
```

#### Running in chroot
```
    <inst_finish_stages config:type="list">
    <chroot>
        <label>Update Configuration</label>
        <steps config:type="list">
        <step>pkg</step>
        [...]
        </steps>
    </chroot>
    </inst_finish_stages>
```

#### Before unmounting the system
```
    <inst_finish_stages config:type="list">
    <before_umount>
        <label>Disconnect Network Disks</label>
        <steps config:type="list">
        <step>iscsi_disconnect</step>
        [...]
        </steps>
    </before_umount>
    </inst_finish_stages>
```

All new steps are added at the end of the current list in the particular
inst\_finish workflow. It is not possible to remove any other
inst\_finish clients or replace them.

### Replace whole second-stage workflow

To replace a workflow, just create workflows as in base product control
file. The important is that the stage of the workflow is set to
```
    <stage>continue</stage>
```

and the mode is set for the specified mode.

### Algorithm for Adapting Workflow

The algorithm is rather straightforward. Every time, remove is applied
first, then replace and the last step is add. This is done per product,
so first the changes by product A are applied, then by product B etc.

### Product Features

One of the most important data stored in the control.xml file are the
values to influence the behavior of YaST code, like proposals etc. The
idea is the same as for workflow/proposal adaptation: by redefining a
value, the resulting values are changed. Within YaST, the options are
accessible via ProductFeatures module. No new option groups can be
defined. Options which are defined by the base product, but not by the
add-on product, are kept unchanged (base product's value is used).
```
    <globals>
        <additional_kernel_parameters></additional_kernel_parameters>
    </globals>
    [...]
    <software>
        <selection_type config:type="symbol">auto</selection_type>
    </software>
```

### AutoYaST profile generation

At the end of the installation, a profile for AutoYaST can be generated.
The profile will be generated using modules from the base product and
modules specified in the add-on product control file.
```
    <clone_modules config:type="list">
        <clone_module>printer</clone_module>
        [...]
    </clone_modules>
```

### Example of OES 1.0

The network code is instructed to force a static IP address.

The control file contains steps for both standalone installation and
installation together with the base product. In the standalone
installation workflow, selecting and installing packages is missing,
these steps need to be prepended to the workflow.

```
    <?xml version="1.0"?>
    <productDefines  xmlns="http://www.suse.com/1.0/yast2ns"
            xmlns:config="http://www.suse.com/1.0/configns">
    <textdomain>OES</textdomain>
    <network>
        <force_static_ip config:type="boolean">true</force_static_ip>
        <network_manager_is_default config:type="boolean">false</network_manager_is_default>
    </network>
    <proposals config:type="list">
        <proposal>
            <name>oes</name>
            <stage>continue,normal</stage>
            <mode>installation</mode>
            <proposal_modules config:type="list">
                <proposal_module>oes-ldap</proposal_module>
                <proposal_module>imanager</proposal_module>
                <proposal_module>lifeconsole</proposal_module>
                <proposal_module>linux-user-mgmt</proposal_module>
                <proposal_module>eguide</proposal_module>
                <proposal_module>novell-samba</proposal_module>
                <proposal_module>ifolder2</proposal_module>
                <proposal_module>ifolder</proposal_module>
                <proposal_module>ifolderwebaccess</proposal_module>
                <proposal_module>iprint</proposal_module>
                <proposal_module>nss</proposal_module>
                <proposal_module>netstorage</proposal_module>
                <proposal_module>novell-quickfinder</proposal_module>
                <proposal_module>novell-vo</proposal_module>
                <proposal_module>ncs</proposal_module>
                <proposal_module>ncpserver</proposal_module>
                <proposal_module>sms</proposal_module>
            </proposal_modules>
        </proposal>
    </proposals>
    <workflows config:type="list">
        <workflow>
            <label>Preparation</label>
            <defaults>
                <archs>all</archs>
            </defaults>
            <mode>installation</mode>
            <stage>normal</stage>
            <modules config:type="list">
                <module>
                    <label>License Agreement</label>
                    <name>inst_license</name>
                    <enable_back>no</enable_back>
                    <enable_next>yes</enable_next>
                </module>
                <module>
                    <label>OES Configuration</label>
                    <name>inst_check_cert</name>
                    <enable_back>no</enable_back>
                    <enable_next>yes</enable_next>
                </module>
                <module>
                    <label>OES Configuration</label>
                    <name>inst_proposal</name>
                    <arguments>false,false,`product</arguments>
                    <enable_back>no</enable_back>
                    <enable_next>yes</enable_next>
                </module>
                <module>
                    <label>OES Configuration</label>
                    <name>inst_oes</name>
                    <enable_back>yes</enable_back>
                    <enable_next>yes</enable_next>
                </module>
                <module>
                    <label>OES Configuration</label>
                    <name>inst_oes_congratulate</name>
                    <enable_back>no</enable_back>
                    <enable_next>yes</enable_next>
                </module>
            </modules>
        </workflow>
    </workflows>
    <update>
        <workflows config:type="list">
            <workflow>
                <defaults>
                    <archs>all</archs>
                    <enable_back>no</enable_back>
                    <enable_next>no</enable_next>
                </defaults>
                <stage>continue</stage>
                    <mode>installation</mode>
                    <append_modules config:type="list">
                        <module>
                            <label>OES Configuration</label>
                            <name>inst_oes_congratulate</name>
                        </module>
                    </append_modules>
                    <insert_modules config:type="list">
                        <insert_module>
                            <before>release_notes</before>
                            <modules config:type="list">
                                <module>
                                    <label>OES Configuration</label>
                                    <name>inst_check_cert</name>
                                </module>
                                <module>
                                    <label>OES Configuration</label>
                                    <name>inst_edirectory</name>
                                </module>
                                <module>
                                    <label>OES Configuration</label>
                                    <name>inst_proposal</name>
                                    <arguments>false,true,`product</arguments>
                                </module>
                                <module>
                                    <label>OES Configuration</label>
                                    <name>inst_oes</name>
                                </module>
                            </modules>
                        </insert_module>
                    </insert_modules>
                </workflow>
            </workflows>
        </update>
    </productDefines>
```
