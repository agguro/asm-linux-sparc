Name: fstyp
Version: 0.1
Release: 1
Packager: mkp@mkp.net
Provides: fstyp 
Autoreqprov: on
Summary: filesystem type identifier
Source: fstyp-0.1.tar.gz
Group: System
BuildRoot: /var/tmp/fstyp-%{PACKAGE_VERSION}-root
Copyright: GPL

%description
Utility to heuristically determine filesystem type of a partition.

%prep
%setup

%build
./configure --prefix=/usr --mandir=/usr/share/man
make

%install
rm -rf $RPM_BUILD_ROOT
mkdir -p $RPM_BUILD_ROOT/usr/share/man/man8
mkdir -p $RPM_BUILD_ROOT/usr/sbin
make install DESTDIR=$RPM_BUILD_ROOT/

%clean
[ -n "$RPM_BUILD_ROOT" -a "$RPM_BUILD_ROOT" != / ] && rm -rf $RPM_BUILD_ROOT

%files
/usr/*

