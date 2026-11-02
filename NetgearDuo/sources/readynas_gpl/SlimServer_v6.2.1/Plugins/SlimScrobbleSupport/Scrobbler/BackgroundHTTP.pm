# BackgroundHTTP.pm
# Copyright (c) 2004-05 SlimScrobbler Team
# See Scrobbler.pm for full copyright details
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License,
# version 2.

# BackgroundHTTP provides a relatively simple way to place non-blocking
# HTTP calls, inside SlimServer. Configure the BackgroundHTTP and call
# the get() or post() methods, supplying a callback. BackgroundHTTP uses
# SlimServer's Timer feature to check for responses and execute the callback

use strict;

package Scrobbler::BackgroundHTTP;

use Net::HTTP::NB;
use Net::DNS;
use IO::Select;
use HTTP::Status;
use URI;

# If Perl version less than 5.8, use old Unicode stuff
if ($^V lt v5.8)
{
   # print "Perl version less than 5.8!\n";

   # Haven't been able to get this working yet; no Unicode on Perl 5.6 for now.
   # This means non-ASCII characters in song & track titles may be submitted
   # incorrectly.

   # require Unicode::MapUTF8;
   # import Unicode::MapUTF8;
}
else
{
   #print "Perl version 5.8 or greater.\n";

   # Requires Perl 5.8.0 or greater. Needed for UTF-8 encoding.
    require Encode;
    import Encode;
}

# We maintain a noddy DNS cache, to save explicitly looking up every single
# time.
my %dnscache = ();
my $dnscacheCountdown = Time::Countdown->new();


# Constructor. Key/value pair arguments may be provided to set up
# the initial state of the Session. The following options correspond to
# attribute methods described below:
#
#    KEY                        DEFAULT
#    ----------                 -------------
#    connectTimeout             60
#    timeout                    30
#    userAgent                  undef
#
# Or you can use the setter methods defined below.
# 
# The TCP level connect is still a blocking call, and may be lengthy.
# The connectTimeout parameter controls the maximum time spent waiting on
# this call. If the initial connect fails, your callback function will be
# called with code -1.
# 
# After the initial connect, the GET or POST request is sent. The server
# has timeout to respond completely. If it doesn't, your callback function
# will be called with code 408.

sub new
{
    my($class, %cnf) = @_;

    debug("==BackgroundHTTP.new");

    my $timeout        = delete $cnf{timeout};
    my $connectTimeout = delete $cnf{connectTimeout};
    my $useragent      = delete $cnf{useragent};

    if (!defined($timeout)) {
	$timeout = 30;
    }

    if (!defined($connectTimeout)) {
	$connectTimeout = 60;
    }

    my $self = bless {
	timeout   => $timeout,
	connectTimeout => $connectTimeout,
	useragent => $useragent,
    }, $class;

    return $self;
}

# public accessor functions

sub timeout
{
    my $self = shift;
    my $old = $self->{timeout};
    if (@_) { $self->{timeout} = shift; }
    $old;
}

sub connectTimeout
{
    my $self = shift;
    my $old = $self->{connectTimeout};
    if (@_) { $self->{connectTimeout} = shift; }
    $old;
}

sub useragent
{
    my $self = shift;
    my $old = $self->{useragent};
    if (@_) { $self->{useragent} = shift; }
    $old;
}

# Initiate a background HTTP GET. Supply the URI, a callback method
# to be called when the operation completes or timesout,
# and an argument passed in as the first parameter to the callback.
# This would normally be the object 'owning' the callback method.
sub get
{
    my $self = shift;
    my $uri = shift;
    my $callback = shift;
    my $cbparam = shift;

    debug("==BackgroundHTTP.get");

    # Cancel any existing background read
    Slim::Utils::Timers::forgetClient($self);

    my $uri_o = URI->new($uri)->canonical;

    my $host = $uri_o->host();
    my $proxy = Slim::Utils::Prefs::get('webproxy');
    if ($proxy && $host ne 'localhost' && $host ne '127.0.0.1') {
	debug("Using proxy $proxy");
	my ($proxy_server, $proxy_port) = split /:/, $proxy;
	$self->{host} = $proxy_server;
	$self->{port} = $proxy_port || 80;
    }
    else {
	$self->{host} = $uri_o->host();
	$self->{port} = $uri_o->port();
    }
    $self->{hostHeader} = $uri_o->host() . ":" . $uri_o->port();
    $self->{uri} = $uri;
    $self->{callback} = $callback;
    $self->{cbparam} = $cbparam;
    $self->{countdown} = $self->{timeout};
    $self->{method} = "get";

    $self->initiateDNSlookup();
}


# Initiate a background HTTP POST. Supply the URI, the data to POST, it's
# content-type, a callback method to be called when the operation completes
# or timesout, and an argument passed in as the first parameter to the
# callback. This would normally be the object 'owning' the callback method.
sub post
{
    my $self = shift;
    my $uri = shift;
    my $data = shift;
    my $contentType = shift;
    my $callback = shift;
    my $cbparam = shift;

    debug("==BackgroundHHTP.post");

    # Cancel any existing background read
    Slim::Utils::Timers::forgetClient($self);

    my $uri_o = URI->new($uri)->canonical;

    my $host = $uri_o->host();
    my $proxy = Slim::Utils::Prefs::get('webproxy');
    if ($proxy && $host ne 'localhost' && $host ne '127.0.0.1') {
        debug("Using proxy $proxy");
        my ($proxy_server, $proxy_port) = split /:/, $proxy;
        $self->{host} = $proxy_server;
        $self->{port} = $proxy_port || 80;
    }
    else {
        $self->{host} = $uri_o->host();
        $self->{port} = $uri_o->port();
    }
    $self->{hostHeader} = $uri_o->host() . ":" . $uri_o->port();
    $self->{uri} = $uri;
    $self->{contentType} = $contentType;
    $self->{postData} = $data;
    $self->{callback} = $callback;
    $self->{cbparam} = $cbparam;
    $self->{countdown} = $self->{timeout};
    $self->{method} = "post";

    $self->initiateDNSlookup();
}


# Called to do the DNS lookup, or decide to skip it
sub initiateDNSlookup()
{
    my $self = shift;
    my $host = $self->{host};

    # Has the cache expired? If so, reset it.
    # The cache contains an entry for localhost by default, we wouldn't
    # want this going to the DNS server.
    if ($dnscacheCountdown->hasCountdownCompleted()) {
	debug("Clearing DNS cache");
	%dnscache = ("localhost" => "127.0.0.1",);
	# reset again in, oh I don't know, two hours.
	$dnscacheCountdown->reset(7200);
	$dnscacheCountdown->run();
    }

    # First, check in the cache
    if ($dnscache{$host}) {
	# We've got this in our cache
	my $hostR=$dnscache{$host};
	debug("Resolved $host from cache: $hostR");
	$self->initiateHTTPcall($hostR);
    }

    # Is it already in dotted form?
    # (This only checks for nnn.nnn.nnn.nnn format,
    # IPv6 looks different. Oh well.)
    elsif ($host =~ m/\d+\.\d+\.\d+\.\d+/) {
	# It's an (IPv4) dotted address, skip the resolve step
	debug("$host is already resolved");
	$self->initiateHTTPcall($host);
    }

    else {
	# First, obtain a resolver object and store the list of DNS servers.
	# We'll drive each of the servers in turn until we find one that
	# works.
	my $resolver = Net::DNS::Resolver->new;
	my @dnsservers = $resolver->nameservers;

	if (@dnsservers) {
	    $resolver->nameservers($dnsservers[0]);
	    my $sock = $resolver->bgsend($host);
	    my $sel = IO::Select->new($sock);

	    $self->{resolver} = $resolver;
	    $self->{select} = $sel;
	    $self->{pollint} = 0.1;
	    $self->{dnsservers} = \@dnsservers;
	    $self->{nextdnsserver} = 1;
	    $self->{sincelastbgsend} = 0;

	    debug("Performing background DNS resolution on $host");
	    debug("...using nameserver " . $dnsservers[0]);
	    # Schedule the response read, immediately
	    Slim::Utils::Timers::setTimer($self, Time::HiRes::time(),
					  \&readDNSResponse, ($self));
	}
	else {
	    # Oops, apparently no nameservers.
	    debug("Found no DNS nameservers");
            debug("Setting code -1");
            $self->{code} = -1;
            $self->callbackWithFailure();
	}	    
    }
}


# Called to see whether we've got the DNS response back. If so, fire off
# the HTTP request
sub readDNSResponse
{
    my $self = shift;
    
    my $select = $self->{select};
    my $resolver = $self->{resolver};

    my @ready = $select->can_read(0.1);
    if (@ready) {
	my $sock = $ready[0];
	my $packet = $resolver->bgread($sock);
	if ($packet) {
	    my $hostR;
	    foreach my $rr ($packet->answer) {
		next unless $rr->type eq "A";
		$hostR=$rr->address;
	    }

	    my $host=$self->{host};
	    if (!$hostR) {
		# There were no matching records, yet no
		# error was reported. This only seems to occur
		# when the host string is already resolved, so
		# we'll proceed with the original hostname.
		debug("$host apparently already resolved");
		$hostR=$host;
	    }
	    else {
		debug("$host resolves to $hostR");
	    }

	    # Record this in our cache
	    $dnscache{$host} = $hostR;

	    $self->initiateHTTPcall($hostR);
	}
	else {
	    # The response is an error
	    debug("DNS lookup failed: ".$resolver->errorstring);
	    debug("Setting code -1");

	    $self->{code} = -1;
	    $self->callbackWithFailure();
	}
    }
    else {
	$self->{countdown} = $self->{countdown} - $self->{pollint};
	$self->{sincelastbgsend} = $self->{sincelastbgsend} + $self->{pollint};
	if ($self->{countdown} <= 0) {
	    debug("Reached timeout period waiting for DNS resolution - failing call");
	    $self->{code} = -1;
	    $self->callbackWithFailure();
	}
	else {
	    # No response yet - keep waiting.

	    # If we haven't had a response for five seconds, and we still
	    # have nameservers to try, send a lookup to the next one.
	    my $r=$self->{dnsservers};
	    my @dnsservers=@$r;
	    if (($self->{sincelastbgsend} > 5)
		&& ($self->{nextdnsserver} < @dnsservers)) {

		my $i=$self->{nextdnsserver};
		debug("...using nameserver " . $dnsservers[$i]);
		$resolver->nameservers($dnsservers[$i]);
		my $sock = $resolver->bgsend($self->{host});
		$select->add($sock);

		$self->{sincelastbgsend} = 0;
		$self->{nextdnsserver} = $i+1;
	    }

	    my $interval=$self->{pollint};
	    $self->{pollint} = $self->{pollint}*2;
	    if ($self->{pollint} > 1) { $self->{pollint}=1; }
	    Slim::Utils::Timers::setTimer($self, Time::HiRes::time()+$interval, \&readDNSResponse, ($self));
        }
    }
}

# Called to start the HTTP call, after DNS has been performed or skipped
# Rumour and guesswork suggests that we need to explicitly add the Host
# header into the write_request call, for proxy support.
sub initiateHTTPcall
{
    my $self = shift;
    my $hostR = shift;

    # Now initiate the HTTP call
    debug("Connecting to " . $hostR . ":" . $self->{port});
    my $http = Net::HTTP::NB->new(Host => $hostR . ":" . $self->{port},
				  Timeout => $self->{connectTimeout});

    if ($http) {
	debug("Connected. Sending request...");
	if ($self->{method} eq "get") {
	    if ($self->{useragent}) {
		$http->write_request(GET => $self->{uri},
				     'User-Agent' => $self->{useragent},
				     'Host' => $self->{hostHeader});
	    }
	    else {
		$http->write_request(GET => $self->{uri},
				     'Host' => $self->{hostHeader});
	    }
	}
	elsif ($self->{method} eq "post") {
	    if ($self->{useragent}) {
		$http->write_request(POST => $self->{uri},
				     'User-Agent' => $self->{useragent},
				     'Content-Type' => $self->{contentType},
				     'Host' => $self->{hostHeader},
				     $self->{postData});
	    }
	    else {
		$http->write_request(POST => $self->{uri},
				     'Content-Type' => $self->{contentType},
				     'Host' => $self->{hostHeader},
				     $self->{postData});
	    }
	}

	$self->{http} = $http;
	$self->{select} = IO::Select->new($http);
	$self->{countdown} = $self->{timeout};
	$self->{pollint} = 0.1;

	# Schedule the response read, immediately
	Slim::Utils::Timers::setTimer($self, Time::HiRes::time(),
				      \&readHeader, ($self));
    }
    else {
	debug("Could not establish HTTP::NB object: probable network error");
	debug("Setting code -1");
	$self->{code} = -1;
	$self->callbackWithFailure();
    }
}


# Called to check whether we've got the header back from the request
sub readHeader
{
    my $self = shift;

    my $select = $self->{select};
    my $http = $self->{http};
    my $waitAgain = 0;
    if ($select->can_read(0.1)) {
	my ($code, $mess, %h);

	# read_response_headers can die, so we wrap in an eval to
	# stop the die taking out the slimserver
        eval {
	    ($code, $mess, %h) = $http->read_response_headers;
	};

	if ($@) {
	    debug("HTTP request died with: $@");
	    $self->{code} = -1;
	    $self->callbackWithFailure();
	}
	elsif ($code) {
	    # If $code is undef, then the read isn't complete yet
	    debug("Received HTTP code $code: ".HTTP::Status::status_message($code));
	    $self->{code} = $code;

	    if (HTTP::Status::is_success($code)) {
		# Call into readBody immediately, which will schedule
		# further waits if needbe
		$self->{buffer}="";
		$self->{pollint}=0.1;
		readBody($self);
	    }
	    else {
		$self->callbackWithFailure();
	    }
	}
	else {
	    $waitAgain=1;
	}
    }
    else {
	$waitAgain=1;
    }

    # If we haven't yet received the headers from the server,
    # reschedule ourselves - unless we've hit our timeout
    if ($waitAgain==1) {
	$self->{countdown} = $self->{countdown} - $self->{pollint};
	if ($self->{countdown} <= 0) {
	    # Fake up 408 - Request Timeout
	    debug("Reached timeout period - failing call");
	    $self->{code} = HTTP::Status::RC_REQUEST_TIMEOUT;
	    $self->callbackWithFailure();
	}
	else {
	    my $interval=$self->{pollint};
	    $self->{pollint} = $self->{pollint}*2;
	    if ($self->{pollint} > 1) { $self->{pollint} = 1 };
	    Slim::Utils::Timers::setTimer($self, Time::HiRes::time()+$interval, \&readHeader, ($self));
	}
    }
}

# Called to check whether we've got the body back from the request
sub readBody
{
    my $self=shift;

    my $select = $self->{select};
    my $http = $self->{http};

    my $waitAgain = 0;
    if ($select->can_read(0.1)) {
	my $n;

	# It looks like read_entity_body can die, so we read the
	# buffer inside an eval block.
	eval {
	    do {
		my $buf;
		$n = $http->read_entity_body($buf, 1024);
		if ($n>0) {
		    $self->{buffer} = $self->{buffer} . $buf;
		}
	    } while ($n>0);
	};

        if ($@) {
            debug("HTTP request died with: $@");
            $self->{code} = -1;
            $self->callbackWithFailure();
        }
        elsif ($n==0) {
	    # EOF. Call the callback.
	    $self->callbackWithSuccess();
	}
	else {
	    # There's more data to come
	    $waitAgain = 1;
	}
    }
    else {
	$waitAgain = 1;
    }

    # If we haven't yet received all the data from the server,
    # reschedule ourselves - unless we've hit our timeout
    if ($waitAgain==1) {
        $self->{countdown} = $self->{countdown} - $self->{pollint};
        if ($self->{countdown} == 0) {
            debug("Reached timeout period - failing call");
            # Fake up 408 - Request Timeout
            $self->{code} = HTTP::Status->RC_REQUEST_TIMEOUT;
            $self->callbackWithFailure();
        }
        else {
	    my $interval=$self->{pollint};
	    $self->{pollint} = $self->{pollint}*2;
	    if ($self->{pollint}>1) {$self->{pollint}=1};
	    Slim::Utils::Timers::setTimer($self, Time::HiRes::time()+$interval, \&readBody, ($self));
	}
    }
}

sub callbackWithFailure()
{
    my $self=shift;

    my $code=$self->{code};
    my $callback=$self->{callback};
    my $cbparam=$self->{cbparam};

    debug("BackgroundHTTP calling callback with failure");
    &$callback($cbparam, $code, undef);
}

sub callbackWithSuccess()
{
    my $self=shift;

    my $code=$self->{code};
    my $callback=$self->{callback};
    my $cbparam=$self->{cbparam};
    my $buffer=$self->{buffer};

    debug("BackgroundHTTP calling callback with response data");
    &$callback($cbparam, $code, $buffer);
}


# Private method which logs debug text
sub debug($)
{
    my $line=shift;
    Plugins::Scrobbler::scrobbleMsg("$line\n");
}

# Packages must return true
1;
