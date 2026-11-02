#!/usr/bin/perl

# This script tries to generate a manual page for proftpd.conf(5) out
# of the file ../doc/Configuration.html.

$date = `date +"%e %B %Y"`;
$date =~ tr/\r\n//d;

print <<EOF;
.\" This file was automatically generated on $date from Configuration.html.
.\" This file may be distributed under the GNU General Public License.
.\"
.TH PROFTPD.CONF 5 "$date" "proftpd.conf" "Debian proftpd"
.SH NAME
proftpd.conf \- Configuration file for ProFTPD
.SH DESCRIPTION
.PP
\\fBWARNING: This file was automatically generated\\fR from the file
\\fI/usr/share/doc/proftpd-doc/Configuration.html\\fR (from the
package \\fIproftpd-doc\\fR).  It is very well possible that there are
a few remaining conversion errors.  If in doubt, always consult the
HTML version.
.PP
This manual page describes the configuration options that are
available in the proftpd configuration file \\fI/etc/proftpd.conf\\fR.
.SH SYNTAX
.PP
A list of available options follow.
.PP
EOF

$header_started = 0;

while (<STDIN>) {
    s/&lt;/\</g;
    s/&gt;/\>/g;
    s/&amp;/&/g;
    s/&quot;/"/g;
    if(m%^<h2><a[^>]*>(.+)</a></h2>$%i) {
	print ".TP\n\\fB$1\\fR\n";
	$block_started = 1;
    } else {
	if($block_started) {
	    if($header_started != 2 && m%^.*<strong>(.*):</strong>(.*)<[^>]*>$%i) {
		if(!$header_started) {
		    $header_started = 1;
		    print "\n.TS\ntab(\@);\nl l.\n";
		}
		$field = $1;
		$value = $2;
		$value =~ s%<strong>%\\fB%gi;
		$value =~ s%<em>%\\fI%gi;
		$value =~ s%<i>%\\fI%gi;
		$value =~ s%</strong>%\\fR%gi;
		$value =~ s%</em>%\\fR%gi;
		$value =~ s%</i>%\\fR%gi;
		print "\\fB$field\\fR:\@$value\n";
	    } else {
		if(m%<hr>%i) {
		    $block_started = 0;
		    $header_started = 0;
		} else {
		    if($header_started == 1) {
			$header_started = 2;
			print ".TE\n\n";
		    }
		    s/^\s+//g;
		    if(m%^<p>%i) {
			print "\n";
			s/^<p>//i;
		    }
		    if(s%^(<[^>]+>)*<code>%%gi) {
			$code_started = 1;
			print ".PP\n.sp\n.nf\n.in +10\n";
			s%</p>%%i;
			if(s%</code>$%%gi) {
			    $code_started = 0;
			    print;
			    print ".fi\n.PP\n";
			} else {
			    s%<br>%%gi;
			    print;
			}
		    } else {
			s%</p>%%i;
			s%<strong>%\\fB%gi;
			s%<em>%\\fI%gi;
			s%<i>%\\fI%gi;
			s%</strong>%\\fR%gi;
			s%</em>%\\fR%gi;
			s%</i>%\\fR%gi;
			if($link_started) {
			    s%^[^>]*>(.*)</a>%\\fB$1\\fR%i;
			    $link_started = 0;
			}
			s%<a[^>]*>(.*)</a>%\\fB$1\\fR%gi;
			if($code_started) {
			    s%<br>%%gi;
			} else {
			    s%<br>%\n%gi;
			}
			if(s%</code>$%%gi) {
			    $code_started = 0;
			    print;
			    print ".fi\n.PP\n";
			} else {
			    if(s%<a[^>]*$%%i) {
				$link_started = 1;
			    }
			    print;
			}
		    }
		}
	    }
	}
    }
}

print <<EOF;
.PP
.SH "SEE ALSO"
\\fBproftpd\\fR(8)
.PP
The full documentation for
.B proftpd.conf
is maintained as a HTML file in the package
.B proftpd-doc
; if for example the
.B lynx
and
.B proftpd-doc
packages are properly installed at your site, the command
.IP
.B lynx /usr/share/doc/proftpd-doc/Configuration.html
.PP
should give you access to the complete manual.
EOF
