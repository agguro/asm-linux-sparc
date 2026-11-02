# Track.pm
# Copyright (c) 2005 SlimScrobbler Team
# See Scrobbler.pm for full copyright details
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License,
# version 2.

# Track represents information about a track which is currently playing (or
# has recently been played). As well as storing data about the track
# (title/artist etc.) it knows how far through the track has been played.
# Track also knows about the submission policy, i.e. min/max track lengths,
# submission threshold etc.

# Track is really a state machine, as defined by:
#
#               <--- PLAYING ---> READY ---> REGISTERED
#        CANCEL      /|\ \|/
#               <--- PAUSED
#
# PLAYING    - track is currently playing
# PAUSED     - track is currently paused
# READY      - track has reached its play threshold, and can be submitted
# REGISTERED - track has been passed to the Session for submission.
#              It has either been submitted or logged for later submission.
# CANCEL     - track has been stopped before the threshold, or some other
#              condition causes the track never to be submitted.
# The intention is that the slimserver's thread controls movement between
# PLAYING, PAUSED and CANCEL, while a background submitter thread
# moves the track into REGISTERED. Either thread can do the transit to READY.
# Once REGISTERED or CANCEL, the background thread forgets about the track.

use strict;

package Scrobbler::Track;

use Time::Countdown;
use Math::Round;

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
# the initial state of the Track.
#
# Supported arguments are:
#   filename, artist, album, title, musicBrainzId, threshold, session
# Or you can use the setter methods defined below. There are no required
# parameters, although without artist/track audioscrobbler will
# reject any submission. If totalLength is zero or undef, we will start at
# CANCEL rather than PAUSED.

sub new
{
    my($class, %cnf) = @_;

    debug("==Track.new");

    my $filename      = delete $cnf{filename};
    my $artist        = delete $cnf{artist};
    my $album         = delete $cnf{album};
    my $title         = delete $cnf{title};
    my $musicBrainzId = delete $cnf{musicBrainzId};
    my $totalLength   = delete $cnf{totalLength};
    my $session       = delete $cnf{session};

    my $self = bless {
        filename      => $filename,
    	artist        => $artist,
        album         => $album,
        title         => $title,
        musicBrainzId => $musicBrainzId,
        totalLength   => $totalLength,
    }, $class;

    my $vars = vars();

    # Decide whether or not this track will be submitted should it reach
    # the threshold.
    my $submit=1;
    if (defined($totalLength)) {
        debug("Track length is: $totalLength seconds");
	if ($totalLength < $vars->{SCROBBLE_MINIMUM_LENGTH}) {
	    debug("Track is too short to submit");
	    $submit=0;
	}
	if ($totalLength > $vars->{SCROBBLE_MAXIMUM_LENGTH}) {
	    debug("Track is too long to submit");
	    $submit=0;
	}
        # ... other conditions can go here if needbe.
    }
    else {
        debug("No length available, track will not be submitted");
        $submit=0;
    }
    
    if ($submit == 1) {
        my $threshold = $vars->{SCROBBLE_PERCENT_PLAY_THRESHOLD} * $totalLength;
        if ($threshold > $vars->{SCROBBLE_TIME_PLAY_THRESHOLD}) {
            $threshold = $vars->{SCROBBLE_TIME_PLAY_THRESHOLD};
        }
        
        # Set up our countdown timer
        debug("Track will be submitted after $threshold seconds of play");
        $self->{countdown} = Time::Countdown->new();
        $self->{countdown}->reset($threshold);
    
        # Our initial state
        $self->{state} = "PAUSED";
    }
    else {
        $self->{state} = "CANCEL";
    }

    return $self;
}

# Public method: put the track into PLAYING if possible.
sub play()
{
    my $self=shift;
    $self->catchup();
    
    if ($self->{state} eq "PAUSED") {
        my $remaining = $self->{countdown}->getRemainingTime();
        debug("Restarting track countdown: $remaining seconds remaining");

        $self->{state} = "PLAYING";     
        $self->{countdown}->run();
    }
}

# Public method: put the track into PAUSED if possible
sub pause()
{
    my $self=shift;
    $self->catchup();
    
    if ($self->{state} eq "PLAYING") {
        $self->{state} = "PAUSED";
        $self->{countdown}->pause();
        
        my $remaining = $self->{countdown}->getRemainingTime();
        debug("Pausing track countdown: $remaining seconds remaining");
    }
}

# Public method: flip between PLAYING and PAUSED
sub togglePause()
{
    my $self=shift;
    $self->catchup();
    
    if ($self->{state} eq "PAUSED") {
        my $remaining = $self->{countdown}->getRemainingTime();
        debug("Restarting track countdown: $remaining seconds remaining");
        
        $self->{state} = "PLAYING";
        $self->{countdown}->run();
    }
    elsif ($self->{state} eq "PLAYING") {
        $self->{state} = "PAUSED";
        $self->{countdown}->pause();
        
        my $remaining = $self->{countdown}->getRemainingTime();
        debug("Pausing track countdown: $remaining seconds remaining");
    }
}

# Public method: put the track into CANCEL if possible
# Call when the track is stopped, or if some user action invalidates the track
sub cancel()
{
    my $self=shift;
    $self->catchup();
    
    if (($self->{state} eq "PLAYING") || ($self->{state} eq "PAUSED")) {
        my $title=$self->{title};
        debug("Track $title will not be submitted.");
        
        $self->{state} = "CANCEL";
    }
}

# Public method, called when the track info has been passed to the Session to
# be recorded/submitted.
sub markRegistered()
{
    my $self=shift;
    my $state=$self->{state};
    
    # Sanity check - we should only be called while READY. If we're not,
    # change our state anyway as it's probably the intended action.
    if (!($self->{state} eq "READY")) {
        debug("WARNING: INTERNAL ERROR IN SLIMSCROBBLER");
        debug("markRegistered() called while state is $state, not READY");
    }
    
    $self->{state} = "REGISTERED";
}        

# Public method, returns true if we are ready to be submitted.
sub isReady()
{
    my $self=shift;

    $self->catchup();
    return ($self->{state} eq "READY");
}

# Public method, returns true if we are marked registered.
sub isRegistered()
{
    my $self=shift;

    $self->catchup();
    return ($self->{state} eq "REGISTERED");
}

# Public method, returns true if we are cancelled.
sub isCancelled()
{
    my $self=shift;

    $self->catchup();
    return ($self->{state} eq "CANCEL");
}

# Private method which updates the state machine according to the current time.
# Any attempt to update the state machine for some event, when the state machine
# might be PLAYING, should call this method first.
sub catchup
{
    my $self=shift;
    my $title=$self->{title};
    
    if ($self->{state} eq "PLAYING") {
        my $remaining = $self->{countdown}->getRemainingTime();
        if ($remaining eq 0) {
            debug("Track $title has reached its play threshold");
            $self->{state} = "READY";
        }
        else {
          # Too chatty
          # debug("Track $title has not yet reached its play threshold:");
          # debug("$remaining seconds left");
        }
    }
}

# Create a block of text block for a played song,
# to be submitted to the server as part of the "played these song(s)" POST.
# Looks something like this:
#
# a[X]=<artist name>
# b[X]=<album name>
# t[X]=<song title>
# m[X]=<MusicBrainz.Org ID>
# l[X]=<length of song in seconds>
# i[X]=<UTC formatted date-time on the client>
#
# Where X is the submission number

# i.e.
#
# a[0]=Metallica
# b[0]=Ride the Lightning
# t[0]=Fade to Black
# l[0]=237
# i[0]=28/02/2003 12:15:31
# m[0]=
sub makeSongEntryText
{
    # These are the passed parameters
    my $self = shift;
    my $entryNumber = shift;
    my $UTCDate = shift;

    my $artist = $self->{artist};
    my $album = $self->{album};
    my $title = $self->{title};
    my $lengthInSeconds = $self->{totalLength};
    my $musicBrainzId = $self->{musicBrainzId};
    
    if (!defined($artist)) { $artist=""; }
    if (!defined($album)) { $album=""; }
    if (!defined($title)) { $title=""; }
    if (!defined($lengthInSeconds)) { $lengthInSeconds=0; }
    if (!defined($musicBrainzId)) { $musicBrainzId=""; }

    # Round to nearest whole second
    $lengthInSeconds = round($lengthInSeconds);

    my $delim = vars()->{SCROBBLE_SUBMIT_DELIMITER};
    my $songEntryText = "";
    $songEntryText .= "a[" . $entryNumber . "]=" . formatUserDataField($artist) . $delim;
    $songEntryText .= "b[" . $entryNumber . "]=" . formatUserDataField($album) . $delim;
    $songEntryText .= "t[" . $entryNumber . "]=" . formatUserDataField($title) . $delim;
    $songEntryText .= "l[" . $entryNumber . "]=" . formatUserDataField($lengthInSeconds) . $delim;
    $songEntryText .= "i[" . $entryNumber . "]=" . formatUserDataField($UTCDate) . $delim;
    $songEntryText .= "m[" . $entryNumber . "]=" . formatUserDataField($musicBrainzId) . $delim;

    return $songEntryText;
}

# UTF-8 encode, then URL encode.
# Used for any data coming from user's songs.
# Note that this is a regular function, not an object method
# TODO this is duplicated in Session.pm, maybe it should go somewhere central
sub formatUserDataField($)
{
    my $userDataField = shift;

    return URI::Escape::uri_escape_utf8($userDataField);
}


# Debugging routine - shows current variable values
sub showCurrentVariables($)
{
   my $self=shift;

   my $tmpArtist = $self->{artist};
   my $tmpTrack  = $self->{title};
   my $tmpAlbum  = $self->{album};
   debug("Artist: $tmpArtist");
   debug("Track:  $tmpTrack");
   debug("Album:  $tmpAlbum");
   my $tmpOriginalFilename = $self->{filename};
   debug("Original Filename: $tmpOriginalFilename");
   my $tmpDurationInSeconds = $self->{totalLength};
   if ($tmpDurationInSeconds) {
       debug("Duration in seconds: $tmpDurationInSeconds");
   }
   my $mbid = $self->{musicBrainzId};
   if ($mbid) {
       debug("MusicBrainz id: $mbid");
   }

   my $countdown = $self->{countdown};
   if ($countdown) {
       my $currentElapsedTime = $countdown->getElapsedTime();
       my $currentRemainingTime = $countdown->getRemainingTime();
       debug("Time showing on stopwatch: $currentElapsedTime");
       debug("Remaining time: $currentRemainingTime");
   }
   else {
       debug("No Countdown object yet");
   }
   
   my $tmpState = $self->{state};
   debug("Current state of Track object: $tmpState");
}

# Private method which obtains Tracks's static variables from
# Scrobbler.pm
sub vars
{
    my $vars = Plugins::Scrobbler::trackVars();
    return $vars;
}

# Private method which logs debug text
sub debug($)
{
    my $line=shift;
    Plugins::Scrobbler::scrobbleMsg("$line\n");
}

# Packages must return true
1;
