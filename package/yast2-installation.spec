#
# spec file for package yast2-installation
#
# Copyright (c) 2013 SUSE LINUX Products GmbH, Nuernberg, Germany.
#
# All modifications and additions to the file contributed by third parties
# remain the property of their copyright owners, unless otherwise agreed
# upon. The license for this file, and modifications and additions to the
# file, is the same license as for the pristine package itself (unless the
# license for the pristine package is not an Open Source License, in which
# case the license is the MIT License). An "Open Source License" is a
# license that conforms to the Open Source Definition (Version 1.9)
# published by the Open Source Initiative.

# Please submit bugfixes or comments via http://bugs.opensuse.org/
#


Name:           yast2-installation
Version:        3.1.17
Release:        0

BuildRoot:      %{_tmppath}/%{name}-%{version}-build
Source0:        %{name}-%{version}.tar.bz2

Group:          System/YaST
License:        GPL-2.0
Requires:       yast2-ruby-bindings >= 1.0.0

Summary:        YaST2 - Installation Parts

Source1:	YaST2-Second-Stage.service
Source2:	YaST2-Firstboot.service

BuildRequires:  docbook-xsl-stylesheets libxslt update-desktop-files yast2-core-devel
BuildRequires:  yast2-devtools >= 3.1.10
BuildRequires:  rubygem-rspec

# Linuxrc.keys
BuildRequires: yast2 >= 3.1.9

# AutoinstConfig::getProposalList
Requires:       autoyast2-installation >= 2.17.1

# ProductProfile
Requires:	yast2 >= 3.1.9

# Language::GetLanguageItems and other API
# Language::Set (handles downloading the translation extensions)
Requires:	yast2-country-data >= 2.16.11

# Pkg::SourceProvideDigestedFile() 
Conflicts:	yast2-pkg-bindings < 2.17.25

# Pkg::Add/RemoveUpgradeRepo()
Requires:	yast2-pkg-bindings >= 2.21.2

# Mouse-related scripts moved to yast2-mouse
Conflicts:	yast2-mouse < 2.18.0

# New API for ProductLicense
Requires:	yast2-packager >= 2.19.2

# Storage::GetDetectedDiskPaths
Requires:	yast2-storage >= 2.24.1

# use in startup scripts
Requires:	initviocons

# Proxy settings for 2nd stage (bnc#764951)
Requires:       yast2-proxy

# Systemd default target and services
Requires: yast2-services-manager

# Only in inst-sys
# Requires:	yast2-network
# Requires:	yast2-add-on
# Requires:	yast2-update

# Pkg::SourceProvideSignedFile Pkg::SourceProvideDigestedFile
# pkg-bindings are not directly required
Conflicts:	yast2-pkg-bindings < 2.17.25

# InstError
Conflicts:	yast2 < 2.18.6

# Added new function WFM::ClientExists
Conflicts:	yast2-core < 2.17.10

# ButtonBox widget
Conflicts:	yast2-ycp-ui-bindings < 2.17.3

# tar-gzip some system files and untar-ungzip them after the installation (FATE #300421, #120103)
Requires:	tar gzip
Requires:	coreutils

%if 0%{?suse_version} >= 1210
BuildRequires: systemd-devel
%{systemd_requires}
%endif

# for the first/second stage of installation
# currently not used
# bugzilla #208307
#Requires:	/usr/bin/jpegtopnm
#Requires:	/usr/bin/pnmtopng

# BNC 446533, /sbin/lspci called but not installed
Requires:	pciutils

Recommends:	yast2-registration
Recommends:	yast2-online-update
Recommends:	yast2-users
Recommends:	yast2-firewall
Recommends:	release-notes
Recommends:	curl
Recommends:	yast2-update
Recommends:	yast2-add-on

PreReq:		%fillup_prereq

BuildArch: noarch

%package devel-doc
Group:          Documentation/HTML
Requires:	yast2-installation >= 2.15.34

PreReq:		%fillup_prereq

Summary:	YaST2 - Installation Parts

%description
System installation code as present on installation media.

%description devel-doc
System installation code as present on installation media.

%prep
%setup -n %{name}-%{version}

%build
%yast_build

%install
%yast_install

for f in `find %{buildroot}%{_datadir}/autoinstall/modules -name "*.desktop"`; do
    %suse_update_desktop_file $f
done 

mkdir -p %{buildroot}%{yast_vardir}/hooks/installation

mkdir -p %{buildroot}%{_unitdir}
install -m 644 %{SOURCE1} %{buildroot}%{_unitdir}
install -m 644 %{SOURCE2} %{buildroot}%{_unitdir}


%post
%{fillup_only -ns security checksig}

%if 0%{suse_version} > 1140

%service_add_post YaST2-Second-Stage.service YaST2-Firstboot.service

%pre
%service_add_pre YaST2-Second-Stage.service YaST2-Firstboot.service

%preun
%service_del_preun YaST2-Second-Stage.service YaST2-Firstboot.service

%postun
%service_del_postun YaST2-Second-Stage.service YaST2-Firstboot.service

%endif #suse_version

%files
%defattr(-,root,root)

# systemd service files
%{_unitdir}/YaST2-Second-Stage.service
%{_unitdir}/YaST2-Firstboot.service

%{yast_clientdir}/*.rb
%{yast_moduledir}/*.rb
%{yast_desktopdir}/*.desktop
/usr/share/autoinstall/modules/*.desktop
/usr/share/YaST2/schema/autoyast/rnc/deploy_image.rnc
%dir /usr/share/autoinstall
%dir /usr/share/autoinstall/modules
%dir %{yast_yncludedir}/installation
%{yast_yncludedir}/installation/*

# agents
%{yast_scrconfdir}/etc_passwd.scr
%{yast_scrconfdir}/cfg_boot.scr
%{yast_scrconfdir}/cfg_windowmanager.scr
%{yast_scrconfdir}/cfg_fam.scr
%{yast_scrconfdir}/etc_install_inf.scr
%{yast_scrconfdir}/etc_install_inf_alias.scr
%{yast_scrconfdir}/etc_install_inf_options.scr
%{yast_scrconfdir}/proc_modules.scr
%{yast_scrconfdir}/run_df.scr
# fillup
/var/adm/fillup-templates/sysconfig.security-checksig

# programs and scripts
%{yast_ystartupdir}/startup

# installation hooks
%dir %{yast_vardir}/hooks
%dir %{yast_vardir}/hooks/installation

%dir %{yast_docdir}
%{yast_docdir}/COPYING

%files devel-doc
%defattr(-,root,root)
%doc %{yast_docdir}
%exclude %{yast_docdir}/COPYING
