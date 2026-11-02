# Session.pm
# Copyright (c) 2004-05 SlimScrobbler Team
# See Scrobbler.pm for full copyright details
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License,
# version 2.

# Session maintains a single handshake with AudioScrobbler (and is
# associated with a userid). It manages submissions to AS and persists
# anything it can't currently submit to a file.

use strict;

package Scrobbler::Session;

use File::Spec;
use LWP::UserAgent;
use Time::Countdown;
use Math::Round;
use Slim::Utils::Misc;
use HTTP::Status;

use Scrobbler::BackgroundHTTP;

# Use slow, pure-perl implementation of MD5 for ease of installation
use Digest::Perl::MD5;

# Call back to Plugins::Scrobbler for logging etc.
use Plugins::Scrobbler;

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


# Constructor. Key/value pair arguments may be provided to set up
# the initial state of the Session. The following options correspond to
# attribute methods described below:
#
#    KEY                        DEFAULT
#    ----------                 -------------
#    userid                     undef
#    password                   undef
#    pendingSongFile            function of userid
#
# Or you can use the setter methods defined below. You really should set
# userid and password before calling other functions on this object.

sub new
{
    my($class, %cnf) = @_;

    debug("==Session.new");

    my $userid          = delete $cnf{userid};
    my $password        = delete $cnf{password};
    my $pendingSongFile = delete $cnf{pendingSongFile};

    my $self = bless {
	userid   =>        $userid,
        password =>        $password,
        pendingSongFile => $pendingSongFile,
    }, $class;

    if (!defined($pendingSongFile)) {
	$self->calcDefaultPendingSongFile();
    }

    if (defined($password)) {
	$self->{passwordMD5} = Digest::Perl::MD5::md5_hex($password);
    }
    $self->clearHandshake();

    my $vars = Plugins::Scrobbler::sessionVars();

    # Our interval Countdown timer. If getRemainingTime() is 0, we can
    # try talking to the Audioscrobbler server again.
    $self->{intervalCountdown} = Time::Countdown->new();

    # A BackgroundHTTP object, used to submit http requests without
    # holding up the server.
    $self->{backgroundHTTP} = Scrobbler::BackgroundHTTP->new();
    my $agentName = vars()->{SCROBBLE_PLUGIN_NAME} . "/" . vars()->{SCROBBLE_PLUGIN_VERSION};
    $self->{backgroundHTTP}->useragent($agentName);
    $self->{backgroundHTTP}->connectTimeout(vars()->{SCROBBLE_NB_COMMS_TIMEOUT});

    # Our current background-submit status
    # 0 - no background submission in progress
    # 1 - background submission in handshake phase
    # 2 - background submission in post phase
    $self->{backgroundSubmitStatus} = 0;

    # If we're background-submitting, upon POST failure we want to
    # rehandshake only if we were using a previous handshake.
    $self->{rehandshake} = 'false';

    # If we're background-submitting, set the initial delay interval
    # between retries
    $self->{retryDelay} = vars()->{SCROBBLE_RETRY_MIN_DELAY};

    return $self;
}

# public accessor functions

# Note that setting the userid also overrides the current pending
# song file.
sub userid
{
    my $self = shift;
    my $new = shift;
    my $old = $self->{userid};
    if ($new && (!($old) || ($new ne $old))) {
	$self->{userid} = $new;
	$self->calcDefaultPendingSongFile();
	$self->clearHandshake();
	$self->cancelInterval();
    }
    $old;
}

sub password
{
    my $self = shift;
    my $new = shift;
    my $old = $self->{password};
    if ($new && (!($old) || ($new ne $old))) {
	$self->{password} = $new;
	$self->{passwordMD5} = Digest::Perl::MD5::md5_hex($self->{password});
	$self->clearHandshake();
	$self->cancelInterval();
    }
    return $old;
}

sub passwordMD5 { shift->{passwordMD5}; }

sub pendingSongFile
{
    my $self = shift;
    my $old = $self->{pendingSongFile};
    if (@_) { $self->{pendingSongFile} = shift; }
    $old;
}



# Public method, called when a track should be added to the pending file.
# Sometime after calling this, call tryToSubmitToAudioscrobblerIfNeeded
# to perform any possible actual submission
#
# This function will put data of this sort into the pending file:
#
# a[0]=Metallica
# s[0]=Sad But True
# l[0]=219
# d[0]=28/02/2003 12:18:59
#
# The pending file will eventually be read, its contents submitted, and
# the file cleared. This might happen immediately or much later - it
# depends on if Audioscrobbler.com is available, and on user preferences.
sub logTrackToAudioScrobblerAsPlayed($$$)
{
    my $self = shift;

    # Parameters - What to log
    my $track = shift;
    my $UTCtime = shift;

    debug("==logTrackToAudioScrobblerAsPlayed()");

    # If we have 1 entries, the next index number is 1 since indexes are numbered
    # from 0.
    my $nextEntryNumber = $self->getNumberOfSongsPendingToSubmit();

    # Create entry for the song (see comment for format)
    my $songEntry = $track->makeSongEntryText( $nextEntryNumber, $UTCtime );

    # Add the song block to the pending submissions file
    $self->addSongRecordToPendingFile($songEntry);

    # If we have an existing submission waiting for a response from
    # the post, then we keep a separate record of this track in memory
    # Then, if the post succeeds, we'll clear the file and rewrite this
    # track (otherwise we'd lose it). If the post fails, we've already
    # got the track in the file.
    if ($self->{backgroundSubmitStatus} == 2) {
	my @tracks = $self->{backgroundTemporaryTracks};
	if (!@tracks) { @tracks = (); }
	push (@tracks, $track);
	push (@tracks, $UTCtime);

	# Is this necessary?
	$self->{backgroundTemporaryTracks} = @tracks;
    }

    # Take this opportunity to trace our status
    $self->showCurrentVariables();
}


# Public method.
# See if we should submit to Audioscrobbler now or not.
# If we should, try to submit.
sub tryToSubmitToAudioscrobblerIfNeeded($)
{
    my $self = shift;

    if ($self->shouldTryToSubmitToAudioscrobbler())
    {
	debug("About to attempt submit to Audioscrobbler..");
	$self->attemptToSubmitToAudioScrobbler();
    }
}

# Public method.
# Attempt to submit the contents of the pending
# file to Audioscrobbler. If it succeeds, the
# pending file will be cleared. If pending file
# is empty, does nothing.
# This is much like calling "tryToSubmitToAudioscrobblerIfNeeded"
# except we ignore the resubmission interval. This is useful,
# say, to submit while dialled up.
# If there's a background submission currently occuring, do nothing
# TODO sort that out; at the moment I think the same flag is used
# to distinguish between recording played music and auto-submitting.
# They should probably be different, and this method never called while
# auto-submitting.
sub attemptToSubmitToAudioScrobbler($)
{
    my $self = shift;

    debug("==attemptToSubmitToAudioScrobbler()");

    if ($self->{backgroundSubmitStatus} != 0) {
	debug("Background submission in progress; aborting submit");
	return;
    }

    # Only attempt to submit if there are songs pending
    if ($self->areSongsPendingToSubmit())
    {
        # Get all the pending songs
        my $allPendingSongs = $self->getAllSongRecordsFromPendingFile();

        # If we've handshaked, attempt the submit
        if ($self->{haveHandshaked} eq 'true')
        {
            $self->doSubmit($allPendingSongs);
        }

        if ($self->{haveHandshaked} eq 'false')
        {
            # We might be here if we have not previously handshaked,
            # or if the previous submit attempt failed and reset the
            # the handshake flag.
            # Either way, we need to perform a handshake and then
            # attempt the submission. If the submit fails this time,
            # we'll delay our submit for 30 minutes.

            $self->doHandshake();

            if ($self->{haveHandshaked} eq 'true')
            {
                $self->doSubmit($allPendingSongs);
            }

            if ($self->{haveHandshaked} eq 'false')
            {
                # Either the handshake failed, or the submit attempt
                # failed. Perhaps the userid/password is wrong, or
                # audioscrobbler is down. Wait the delay period before
                # trying again.
                debug("Handshake failure, waiting before retry");
                $self->setInterval(vars()->{SCROBBLE_RETRY_DELAY});
            }
        }

	# Trace status after this submission
	$self->showCurrentVariables();
    }
}

# Public method.
# See if we should submit to Audioscrobbler now or not.
# If we should, try to submit in the background
sub tryToBackgroundSubmitToAudioscrobblerIfNeeded($)
{
    my $self = shift;

    if ($self->shouldTryToSubmitToAudioscrobbler())
    {
        debug("About to attempt submit to Audioscrobbler..");

	if ($self->{haveHandshaked} eq 'true')
	{
	    $self->{rehandshake} = 'true';
	    $self->doBackgroundSubmit();
	}
	else {
	    $self->doBackgroundHandshakeThenSubmit();
	}
    }
}



# Public method.
# Debugging routine - shows current variable values
sub showCurrentVariables($)
{
    my $self = shift;

    my $userid = $self->{userid};
    debug("Session status for ${userid}:");

    my $pendingCount = $self->getNumberOfSongsPendingToSubmit();
    my $maxPendingCount = Slim::Utils::Prefs::get("plugin_scrobbler_max_pending");
    debug("  Pending submissions / Max :  $pendingCount / $maxPendingCount");
    
    debug("  Background Submit Status: " . $self->{backgroundSubmitStatus});

    my $remainingInterval = $self->{intervalCountdown}->getRemainingTime();
    my $elapsedInterval = $self->{intervalCountdown}->getElapsedTime();
    my $originalInterval = $self->{intervalCountdown}->getCountdownTime();
    debug("  Interval Countdown remaining / elapsed / original : $remainingInterval / $elapsedInterval / $originalInterval");
}


####### What follows are private methods, and shouldn't oughta be called
####### from outside this class.
####### (Does perl provide any way to police this?)

# UTF-8 encode, then URL encode.
# Used for any data coming from user's songs.
# Note that this is a regular function, not an object method
# TODO this is duplicated in Session.pm, maybe it should go somewhere central
sub formatUserDataField($)
{
    my $userDataField = shift;

    return URI::Escape::uri_escape_utf8($userDataField);
}

# Makes the decision about whether to try and
# submit to Audioscrobbler - this might involve
# several factors that I can think of.
sub shouldTryToSubmitToAudioscrobbler($)
{
    my $self = shift;

    # Only submit if:
    # - We have enough entries
    # - Re-submit interval has passed
    # - we are not already background-submitting

    # Other criteria could certainly be added here.

    if (($self->{intervalCountdown}->hasCountdownCompleted())
	&& ($self->{backgroundSubmitStatus} == 0)) {

	my $pendingCount = $self->getNumberOfSongsPendingToSubmit();
	if ($pendingCount >= Slim::Utils::Prefs::get("plugin_scrobbler_max_pending"))
	{
	    debug("It IS time to submit!");
	    return 1;
	}
	else
	{
	    # debug("Not yet time to submit..");
	    return 0;
	}
    }
    else
    {
	return 0;
    }
}

# Sets the delay before submitting again, without trashing any
# existing, longer, delay.
sub setInterval($$)
{
    my $self = shift;
    my $newInterval = shift;

    my $remaining = $self->{intervalCountdown}->getRemainingTime();

    # Set our Interval countdown running
    if ($remaining < $newInterval)
    {
	debug( "Setting interval: $newInterval");
	$self->{intervalCountdown}->reset($newInterval);
	$self->{intervalCountdown}->run();
    }
    else {
      debug( "Leaving remaining interval at $remaining" );
    }
}

# Removes any delay before submitting again.
sub cancelInterval($)
{
    my $self = shift;
    $self->{intervalCountdown}->reset(0);
}

# Add the song block to the pending submissions file.
sub addSongRecordToPendingFile($$)
{
    my $self = shift;

    # The song entry we are adding
    my $latestEntry = shift;

    my $pendingSongFilename = $self->{pendingSongFile};
    debug("Writing song entry to \"$pendingSongFilename\"...");

    # Attempt to open pending song submission file
    if ( open(SONGFILE,">>$pendingSongFilename") )
    {
	my($writeSuccess) = print SONGFILE $latestEntry;
	if (!$writeSuccess)
	{
	    msg("Audioscrobbler could not write to \"$pendingSongFilename\"; song record lost!\n");
	}
	
	close(SONGFILE);
    }
    else
   {
      msg("Audioscrobbler could not open \"$pendingSongFilename\"; song record lost!\n");
  }
}

# Read the entire pending song submissions file.
sub getAllSongRecordsFromPendingFile($)
{
    my $self = shift;

    my $allSongRecords = "";

    my $pendingSongFilename = $self->{pendingSongFile};

    #try to open file
    my($openFailed) = !(open(SONGFILE,'<'.$pendingSongFilename));

    if (!$openFailed)
    {
	#read in whole file into string
	while(<SONGFILE>)
	{
	    $allSongRecords .= $_;
	}

	close(SONGFILE);
    }
    else
    {
	msg("Audioscrobbler could not open \"$pendingSongFilename!\"\n");
    }

    return $allSongRecords;
}

# Clear the pending song submissions file.
sub clearPendingFile($)
{
    my $self = shift;

    #attempt to delete file
    my($deleteSuccess) = unlink ( $self->{pendingSongFile} );

    #assert that delete was successful
    if (!$deleteSuccess)
    {
	my $pendingSongFilename = $self->{pendingSongFile};
	msg("Audioscrobbler could not delete \"$pendingSongFilename\"; song records may be confused!\n");
    }
}

# Are there pending song submissions in the pending file?
sub areSongsPendingToSubmit($)
{
    my $self = shift;

    return ($self->getNumberOfSongsPendingToSubmit() > 0);
}

# Get the number of songs pending to submit
sub getNumberOfSongsPendingToSubmit($)
{
    my $self = shift;

    # Number of songs pending to submit
    my $numberSongsPending = 0;

    my $tmpPendingSongfile = $self->{pendingSongFile};
#    debug("Pending song file: \"$tmpPendingSongfile\"");

    # Only try to read the pending file if it exists
    if (doesFileExist($tmpPendingSongfile))
    {
#	debug("Pending file \"$tmpPendingSongfile\" exists, reading..");

	# We read the pending file in
	my $wholePendingFile = $self->getAllSongRecordsFromPendingFile();

	# debug("Whole pending file:\n $wholePendingFile");

	# Look for the last Date record. For example:
	#
	# <..other data in file..>
	# <...>
	# d[33]=28/02/2003 12:18:59
	#
	# This would be the 33'rd entry in the list,
	
	# Try to find d[XX]= in the pending file
	# (We match greedily on the beginning of the file to find the last occurrance of d[XX]=)
	if ($wholePendingFile =~ m/.*\[(\d+)\]=/)
	{
	    # If we found any d[XX]= entries, take the last XX.
	    $numberSongsPending = $1 + 1;

#	    debug("Found $numberSongsPending songs pending to submit..");
	}
	else
	{
	    msg("Audioscrobbler error: Could not understand data in pending file \"$tmpPendingSongfile\", d[xx] entry not found!\n");
      }
   }
   else
   {
#      Plugins::Scrobbler::scrobbleMsg("Pending file \"$tmpPendingSongfile\" does not exist..\n");
   }

   # Return number of songs pending
   return($numberSongsPending);
}

# Does a given file exist?
# Note that this is a regular function, not an object method
sub doesFileExist($)
{
    # Parameter - Full path to filename to look for
    my $PathAndFile = shift;

    # Make sure file exists
    if (!(-e $PathAndFile))
    {
	return 0;
    }

    # Make sure it is a file, not a directory
    if (!(-f $PathAndFile))
    {
	return 0;
    }

    # Make sure we can read it
    if (!(-r $PathAndFile))
    {
	return 0;
    }

    # Success!
    return 1;
}



# This is the main routine for doing a Handshake
# with the AudioScrobbler server.
sub doHandshake($)
{
    # Parameter - PlayTrackStatus for current client
    my $self = shift;

    debug("==doHandshake()");

   # If we have yet to handshake..
    if ($self->{haveHandshaked} eq 'false')
    {
	# Set up a User Agent to be used during the transaction.
	$self->{userAgent} = LWP::UserAgent->new();

	# Identify ourselves as the SlimScrobbler plug-in.
	my $agentName = vars()->{SCROBBLE_PLUGIN_NAME} . "/" . vars()->{SCROBBLE_PLUGIN_VERSION};
	$self->{userAgent}->agent($agentName);

	# Set the HTTP timeout
	$self->{userAgent}->timeout(vars()->{SCROBBLE_COMMS_TIMEOUT});

	# Handshake with the Audioscrobbler server
	my $handshakeResult = $self->submitHandshake();

	# If the handshake was valid..
	if ($self->handshakeWasGood($handshakeResult))
	{
	    # Parse the handshake result for the submit URL
	    my $postURL="";
	    my $postMD5="";
	    ($postURL,$postMD5) = $self->parseHandshakeResultAndGetPostURL($handshakeResult);
	    $self->{postURL} = $postURL;
	    $self->{postMD5} = $postMD5;

	    # Set handshake flag to good
	    $self->{haveHandshaked} = 'true';
	}
    }
}

sub submitHandshake($)
{
    my $self = shift;

    my $userAg = $self->{userAgent};
    my $sessionVars = vars();

    debug("==submitHandshake()");

    ## Handshake
    ############


    # Build the request to start our handshake with the server:
    #   http://post.audioscrobbler.com/?hs=true&v=1.0&c=slm
    #
    my $requestURLString = "";
    $requestURLString = 'http://' . $sessionVars->{SCROBBLE_SERVER};
    $requestURLString .= '?';
    $requestURLString .= 'hs=true';
    $requestURLString .= '&';
    $requestURLString .= 'p=1.1';
    $requestURLString .= '&';
    $requestURLString .= 'c=' . $sessionVars->{SCROBBLE_CLIENT_ID};
    $requestURLString .= '&';
    $requestURLString .= 'v=' . $sessionVars->{SCROBBLE_PLUGIN_VERSION};
    $requestURLString .= '&';
    $requestURLString .= 'u=' . $self->{userid};

    my $req = HTTP::Request->new(GET => $requestURLString);
    $req->header('Accept' => 'text/html');

    debug("Requesting GET on URL: " . $requestURLString );

    # Send request
    my $handshakeResult = $userAg->request($req);

    # Check the outcome
    if ($handshakeResult->is_success)
    {
	debug( $handshakeResult->content );
    }
    else
    {
	debug( "AudioScrobbler HTTP Error: " . $handshakeResult->status_line );
    }

    # Return the handshake results
    return ( $handshakeResult );
}

# Was this a valid handshake?
sub handshakeWasGood($$)
{
    my $self = shift;

    debug("");
    debug("==handshakeWasGood()");

    # Parameter - Result of Handshake
    my $handshakeResult = shift;

    # Handshake was good if the HTTP transaction succeeded AND
    # the response was what we expected.
    my $postURL="";
    my $postMD5="";
    ($postURL,$postMD5)=$self->parseHandshakeResultAndGetPostURL($handshakeResult);
    return ( ($handshakeResult->is_success) && ($postURL ne "") );
}

sub parseHandshakeResultAndGetPostURL($$)
{
    my $self = shift;
    my $handshakeResult = shift;

    debug("==parseHandshakeResultAndGetPostURL()");

    return ($self->parseHandshakeResultFromContent($handshakeResult->content));
}

sub parseHandshakeResultFromContent($$)
{
    my $self = shift;

    debug("==parseHandshakeResultFromContent()");

    # Parameter - Handshake result
    my $content = shift;

    #  Expect four lines from the server:
    #
    #  UPTODATE
    #  <md5 challenge>
    #  <post url>
    #  INTERVAL n

    # The URL we should submit our data to.
    my $postURL = "";
    my $postMD5 = "";

    # Does it look like a valid response?
    if ($content =~ m/UPTODATE\n(.*)\n(http:.*)\nINTERVAL ([0-9]*)/)
    {
	# Pull out md5 Challenge
	$postMD5 = $1;
	# Pull out post URL
	$postURL = $2;
	# Pull out re-post interval
	my $postInterval = $3;

	debug( "" );
	debug( "Got MD5 Challenge : $postMD5" );
	debug( "Got Post URL      : $postURL" );
	debug( "Got INTERVAL      : $postInterval" );
	
	# Set our Interval countdown running
	$self->{intervalCountdown}->reset($postInterval);
	$self->{intervalCountdown}->run();
    }
    elsif ($content =~ m/UPDATE(.*)/)
    {
	# The plug-in appears to be out of date. The server should
	# give us a URL to consult to get the latest version.
	my $updateURL = $1;

	debug( "AudioScrobbler Plugin is out-of date! Please visit $updateURL for the latest version." );
    }
    else
    {
	debug( "AudioScrobbler HTTP Error: Couldn't find URL in GET response!" );
    }

    # Return the URL we should post to.
    return ($postURL,$postMD5);
}


# Submit a set of track info to AudioScrobbler
sub doSubmit($$)
{
    my $self = shift;

    # Parameter - all pending songs to submit
    my $allPendingSongs = shift;

    debug("==doSubmit()");

    # Post to the Post URL
    my $postResult = $self->postDataToPostURL($allPendingSongs);

    # Parse the results
    $self->parsePostResults($postResult);
}

# Post the submission data to the POST URL.
sub postDataToPostURL($$)
{
    my $self = shift;

    # Parameter - all pending songs to submit
    my $allPendingSongs = shift;

    my $md5PasswordDigest = Digest::Perl::MD5::md5_hex($self->{passwordMD5} . $self->{postMD5});

    my $songPlayPost = "";

    debug("==postDataToPostURL()");

    # User ID & Password (MD5 hashed)
    $songPlayPost  = "u=" . formatUserDataField($self->{userid}) . vars()->{SCROBBLE_SUBMIT_DELIMITER};
    $songPlayPost .= "s=" . formatUserDataField($md5PasswordDigest) . vars()->{SCROBBLE_SUBMIT_DELIMITER};

    # Add all the song data we retrieved above
    $songPlayPost .= $allPendingSongs;

    # POST the song data
    my $songPostReq = HTTP::Request->new(POST => $self->{postURL});

    $songPostReq->content_type('application/x-www-form-urlencoded');
    $songPostReq->content($songPlayPost);

    debug("\nRequesting POST on URL: \"" . $self->{postURL} . "\"");
    debug("Data posted: \n" . $songPlayPost );

    # send request
    my $postResult = $self->{userAgent}->request($songPostReq);

    # Return post result
    return($postResult);
}

sub parsePostResults($$)
{
    my $self = shift;

    # Parameter - results of the POST operation
    my $postResult = shift;

    debug("==parsePostResults()");

    # Check the outcome for POSTing
    if ($postResult->is_success)
    {
	debug( $postResult->content );

	# Try to make sense of the reponse
	if ($postResult->content =~ m/BADPASS/)
	{
	    msg( "\nAudioScrobbler POST Error: Bad username or password!\n" );
	}
	elsif ($postResult->content =~ m/BADAUTH/)
	{
	    msg( "\nAudioScrobbler POST Error: Authentication unsuccesful: probably bad username or password\n" );
	    
	    # Well, it may be a bad username or password; or it may be that the
	    # server has forgotten our MD5 sum: in which case we should handshake
	    # again.
	    $self->clearHandshake();
	}
	elsif ($postResult->content =~ m/FAILED(.*)/)
	{
	    msg( "\nAudioScrobbler POST Error: $1\n" );
	}
	elsif ($postResult->content =~ m/OK/)
	{
	    debug( "AudioScrobbler submit success! Clearing pending file..." );

	    # Clear pending song submits; we have succeeded.
	    $self->clearPendingFile();
	}

	# If there's an INTERVAL specified, keep track of it
	if ($postResult->content =~ m/INTERVAL (.*)/)
	{
	    my $postInterval = $1;
	    
	    # Set our Interval countdown running
	    $self->setInterval($postInterval);
	}
    }
    else
    {
	# We've hit some HTTP error. It's possible that the server is
	# not receiving right now, which can lead to lengthy pauses between
	# songs while our HTTP requests time out. So wait awhile before trying
	# again.
	debug( "AudioScrobbler HTTP Error: " . $postResult->status_line );
	$self->setInterval(vars()->{SCROBBLE_RETRY_DELAY});
    }
}



#######################################################
# BACKGROUND SUBMISSION FUNCTIONS
# This lot duplicates much of what's above. Oh well.

# Fires off a handshake request. Assuming the handshake was successful,
# fire off a submit request
sub doBackgroundHandshakeThenSubmit
{
    my $self = shift;

    debug("==doBackgroundHandshakeThenSubmit");

    # Set our submit status flag to 'handshaking'
    $self->{backgroundSubmitStatus} = 1;

    # Assuming our handshake works, upon submit failure we
    # don't want to redo the handshake.
    $self->{rehandshake} = 'false';

    my $http = $self->{backgroundHTTP};
    my $sessionVars = vars();

    # Build the request to start our handshake with the server:
    #   http://post.audioscrobbler.com/?hs=true&v=1.0&c=slm
    #
    my $requestURLString = "";
    $requestURLString = 'http://' . $sessionVars->{SCROBBLE_SERVER};
    $requestURLString .= '?';
    $requestURLString .= 'hs=true';
    $requestURLString .= '&';
    $requestURLString .= 'p=1.1';
    $requestURLString .= '&';
    $requestURLString .= 'c=' . $sessionVars->{SCROBBLE_CLIENT_ID};
    $requestURLString .= '&';
    $requestURLString .= 'v=' . $sessionVars->{SCROBBLE_PLUGIN_VERSION};
    $requestURLString .= '&';
    $requestURLString .= 'u=' . $self->{userid};

    debug("Firing GET on URL: " . $requestURLString);
    $http->get($requestURLString, \&handleHandshakeResponse, $self);
}

sub handleHandshakeResponse
{
    my $self = shift;
    my $code = shift;
    my $response = shift;

    debug("==handleHandshakeResponse()");

    if ($code == -1) {
	debug("No connection made, waiting before retry");
	$self->clearHandshake();
	$self->setInterval($self->{retryDelay});
	$self->{backgroundSubmitStatus} = 0;
	$self->{retryDelay} = max($self->{retryDelay} * 2,
				  vars()->{SCROBBLE_RETRY_MAX_DELAY});
	$self->showCurrentVariables();
    }
    elsif (HTTP::Status::is_success($code)) {
	debug("\n".$response);

	my ($postURL,$postMD5)=$self->parseHandshakeResultFromContent($response);
	if ($postURL ne "") {
	    # Our handshake was a success - we got a URL and MD5.
	    $self->{postURL} = $postURL;
	    $self->{postMD5} = $postMD5;
	    $self->{haveHandshaked} = 'true';
	    $self->{retryDelay} = vars()->{SCROBBLE_RETRY_MIN_DELAY};

	    $self->doBackgroundSubmit();
	}
	else {
	    debug("Handshake failure, waiting before retry");
	    $self->clearHandshake();
	    $self->setInterval($self->{retryDelay});
	    $self->{backgroundSubmitStatus} = 0;
	    $self->{retryDelay} = max($self->{retryDelay} * 2,
				      vars()->{SCROBBLE_RETRY_MAX_DELAY});
	    $self->showCurrentVariables();
	}
    }
    else {
	debug("Got bad return code, waiting before retry");
	$self->clearHandshake();
	$self->setInterval($self->{retryDelay});
	$self->{backgroundSubmitStatus} = 0;
	$self->{retryDelay} = max($self->{retryDelay} * 2,
				  vars()->{SCROBBLE_RETRY_MAX_DELAY});
	$self->showCurrentVariables();
    }
}

# Fires off a submit request. If the submit fails, optionally
# force a new handshake and try again
sub doBackgroundSubmit
{
    my $self=shift;

    debug("==doBackgroundSubmit()");

    $self->{backgroundSubmitStatus} = 2;

    my $allPendingSongs = $self->getAllSongRecordsFromPendingFile();

    my $md5PasswordDigest = Digest::Perl::MD5::md5_hex($self->{passwordMD5} . $self->{postMD5});

    my $songPlayPost;

    # User ID & Password (MD5 hashed)
    $songPlayPost  = "u=" . formatUserDataField($self->{userid}) . vars()->{SCROBBLE_SUBMIT_DELIMITER};
    $songPlayPost .= "s=" . formatUserDataField($md5PasswordDigest) . vars()->{SCROBBLE_SUBMIT_DELIMITER};

    # Add all the song data we retrieved above
    $songPlayPost .= $allPendingSongs;
	    

    my $http=$self->{backgroundHTTP};
    debug("Requesting POST on URL: \"" . $self->{postURL} . "\"");
    debug("Posting data: \n" . $songPlayPost);

    $http->post($self->{postURL},
		$songPlayPost, 'application/x-www-form-urlencoded',
		\&handleSubmitResponse, $self);
}

sub handleSubmitResponse
{
    my $self = shift;
    my $code = shift;
    my $response = shift;

    my $success;

    debug("==handleSubmitResponse()");

    if ($code == -1) {
        debug("No connection made, will not rehandshake");
	$success = 'false';
	$self->{rehandshake} = 'false';
    }
    elsif (HTTP::Status::is_success($code)) {
        debug("\n".$response);

	# Try to make sense of the reponse
	if ($response =~ m/BADPASS/)
	{
	    debug( "AudioScrobbler POST Error: Bad username or password!" );
	    $success = 'false';
	}
	elsif ($response =~ m/BADAUTH/)
	{
	    debug( "AudioScrobbler POST Error: Authentication unsuccesful: probably bad username or password" );
	    $success = 'false';
	}
	elsif ($response =~ m/FAILED(.*)/)
	{
	    debug( "AudioScrobbler POST Error: $1" );
	    $success = 'false';
	}
	elsif ($response =~ m/OK/)
	{
	    debug( "AudioScrobbler submit success!" );
	    $success = 'true';
	}

	# If there's an INTERVAL specified, keep track of it
	if ($response =~ m/INTERVAL (.*)/)
	{
	    my $postInterval = $1;

            # Set our Interval countdown running
	    $self->setInterval($postInterval);
	}
    }
    else {
	debug ("Got bad return code from POST");
	$success = 'false';
    }

    if ($success eq 'true')
    {
	debug("Clearing pending file");
	$self->clearPendingFile();

	# If any tracks were registered while we were waiting, then
	# they will have been stored in memory. Having cleared the
	# pending file we need to rewrite them
	my @tracks=$self->{backgroundTemporaryTracks};
	
	my $num=0;
	my $done=0;
	if (@tracks) {
	    while ($done==0) {
		my $track=shift(@tracks);
		my $time=shift(@tracks);

		if ($track) {
		    # Add the song block to the pending submissions file
		    my $songEntry = $track->makeSongEntryText($num, $time);
		    $self->addSongRecordToPendingFile($songEntry);
		    $num=$num+1;
		}
		else {
		    $done=1;
		}
	    }

	    $self->{backgroundTemporaryTracks} = undef;
	}

	$self->{backgroundSubmitStatus} = 0;
    }
    else {
	# Clear the list of tracks registered while we were trying
	# to submit. These should have been written to the file as well,
	# so we should pick them up next time
	$self->{backgroundTemporaryTracks} = undef;

	if ($self->{rehandshake} eq 'true') {
	    $self->clearHandshake();
	    $self->doBackgroundHandshakeThenSubmit();
	}
	else {
	    debug("Waiting before retry");
	    $self->clearHandshake();
	    $self->setInterval($self->{retryDelay});
	    $self->{backgroundSubmitStatus} = 0;
	    $self->{retryDelay} = max($self->{retryDelay} * 2,
				      vars()->{SCROBBLE_RETRY_MAX_DELAY});
	}
    }
    
    $self->showCurrentVariables();
}



#######################################################


# Private method which clears out any initialized state data relating
# to the AS session
sub clearHandshake
{
    my $self = shift;
    $self->{haveHandshaked} = 'false';
}

# Private method which updates the pendingSongFile based on the userid
sub calcDefaultPendingSongFile()
{
    my $self = shift;
    
    if (defined($self->{userid})) {
	# Pending song file lives in temp directory. Something like this:
	# "c:\temp\PendingSongList_userid.txt"
	# or
	# "/tmp/PendingSongList_userid.txt"
	$self->{pendingSongFile} = File::Spec->catfile(File::Spec->tmpdir(),
				"PendingSongList_" . $self->{userid} . ".txt");
    }
}


# Private method which obtains the session's static variables from
# Scrobbler.pm
sub vars
{
    my $vars = Plugins::Scrobbler::sessionVars();
    return $vars;
}

# Private method which logs debug text
sub debug($)
{
    my $line=shift;
    Plugins::Scrobbler::scrobbleMsg("$line\n");
}

sub max
{
    my $a=shift;
    my $b=shift;
    return ($a<$b ? $a : $b);
}

# Packages must return true
1;
