# Scrobbler.pm 
#
# Copyright (c) SlimScrobbler Team:
#
# Stewart Loving-Gibbard (sloving-gibbard@uswest.net) -- Original author
# Mike Scott (slimscrobbler@hindsight.it) -- SlimServer 5.x changes
# Ian Parkinson (iwp@iwparkinson.plus.com) -- Background submission,
#                                             SlimServer 6.x changes,
#                                             multiuser support
#                                             and other tweaks
# Hakan Tandogan (hakan@gurkensalat.com) -- MusicBrainz support
# Eric Gauthier, Dean Blacketter: !$client fix
# Eric Koldinger: Configuration panel
# 
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License,
# version 2.
use strict;
                       
package Plugins::Scrobbler;


# NOTE TO USERS
# You used to have to edit this source file to provide your audioscrobbler
# userid and password. In most cases you should no longer edit this file;
# instead configure the plugin via the Plugins menu on the slimserver
# admin web pages.
# If you use different audioscrobbler accounts for different players,
# you still need to edit the playerAccounts hashtable below; but you must
# still provide a default userid/password on the admin web pages.


# TODO Rationalise the use list. Much work has been offloaded to
# Session.pm and Track.pm, so some of these may no longer be necessary.
use Slim::Player::Playlist;
use Slim::Player::Source;
use Slim::Player::Sync;
use Slim::Utils::Misc;
use Slim::Utils::Timers;
use Slim::Utils::Strings qw (string);
use Slim::Player::Client;
use Slim::Music::Info;
use Time::HiRes;
use MP3::Info;
use Class::Struct;
# For temp directory
use File::Spec;

use FindBin qw($Bin);
use lib(File::Spec->catdir($Bin, 'Plugins','SlimScrobbleSupport'));

use Math::Round;
use LWP::UserAgent;
# For min/max
use List::Util;

use Scrobbler::Session;
use Scrobbler::Track;

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

# Requires Perl 5.8.0 or greater. Needed for UTF-8 encoding.
#use Encode;


#################################################
### Global constants - do not change casually ###
#################################################

# There are multiple different conditions which
# influence whether a track is considered played:
#
#  - A minimum number of seconds a track must be 
#    played to be considered a play. Note that
#    if set too high it can prevent a track from
#    ever being noted as played - it is effectively
#    a minimum track length. Overrides other conditions!
#
#  - A percentage play threshold. For example, if 50% 
#    of a track is played, it will be considered played.
#
#  - A time played threshold. After this number of
#    seconds playing, the track will be considered played.


# Identity of this plug-in
my $SCROBBLE_PLUGIN_NAME = "SlimScrobbler";
my $SCROBBLE_PLUGIN_VERSION = "0.34";

my $trackVars = {
    # After this much of a track is played, mark as played.
    SCROBBLE_PERCENT_PLAY_THRESHOLD => .50,

    # After this number of seconds of a track is played, mark as played.
    SCROBBLE_TIME_PLAY_THRESHOLD => 240,

    # The minimum length (in seconds) of tracks allowed by AudioScrobbler
    SCROBBLE_MINIMUM_LENGTH => 30,

    # The maximum length (in seconds) of tracks allowed by AudioScrobbler
    # (30 minutes)
    SCROBBLE_MAXIMUM_LENGTH => 1800,

    # String/character to separate fields on submission
    # TODO this is defined here and in sessionVars; fix it.
    SCROBBLE_SUBMIT_DELIMITER => "&",
};

my $sessionVars = {
# After a submission error, the number of seconds before retrying,
# as used by the non-background submitter
    SCROBBLE_RETRY_DELAY => 1800,

# After a submission error, minimum and maximum number of seconds before
# retrying, as used by the background submitter
# After the first failure, it retries after MIN_DELAY, and doubles
# each time, maxing out at MAX_DELAY.
    SCROBBLE_RETRY_MIN_DELAY => 60,
    SCROBBLE_RETRY_MAX_DELAY => 7200,


# Length of time, in seconds, to wait for a response from AudioScrobbler
# (ignored by the background submitter)
    SCROBBLE_COMMS_TIMEOUT => 10,

# Length of time, in seconds, to wait for certain network operations
# Should be short enough to not cause pauses in playback
    SCROBBLE_NB_COMMS_TIMEOUT => 5,

# Identity of this plug-in
    SCROBBLE_PLUGIN_NAME => $SCROBBLE_PLUGIN_NAME,
    SCROBBLE_PLUGIN_VERSION => $SCROBBLE_PLUGIN_VERSION,

# Base URL to the AudioScrobbler server
    SCROBBLE_SERVER => "post.audioscrobbler.com/",
# URL for testing
#   SCROBBLE_SERVER => "audioscrobbler.sourceforge.net/submissiontest.php",

# User/password for testing with above test URL
#my $TEST_USER = "test";
#my $TEST_PASSWORD = "testpass";

# Client ID for our plugin                                       
    SCROBBLE_CLIENT_ID => "slm",

# String/character to separate fields on submission
    SCROBBLE_SUBMIT_DELIMITER => "&",
};

# Indicator if scrobbler is hooked or not
# 0= No
# 1= Yes
my $SCROBBLE_HOOK = 0;

# Whether we should, by default, use the background submitter.
# Owners of older (SliMP3) players may want to disable this, as it
# can cause occasional breaks while playing music. However, when disabled,
# you'll see occasional lengthy breaks between tracks and (probably) more
# spam warnings from AudioScrobbler. If you do want to disable this, set
# scrobbler-background-submit = 0 in the slimserver.conf file.
my $SCROBBLE_BACKGROUND_DEFAULT = 1;

# Export the version to the server
use vars qw($VERSION);
$VERSION = $SCROBBLE_PLUGIN_VERSION;


##################################################
### SlimServer Plugin API                      ###
##################################################

# This section needs a lot of help. At the time
# that I wrote this, I had no SlimDevices hardware,
# and so couldn't test it.

# Current menu state for the clients
my %mainModeSelection;
my %userModeSelection;

sub getDisplayName() 
{
# Slim changed this at slimserver v6. Seems an odd thing to change
# to me, given that it must break every plugin out there, and makes it
# impossible to write plugins that support both pre- and post-v6 servers.
#   return string('PLUGIN_SCROBBLER')
    return "PLUGIN_SCROBBLER";
}

sub strings
{
    local $/ = undef;
    <DATA>;
}



sub setMode() 
{
	my $client = shift;

	unless (defined($mainModeSelection{$client})) {
	    $mainModeSelection{$client} = 0;
	}

	$client->lines(\&mainModeLines);
}


sub enabled() 
{
	my $client = shift;
	return 1;
}

sub initPlugin()
{
    # do _debug first, so that anything that traces will work
    initSetting("plugin_scrobbler_debug", 0);
    initSetting("plugin_scrobbler_auto_submit", 1);
    initSetting("plugin_scrobbler_background_submit", $SCROBBLE_BACKGROUND_DEFAULT);
    initSetting("plugin_scrobbler_max_pending", 1);
    initSetting("plugin_scrobbler_user", "");
    initSetting("plugin_scrobbler_password", "");

    # settings for multi-account support
    initSetting("plugin_scrobbler_multiuser", 0);
    initSetting("plugin_scrobbler_useridlist", "");
    initSetting("plugin_scrobbler_default_userid", "");


    # Add the player mode for account selection (multi-user support)
    Slim::Buttons::Common::addMode('plugins_scrobbler_users',
				   userModeGetFunctions(), \&setUserMode);

    hookScrobbler();
}

sub shutdownPlugin()
{
    unHookScrobbler();
}


# The Plugin's main Mode

my %functions = (
	'up' => sub  {
	    my $client = shift;
	    my @choices = getMainModeChoices();
	    my $newposition = Slim::Buttons::Common::scroll($client, -1, scalar(@choices), $mainModeSelection{$client});
	    
	    if ($newposition != $mainModeSelection{$client}) {
		$mainModeSelection{$client} = $newposition;
		$client->pushUp();
	    }

	},
	'down' => sub  {
            my $client = shift;
            my @choices = getMainModeChoices();
            my $newposition = Slim::Buttons::Common::scroll($client, +1, scalar(@choices), $mainModeSelection{$client});

            if ($newposition != $mainModeSelection{$client}) {
                $mainModeSelection{$client} = $newposition;
                $client->pushDown();
            }
	},
	'left' => sub  {
	    my $client = shift;
	    Slim::Buttons::Common::popModeRight($client);
	},
	'right' => sub  {
	    my $client = shift;
	    my @choices = getMainModeChoices();
	    my $rightSub = $choices[$mainModeSelection{$client}][1];
	    if ($rightSub) { &$rightSub($client); }

	},
	'play' => sub {
	    my $client = shift;
	    my @choices = getMainModeChoices();
	    my $playSub = $choices[$mainModeSelection{$client}][2];
	    if ($playSub) { &$playSub($client); }
	}
);



# Gives the options available on the main mode menu.
# If SlimScrobbler is not configured, there is just a warning
# Otherwise, the menu includes current enabled state of slimscrobbler
# Returned is a two-dimensional array, one top-level entry for each
# option. The entry for each option contains the string to display,
# the action to take when right is pressed, and the action to take when
# play is pressed.
sub getMainModeChoices()
{
    if (!isConfigValid()) {
	return ( [ 'PLUGIN_SCROBBLER_BAD_CONFIG', undef, undef] );
    }
    else {
	my @choices = ( [ 'PLUGIN_SCROBBLER_HIT_PLAY_TO_SUBMIT', undef, \&mainModeSubmitNow ] );

	# If multi-user, option to change the account in use
	if (Slim::Utils::Prefs::get("plugin_scrobbler_multiuser")) {
	    my $c = [ 'PLUGIN_SCROBBLER_SELECT_ACCOUNT', \&mainModeToUserMode, undef ];
	    push @choices, $c;
	}

	# Option to enable/disable the entire plugin
	if ($SCROBBLE_HOOK == 0) {
	    my $c = [ 'PLUGIN_SCROBBLER_DISABLED', \&mainModeEnableScrobbler, undef ];
	    push @choices, $c;
	}
	else {
	    my $c = [ 'PLUGIN_SCROBBLER_ENABLED', \&mainModeDisableScrobbler, undef ];
	    push @choices, $c;
	}

	return @choices;
    }
}

sub mainModeEnableScrobbler()
{
    my $client=shift;

    my $line = string('PLUGIN_SCROBBLER_ACTIVATED');
    Plugins::Scrobbler::hookScrobbler();
    Slim::Display::Animation::showBriefly($client, $line, undef);
}

sub mainModeDisableScrobbler()
{
    my $client=shift;

    my $line = string('PLUGIN_SCROBBLER_DEACTIVATED');
    Plugins::Scrobbler::unHookScrobbler();
    Slim::Display::Animation::showBriefly($client, $line, undef);
}

# TODO display helpful text if client has no session/userid
# Better yet, don't display the 'submit now' option
sub mainModeSubmitNow()
{
    my $client = shift;
    my $session = getSessionForClient($client);
    if ($session) {
	my $line = string('PLUGIN_SCROBBLER_SUBMITTING');
	Slim::Display::Animation::showBriefly($client, $line, undef);
	$session->attemptToSubmitToAudioScrobbler();
    }
}

sub mainModeToUserMode()
{
    my $client = shift;
    initUserMode($client);
    Slim::Buttons::Common::pushModeLeft($client, "plugins_scrobbler_users");
}


sub mainModeLines() 
{
    my $client=shift;
    my @choices=getMainModeChoices();

    # Do a patch-up here. If the client is beyond the end of the menu
    # (the menu might change), reset it
    if ($mainModeSelection{$client} >= scalar(@choices)) {
	$mainModeSelection{$client} = 0;
    }

    my $line1=string('PLUGIN_SCROBBLER');
    if (scalar(@choices) > 1) {
	$line1 = $line1 . " (" . ($mainModeSelection{$client}+1)
                               . " " . string("PLUGIN_SCROBBLER_OF") . " "
			       . (scalar(@choices))
			       . ")";
    }

    my $line2 = string($choices[$mainModeSelection{$client}][0]);

    my $br=undef;
    my $rightFunc = $choices[$mainModeSelection{$client}][1];
    if ($rightFunc) { $br = Slim::Display::Display::symbol('rightarrow'); }

    return ($line1, $line2, undef, $br);
}


###
# The users list mode

sub initUserMode()
{
    my $client = shift;

    # Calculate the index of the currently selected userid for this client
    # First, get the currently selected userid
    # TODO this is very similar to some code below, can it be refactored?
    my $userid = Slim::Utils::Prefs::clientGet($client, "plugin_scrobbler_userid");
    my %ups=getAllUserIDPasswords();
    my @userids = sort keys %ups;

    my $index = 0;
    if (defined($userid)) {
	# We have a userid - check it hasn't been deleted and locate its index
	for (my $i=0; $i<@userids; $i++) {
	    if ($userids[$i] eq $userid) {
		# We do the +1 because the displayed list will have
		# a "Use default userid" at position 0 - also we rely on
		# $i == 0 if not found in the test below
		$index= $i + 1;
	    }
	}

	if ($index == 0) {
	    Plugins::Scrobbler::scrobbleMsg("Configured userid $userid not found - removing setting\n");
	    Slim::Utils::Prefs::clientDelete($client, "plugin_scrobbler_userid");
	    $userid=undef;
        }
    }
    
    $userModeSelection{$client} = $index;
}

my %userModeFunctions = (
     'up' => sub {
	 my %ups = getAllUserIDPasswords();
	 my @userList = sort keys %ups;
	 my $client = shift;
	 my $newposition = Slim::Buttons::Common::scroll($client, -1, ($#userList + 2), $userModeSelection{$client});

	 if ($newposition != $userModeSelection{$client}) {
	     $userModeSelection{$client} = $newposition;
	     $client->pushUp();
	     changeClientsSelectedUserId($client, \@userList, $newposition);
	 }
     },

     'down' => sub {
	 my %ups = getAllUserIDPasswords();
	 my @userList = sort keys %ups;
	 my $client = shift;
	 my $newposition = Slim::Buttons::Common::scroll($client, +1, ($#userList + 2), $userModeSelection{$client});

	 if ($newposition != $userModeSelection{$client}) {
	     $userModeSelection{$client} = $newposition;
	     $client->pushDown();
             changeClientsSelectedUserId($client, \@userList, $newposition);
	 }
     },

     'left' => sub {
	 my $client = shift;
	 Slim::Buttons::Common::popModeRight($client);
     },

     'right' => sub {
	 my $client = shift;
	 $client->bumpRight();
     }
);

# Helper function, used by userModeFunctions
sub changeClientsSelectedUserId
{
    my $client = shift;
    my $userListR = shift;
    my $chosen = shift;

    my @userList = @$userListR;
    if ($chosen == 0) {
	# Become server default - delete the property
	Plugins::Scrobbler::scrobbleMsg("Client will now use server default account\n");
	Slim::Utils::Prefs::clientDelete($client, "plugin_scrobbler_userid");
    }
    else {
	my $newuser=$userList[$chosen-1];
	Plugins::Scrobbler::scrobbleMsg("Client will now use account $newuser\n");
	Slim::Utils::Prefs::clientSet($client, "plugin_scrobbler_userid", $newuser);
    }
}

sub userModeGetFunctions()
{
    return \%userModeFunctions;
}

sub userModeLines
{
    my $client = shift;

    my %ups = getAllUserIDPasswords();
    my @userList = sort keys %ups;
    my $line1 = string('PLUGIN_SCROBBLER_SELECT_ACCOUNT');
    $line1 = $line1 . " (" . ($userModeSelection{$client}+1)
	                   . " " . string('PLUGIN_SCROBBLER_OF') . " "
                           . ($#userList+2)
                           . ")";
    my $line2;
    if ($userModeSelection{$client} == 0) {
	$line2 = string('PLUGIN_SCROBBLER_USE_DEFAULT_ACCOUNT');
    }
    else { $line2 = @userList[$userModeSelection{$client}-1] || ''; }

    return ($line1, $line2);
}

sub setUserMode
{
    my $client = shift;
    $client->lines(\&userModeLines);
}


##################################################
### Scrobbler per-client Data                  ###
##################################################


# Each client's playStatus structure. 
# Start's empty; as new players appear we add them using getPlayerStatusForClient().
my %playerStatusHash = ();

# Each user's Session object.
# As with playerStatusHash, starts empty. Sessions are added as we need them,
# indexed by userid
my %sessionHash = ();


# The master structure, one per Slim client. Matches the client to the
# currently playing track
# (This is now of very little use, but we keep it around just in case
# we ever have any more per-client state to track)
struct PlayTrackStatus => {

   # Client Name & ID 
   # Used for debugging at the moment
   clientName => '$',
   clientID => '$',

   # The track currently playing. May be undef.
   currentTrack => 'Scrobbler::Track',

   # Is this player on or off? 
   # (HEY SlimDevices staff: The "power" commandCallbck DOES NOT return "on" or "off", so I must
   #  track this myself! Very error-prone, and redundant.)
   isOn => '$',
};


# Get the appropriate user ID & password for the given
# client. Returns (undef, undef) if no userid available
sub getUserIDPasswordForClient($)
{
    my $client = shift;

    my $manyUsers = Slim::Utils::Prefs::get("plugin_scrobbler_multiuser");
    if ($manyUsers) {
	# We are supporting many Audioscrobbler accounts.
	my $userid = Slim::Utils::Prefs::clientGet($client, "plugin_scrobbler_userid");

	if (defined($userid)) {
	    # We have a userid - check it hasn't been deleted
	    my %ups=getAllUserIDPasswords();
	    my @userids = keys %ups;
	    my $found = 0;
	    foreach my $u (@userids) {
		if ($u eq $userid) {$found = 1;}
	    }

	    if (!$found) {
		Plugins::Scrobbler::scrobbleMsg("Configured userid $userid not found - removing setting\n");
		Slim::Utils::Prefs::clientDelete($client, "plugin_scrobbler_userid");
		$userid=undef;
	    }
	}	    

	if (!defined($userid)) {
	    # Use the default userid
	    Plugins::Scrobbler::scrobbleMsg("Using default userid\n");
	    $userid = Slim::Utils::Prefs::get("plugin_scrobbler_default_userid");
	}

	my $password;
	if ($userid) {
	    $password = Slim::Utils::Prefs::get("plugin_scrobbler_user_${userid}_pw");
	}
	else {
	    Plugins::Scrobbler::scrobbleMsg("No userid available\n");
	    return (undef, undef);
	}

	return ($userid, $password);
    }
    else {
	# We have only one userid
	my $userid = Slim::Utils::Prefs::get("plugin_scrobbler_user");
	my $password = Slim::Utils::Prefs::get("plugin_scrobbler_password");

	return ($userid, $password);
    }
}

# Returns a hash of all configured userID/password pairs. Hash has
# userid as the keys, password as the values.
sub getAllUserIDPasswords()
{
    my $manyUsers = Slim::Utils::Prefs::get("plugin_scrobbler_multiuser");
    if ($manyUsers) {
	cleanUpPasswords();

	my $prop = Slim::Utils::Prefs::get("plugin_scrobbler_useridlist");
	my @userids;
	if ($prop) {
	    @userids = split /,/, $prop;
	}
	else {
	    @userids = ();
	}

	my %out = ();
	foreach my $user (@userids) {
	    # Get the password
	    my $password = Slim::Utils::Prefs::get("plugin_scrobbler_user_${user}_pw");
	    $out{$user} = $password;
	}

	return %out;
    }
    else {
	my $user = Slim::Utils::Prefs::get("plugin_scrobbler_user");
	my $pass = Slim::Utils::Prefs::get("plugin_scrobbler_password");
	my %out = ();
	if ($user) {
	    $out{$user} = $pass;
	}
	return %out;
    }
}
	

# Obtain a Session given a userid and password; re-use an existing
# one if possible. Updates the password on the Session, this should
# only happen after a config change. As a side-effect, registers any
# new Session with the background submitter
sub getSessionForUserIDPassword($$)
{
    my $userID = shift;
    my $password = shift;

    my $sess=$sessionHash{$userID};
    if (!defined($sess))
    {
	Plugins::Scrobbler::scrobbleMsg("Creating new Session for $userID\n");

	# Create the session
	$sess=Scrobbler::Session->new();
	$sess->userid($userID);
	$sess->password($password);

	$sessionHash{$userID} = $sess;
	addSessionToSubmitter($sess);
    }
    else
    {
      Plugins::Scrobbler::scrobbleMsg("Found existing Session for $userID\n");
      $sess->password($password);
    }

    return $sess;
}


# Set the appropriate default values for this playerStatus struct
sub setPlayerStatusDefaults($$$$)
{
   # Parameter - client
   my $client = shift;

   # Parameter - Player status structure.
   # Uses pass-by-reference
   my $playerStatusToSetRef = shift;

   # Parameters -- Client name & ID
   my $clientName = shift;
   my $clientID = shift;

   # Set client name & ID (used for debugging at the moment)
   $playerStatusToSetRef->clientName($clientName);
   $playerStatusToSetRef->clientID($clientID);

   # Are we on? (If we've heard about the player, it is on..)
   $playerStatusToSetRef->isOn('true');
}

# Obtain a Session for this client; either re-use an existing one
# (indexed by userid) or create a new one.
# If we are using an existing Session, update the password as
# specified for this player - this will be triggered by a
# configuration change
sub getSessionForClient($)
{
    my $client = shift;

    # Extract userId and password for the client
    my ($userID, $password) = getUserIDPasswordForClient($client);

    if (!($userID)) {
	Plugins::Scrobbler::scrobbleMsg("No userid found for client\n");
	return undef;
    }
    else {
	Plugins::Scrobbler::scrobbleMsg("User ID: $userID\n");
	return getSessionForUserIDPassword($userID, $password);
    }
}

# Get the player state for the given client.
# Will create one for new clients.
sub getPlayerStatusForClient($)
{
   # Parameter - Client structure
   my $client = shift;

   # Get the friendly name for this client
   my $clientName = Slim::Player::Client::name($client);
   # Get the ID (IP) for this client
   my $clientID = Slim::Player::Client::id($client);

   # These messages get pretty tedious when debugging, even for a chatty client.
   #Plugins::Scrobbler::scrobbleMsg("Asking about client $clientName ($clientID)\n");

   # If we haven't seen this client before, create a new per-client 
   # playState structure.
   if (!defined($playerStatusHash{$client}))
   {
      Plugins::Scrobbler::scrobbleMsg("Creating new PlayerStatus for $clientName ($clientID)\n");
      
      # Create new playState structure
      $playerStatusHash{$client} = PlayTrackStatus->new();

      # Set appropriate defaults
      setPlayerStatusDefaults($client, $playerStatusHash{$client}, $clientName, $clientID);
   }
   else
   {
      # These messages get pretty tedious when debugging, even for a chatty client.
      #Plugins::Scrobbler::scrobbleMsg("Already knew about $clientName ($clientID)\n");
   }

   # If it didn't exist, it does now - 
   # return the playerStatus structure for the client.
   return $playerStatusHash{$client};
}


################################################
### AudioScrobbler main routines             ###
################################################


# A wrapper to allow us to uniformly turn on & off Scrobbler debug messages
sub scrobbleMsg($)
{
   # Parameter - Message to be displayed
   my $scrobbleMessage = shift;

   if ($::d_plugins || (Slim::Utils::Prefs::get("plugin_scrobbler_debug") eq 1))
   {
      msg($scrobbleMessage);      
   }
}


# Check whether the userid/password has been set, if we're in single-user
# mode.
# TODO now of minimal use, consider removing. A per-client version would
# be more useful
sub isConfigValid()
{
    my $muser = Slim::Utils::Prefs::get("plugin_scrobbler_multiuser");
    my $userid = Slim::Utils::Prefs::get("plugin_scrobbler_user");
    my $password = Slim::Utils::Prefs::get("plugin_scrobbler_password");

    if ($muser) { return 1; }
    if (!defined($userid) || ($userid eq "")) { return 0; }
    if (!defined($password) || ($password eq "")) { return 0; }
    
    return 1;
}


# Hook the scrobbler to the play events.
# Do this as soon as possible during startup.
# Only call this if config is valid.
sub hookScrobbler()
{  
    if ($SCROBBLE_HOOK == 0) {
	Plugins::Scrobbler::scrobbleMsg("hookScrobbler() engaged, SlimScrobbler V$SCROBBLE_PLUGIN_VERSION activated.\n");
	Slim::Control::Command::setExecuteCallback(\&Plugins::Scrobbler::commandCallback);
	$SCROBBLE_HOOK=1;

	if (useBackgroundSubmitter()) {
	    setSubmitterTimer();

	    # initialise a Session for all known userids, so that we can
	    # submit old data immediately upon startup
	    my %uhash = getAllUserIDPasswords();
	    my $userid;
	    my $password;
	    while (($userid, $password) = each %uhash) {
		getSessionForUserIDPassword($userid, $password);
	    }
	}
    }
    else {
	Plugins::Scrobbler::scrobbleMsg("SlimScrobbler already active, ignoring hookScrobbler() call");
    }
}


# Unhook the Scrobbler's play event callback function. 
# Do this as the plugin shuts down, if possible.
sub unHookScrobbler()
{
   if ($SCROBBLE_HOOK == 1) {
       if (useBackgroundSubmitter()) {
	   cancelSubmitterTimer();
       }

       # Note that CLI just has this as "...(\&commandCallback)";
       # I'm not sure if what I've done is correct.
       Plugins::Scrobbler::scrobbleMsg("unHookScrobbler() engaged, SlimScrobbler V$SCROBBLE_PLUGIN_VERSION deactivated.\n");
       Slim::Control::Command::clearExecuteCallback(\&Plugins::Scrobbler::commandCallback);
       $SCROBBLE_HOOK=0;
   }
   else {
       Plugins::Scrobbler::scrobbleMsg("SlimScrobbler not active, ignoring unHookScrobbler() call\n");
   }
}


# These xxxCommand() routines handle commands coming to us
# through the command callback we have hooked into.

sub openCommand($$)
{
   ######################################
   ### Open command
   ######################################

   # This is the chief way we detect a new song being played, NOT the play command.

   # Parameter - current client
   my $client = shift;

   # Parameter - filename of track being played
   my $filename = shift;

   # Get name & ID of this player
   my $playStatus = getPlayerStatusForClient($client);
   my $clientName = $playStatus->clientName();
   my $clientID =   $playStatus->clientID();

   Plugins::Scrobbler::scrobbleMsg("*----------------------------\n");
   Plugins::Scrobbler::scrobbleMsg("Open command [$clientName ($clientID)]\n");
   Plugins::Scrobbler::scrobbleMsg("*----------------------------\n");

   # Stop old song, if needed
   if (defined($playStatus->currentTrack()))
   {
      stopTimingSong($client, $playStatus);
   }

   # Get new song data
   my $totalLength;
   my $artistName;
   my $trackTitle;
   my $albumName;
   my $musicbrainz_id;
   my $ds = Slim::Music::Info::getCurrentDataStore();
   if ($ds) {
       my $trackObj = $ds->objectForUrl($filename);
       if ($trackObj) {
	   $totalLength = $trackObj->durationSeconds();
	   $trackTitle  = $trackObj->title();

	   my $artist = $trackObj->artist();
	   if ($artist) { $artistName = $artist->name(); }

	   my $album = $trackObj->album();
	   if ($album) { $albumName = $album->title(); }

	   $musicbrainz_id = $trackObj->{musicbrainz_id};
       }
   }

# Preserved for posterity, just in case anybody tries to run against
# a pre-V6 slimserver. If that is you, uncomment these lines and
# comment out the last block of code.
#   my $totalLength = Slim::Music::Info::durationSeconds($filename);
#   my $artistName = Slim::Music::Info::artist($filename);
#   my $trackTitle = Slim::Music::Info::title($filename);
#   my $albumName  = Slim::Music::Info::album($filename);

   # Start timing new song
   startTimingNewSong($client, $playStatus, $filename, $artistName,
                               $trackTitle, $albumName, $totalLength,
		               $musicbrainz_id);

   showCurrentVariables($playStatus);
}


sub playCommand($)
{
   ######################################
   ### Play command
   ######################################

   # Parameter - current client
   my $client = shift;

   # Get name & ID of this player
   my $playStatus = getPlayerStatusForClient($client);
   my $clientName = $playStatus->clientName();
   my $clientID =   $playStatus->clientID();

   Plugins::Scrobbler::scrobbleMsg("*----------------------------\n");
   Plugins::Scrobbler::scrobbleMsg("Play command [$clientName ($clientID)]\n");
   Plugins::Scrobbler::scrobbleMsg("*----------------------------\n");

   my $track = $playStatus->currentTrack();
   if (defined($track)) {
     $track->play();
   }

   # If we just got a play command, but we think the player is off, we need to toggle the
   # player status back to "on" again. (We don't get a 'power' command when someone just hits
   # the play button from a power-off state. Sigh.)
   # We used to lose the currently-playing track if someone did this, but I don't think we do
   # any more.
   if ($playStatus->isOn() eq "false")
   {
      Plugins::Scrobbler::scrobbleMsg("Looks like someone forgot to tell us power was back on for $clientName ($clientID)]...\n");
      # Plugins::Scrobbler::scrobbleMsg("NOTE: Right now we lose track of the current track's play in this circumstance, sorry! ($clientID)]\n");

      $playStatus->isOn("true");
   }
   
   showCurrentVariables($playStatus);
}

sub pauseCommand($$)
{
   ######################################
   ### Pause command
   ######################################

   # Parameter - current client
   my $client = shift;

   # Get name & ID of this player
   my $playStatus = getPlayerStatusForClient($client);
   my $clientName = $playStatus->clientName();
   my $clientID =   $playStatus->clientID();

   # Parameter - Optional second parameter in command
   # (This is for the case <pause 0 | 1> ). 
   # If user said "pause 0" or "pause 1", this will be 0 or 1. Otherwise, undef.
	my $secondParm = shift;

   Plugins::Scrobbler::scrobbleMsg("*----------------------------\n");
   Plugins::Scrobbler::scrobbleMsg("Pause command [$clientName ($clientID)]\n");
   Plugins::Scrobbler::scrobbleMsg("*----------------------------\n");

   my $track=$playStatus->currentTrack();
   if (defined($track)) {
      # Just a plain "pause"
      if (!defined($secondParm))
      {
         Plugins::Scrobbler::scrobbleMsg("Vanilla Pause\n");
         $track->togglePause();
      }

      # "pause 1" means "pause true", so pause and stop timing, if not already paused.
      elsif ( ($secondParm eq 1) )
      {
         Plugins::Scrobbler::scrobbleMsg("Pausing (1 case)\n");
         $track->pause();      
      }

      # "pause 0" means "pause false", so unpause and resume timing, if not already timing.
      elsif ( ($secondParm eq 0) )
      {
         Plugins::Scrobbler::scrobbleMsg("Pausing (0 case)\n");
         $track->play();      
      }
   
      else
      {      
         Plugins::Scrobbler::scrobbleMsg("Pause command ignored, assumed redundant.\n");
      }
   }

    showCurrentVariables($playStatus);
}


sub stopCommand($)
{
   ######################################
   ### Stop command
   ######################################

   # Parameter - current client
   my $client = shift;

   # Get name & ID of this player
   my $playStatus = getPlayerStatusForClient($client);
   my $clientName = $playStatus->clientName();
   my $clientID =   $playStatus->clientID();

   Plugins::Scrobbler::scrobbleMsg("*----------------------------\n");
   Plugins::Scrobbler::scrobbleMsg("Stop command [$clientName ($clientID)]\n");
   Plugins::Scrobbler::scrobbleMsg("*----------------------------\n");

   if (defined($playStatus->currentTrack()))
   {
      stopTimingSong($client, $playStatus);
   }

   showCurrentVariables($playStatus);
}

sub powerOnCommand ($)
{
   ######################################
   ## Power on command
   ######################################

   # Parameter - current client
   my $client = shift;

   # Get name & ID of this player
   my $playStatus = getPlayerStatusForClient($client);
   my $clientName = $playStatus->clientName();
   my $clientID =   $playStatus->clientID();

   Plugins::Scrobbler::scrobbleMsg("*----------------------------\n");
   Plugins::Scrobbler::scrobbleMsg("Power on command [$clientName ($clientID)]\n");
   Plugins::Scrobbler::scrobbleMsg("*----------------------------\n");

   # Set our on/off flag
   $playStatus->isOn('true');
   
   # I think I've seen times when the power state tracking has got confused,
   # so I'm going to pause any playing song here. The end result will be correct
   # whether we've just turned power off or on; either way, the track is paused.
   my $track=$playStatus->currentTrack();
   if (defined($track)) {
      $track->pause();
   }
   
   showCurrentVariables($playStatus);
}

# We used to treat power-off as a hard stop, but I always find tracks resume
# where they left off after power-on. So we now treat power-off as a pause.
sub powerOffCommand($)
{
   ######################################
   ## Power off command
   ######################################

   # Parameter - current client
   my $client = shift;

   # Get name & ID of this player
   my $playStatus = getPlayerStatusForClient($client);
   my $clientName = $playStatus->clientName();
   my $clientID =   $playStatus->clientID();

   Plugins::Scrobbler::scrobbleMsg("*----------------------------\n");
   Plugins::Scrobbler::scrobbleMsg("Power off command [$clientName ($clientID)]\n");
   Plugins::Scrobbler::scrobbleMsg("*----------------------------\n");

   my $track=$playStatus->currentTrack();
   if (defined($track)) {
      $track->pause();
   }

   # Set our on/off flag
   $playStatus->isOn('false');

    showCurrentVariables($playStatus);
}



# This gets called during playback events.
# We look for events we are interested in, and start and stop our various
# timers accordingly.

sub commandCallback($) 
{
   # These are the two passed parameters
   my $client = shift;
   my $paramsRef = shift;

   # Some commands have no client associated with them, so we ignore them.
   return if (!$client); 

   # I had hoped that this would be accurate enough
   # to use in the place of all this ugly state tracking, but
   # sometimes it says "stop" when the *next* command
   # is about to put it into play mode. 

   # In the end, you need to watch commands anyhow, just
   # a different set of them. So, sticking with original
   # implementation.

   #my $playMode = Slim::Player::Source::playmode($client);
   #Plugins::Scrobbler::scrobbleMsg("[****} Playmode according to Slim Code: $playMode\n");

#   Plugins::Scrobbler::scrobbleMsg("====New commands:\n");
#   foreach my $param (@$paramsRef)
#   {
#      Plugins::Scrobbler::scrobbleMsg("  command: $param\n");
#   }

   # showCurrentVariables($playStatus);

   my $slimCommand = @$paramsRef[0];
   my $paramOne = @$paramsRef[1];

   ######################################
   ### Open command
   ######################################

   # This is the chief way we detect a new song being played, NOT play.

   if ($slimCommand eq "open") 
   {
      my $trackOriginalFilename = $paramOne;

      openCommand($client, $trackOriginalFilename);
   }

   ######################################
   ### Play command
   ######################################

   if( ($slimCommand eq "play") ||
       (($slimCommand eq "mode") && ($paramOne eq "play")) )
   {
      playCommand($client);
   }

   ######################################
   ### Pause command
   ######################################

   if ($slimCommand eq "pause")
   {
      # This second parameter may not exist,
      # and so this may be undef. Routine expects this possibility,
      # so all should be well.
      pauseCommand($client, $paramOne);
   }

   if (($slimCommand eq "mode") && ($paramOne eq "pause"))
   {  
      # "mode pause" will always put us into pause mode, so fake a "pause 1".
      pauseCommand($client, 1);
   }

   ######################################
   ### Sleep command
   ######################################

   if ($slimCommand eq "sleep")
   {
      # Sleep has no effect on streamed players; is this correct for SlimDevices units?
      # I can't test it.

      #Plugins::Scrobbler::scrobbleMsg("===> Sleep activated! Be sure this works!\n");

      #pauseCommand($playStatus, undef());
   }

   ######################################
   ### Stop command
   ######################################

   if ( ($slimCommand eq "stop") ||
        (($slimCommand eq "mode") && ($paramOne eq "stop")) )
   {
      stopCommand($client);
   }

   ######################################
   ### Stop command
   ######################################

   if ( ($slimCommand eq "playlist") && ($paramOne eq "sync") )
   {
      # If this player syncs with another, we treat it as a stop,
      # since whatever it is presently playing (if anything) will end.
      stopCommand($client);
   }


   ######################################
   ## Power command
   ######################################

   # If we received a potential "on"/"off" parameter..
   if ($paramOne) 
   {
      # Power off
      if ( (($slimCommand eq "power") && ($paramOne eq "off")) ||
           (($slimCommand eq "mode") && ($paramOne eq "off")) )
      {
         #Plugins::Scrobbler::scrobbleMsg("===> Power On with explicit \"Off\" parameter\n");
         powerOffCommand($client);
      }
      # Power on
      elsif ( (($slimCommand eq "power") && ($paramOne eq "on")) ||
           (($slimCommand eq "mode") && ($paramOne eq "on")) )
      {
         #Plugins::Scrobbler::scrobbleMsg("===> Power Off with explicit \"On\" parameter\n");
         powerOnCommand($client);
      }
   }
   # Unfortunately, the second parameter is optional, and we often don't get it.
   else
   {
      # TODO this is a little ugly - we get PlayerStatus both here and in
      # the powerO[n|ff]Command() function.
      my $playStatus = getPlayerStatusForClient($client);

      # Power off
      if ( ($slimCommand eq "power") && ($playStatus->isOn() eq "true") ) 
      {
         #Plugins::Scrobbler::scrobbleMsg("===> Power Off, since playStatus appears to be On.\n");
         powerOffCommand($client);
      }
      # Power on
      elsif ( ($slimCommand eq "power") && ($playStatus->isOn() eq "false") ) 
      {
         #Plugins::Scrobbler::scrobbleMsg("===> Power On, since playStatus appears to be Off.\n");
         powerOnCommand($client);
      }
   }

}


# Create a UTC time string for now
sub getUTCTimeRightNow()
{

#   Using an abbreviated UTC Time format:
#
#   YYYY-MM-DD hh:mm:ss

   my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday);
   
   # Get the time variables
   ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday) = gmtime(time);  
   
   # Adjust for human-readable output 
   $mday = sprintf("%02u", $mday);
   # months numbered from 0;
   $mon += 1;
   $mon = sprintf("%02u", $mon);
   # Year is number of years since 1900; adjust
   $year += 1900;
   # Time
   $hour = sprintf("%02u", $hour);
   $min = sprintf("%02u", $min);
   $sec = sprintf("%02u", $sec);

   # Build the UTC string
   # Year first
   my $UTCString = $year . "-" . $mon . "-" . $mday;
   # Space
   $UTCString .= " ";
   # Time second
   $UTCString .= $hour . ":" . $min . ":" . $sec; 

   # Return the time we built
   return($UTCString);
}


# A new song has begun playing. Reset the current song
# timer and set new Artist and Track.
sub startTimingNewSong($$$$$$$$)
{
   # Parameter - the client
   my $client = shift;
   # Parameter - PlayTrackStatus for current client
   my $playStatus = shift;

   # Parameters: Artist name & Track title
   my $filename = shift;
   my $artistName = shift;
   my $trackTitle = shift;
   my $albumName  = shift;
   my $totalLength = shift;
   my $musicbrainz_id = shift;

   if (!$artistName) { $artistName = ""; }
   if (!$trackTitle) { $trackTitle = ""; }
   if (!$albumName) { $albumName = ""; }

   Plugins::Scrobbler::scrobbleMsg("=======================================\n");
   Plugins::Scrobbler::scrobbleMsg("Starting to time \"$artistName - $trackTitle (from $albumName)\"\n");

   my $newTrack = Scrobbler::Track->new(
        filename      => $filename,
        artist        => $artistName,
        album         => $albumName,
        title         => $trackTitle,
        totalLength   => $totalLength,
	musicBrainzId => $musicbrainz_id,
   );
                     
   # Start the new track timing   
   $newTrack->play();

   # Register our track with the background submitter
   if (useBackgroundSubmitter()) {
       addTrackToSubmitter($client, $newTrack);
   }
   
   $playStatus->currentTrack($newTrack);
}


# Stop timing the current song
# (Either stop was hit or we are about to play another one)
sub stopTimingSong($$)
{
   # Parameter - client
   my $client = shift;
   # Parameter - PlayTrackStatus for current client
   my $playStatus = shift;

   my $track = $playStatus->currentTrack();
   if (!defined($track))
   {
      msg("Programmer error in Scrobbler::stopTimingSong() - not already timing!\n");   
   }
   else {
      # Attempt to stop the track timing
      $track->cancel();

      if (!useBackgroundSubmitter()) {
	  # If the track was played long enough to count as a listen, it will
	  # be marked 'Ready'
	  if ($track->isReady())
	  {
	      Plugins::Scrobbler::scrobbleMsg("Track was played long enough to count as listen\n");

	      my $session = getSessionForClient($client);
	      if (defined($session)) {
		  # Log it to Audioscrobbler
		  my $UTCtime = getUTCTimeRightNow();
		  $session->logTrackToAudioScrobblerAsPlayed($track, $UTCtime);
		  $track->markRegistered();

		  # If we're autosubmit, submit now
		  if (Slim::Utils::Prefs::get("plugin_scrobbler_auto_submit")) {
		      $session->tryToSubmitToAudioscrobblerIfNeeded();
		  }
	      }
	      else {
		  Plugins::Scrobbler::scrobbleMsg("No session - scrobbling is disabled for this client\n");
	      }
	      # We could also log to history at this point as well..
	  }
	  else {
	      Plugins::Scrobbler::scrobbleMsg("Track was NOT played long enough to count as listen\n");
	  }
      }
  }

}


# Debugging routine - shows current variable values for the given playStatus
sub showCurrentVariables($)
{
   # Parameter - PlayTrackStatus for current client
   my $playStatus = shift;

   Plugins::Scrobbler::scrobbleMsg("======= showCurrentVariables() ========\n");
   
   # Call Track to display artist, track name, etc.
   if (defined($playStatus->currentTrack())) {
     $playStatus->currentTrack()->showCurrentVariables();
   }
   else {
     Plugins::Scrobbler::scrobbleMsg("No track currently timing\n");
   }
   
   my $tmpIsPowerOn = $playStatus->isOn();
   Plugins::Scrobbler::scrobbleMsg("Is power on? : $tmpIsPowerOn\n");

   Plugins::Scrobbler::scrobbleMsg("=======================================\n");
}


sub getFunctions() 
{
	return \%functions;
}

sub sessionVars()
{
    return $sessionVars;
}

sub trackVars()
{
    return $trackVars;
}

########################################################################
## Background submission functions and data
##

my @tracks = ();
my @sessions = ();

sub submitter
{
    my @toDelete = ();

    # First, go through the tracks looking for any to register or delete
    my $i=0;
    my $client;
    my $session;
    my $track;
    foreach my $p (@tracks) {
	$client=$p->{client};
	$track=$p->{track};

	if ($track->isReady()) {
	    Plugins::Scrobbler::scrobbleMsg("Following track is ready to submit:\n");
	    $track->showCurrentVariables();

	    # Register it
	    my $UTCtime = getUTCTimeRightNow();
	    $session = getSessionForClient($client);
	    if (defined($session)) {
		$session->logTrackToAudioScrobblerAsPlayed($track, $UTCtime);
		$track->markRegistered();
	    }
	    else {
		Plugins::Scrobbler::scrobbleMsg("Client has no available Session (no userId set) - cancelling track\n");
		$track->cancel();
	    }
	    push(@toDelete, $i);
	}
	elsif ($track->isRegistered()) {
	    # Probably shouldn't happen, means the track has already
	    # been registered. Oh well, delete it
	    Plugins::Scrobbler::scrobbleMsg("Fogetting about following track:\n");
	    $track->showCurrentVariables();

	    push(@toDelete, $i);
	}
	elsif ($track->isCancelled()) {
	    # We can forget about this track now

	    Plugins::Scrobbler::scrobbleMsg("Forgetting about following track:\n");
	    $track->showCurrentVariables();

	    push(@toDelete, $i);
	}

	$i=$i+1;
    }

    # Delete those marked for deletion (I suspect this wouldn't be a good
    # idea during the previous foreach)
    my $offset=0;
    foreach my $d (@toDelete) {
	splice(@tracks, $d - $offset, 1);
	$offset=$offset+1;
    }


    # Now pass over the sessions, see if they need to submit
    if (Slim::Utils::Prefs::get("plugin_scrobbler_auto_submit")) {
	foreach $session (@sessions) {
	    $session->tryToBackgroundSubmitToAudioscrobblerIfNeeded();
	}
    }
   
    setSubmitterTimer();
}

sub setSubmitterTimer()
{
  Slim::Utils::Timers::setTimer("SlimScrobbler", Time::HiRes::time() + 10,
				\&submitter);
}

sub cancelSubmitterTimer()
{
    Slim::Utils::Timers::killOneTimer("SlimScrobbler", \&submitter);

    # Drop any tracks currently being timed. Otherwise, should the Plugin
    # become active again later, the track will be submitted regardless of
    # whether it was left playing for long enough.
    foreach my $p (@tracks) {
	my $track=$p->{track};
	$track->cancel();
    }
}

sub addTrackToSubmitter($$)
{
    my $client=shift;
    my $track=shift;

    if (defined($client) && defined($track)) {
	my $p = {
	    client => $client,
	    track => $track,
	};

	if (!$track->isCancelled()) {
	    push(@tracks, $p);
	}
    }
}

sub addSessionToSubmitter($)
{
    push(@sessions, shift);
}

sub useBackgroundSubmitter
{
    return Slim::Utils::Prefs::get("plugin_scrobbler_background_submit");
}


########################################################################
## Interface functions
##

sub setupGroup
{
    # The group is quite different depending on whether we're using
    # multiple accounts or not, so delegate to one of two methods.
    my $multi=Slim::Utils::Prefs::get("plugin_scrobbler_multiuser");
    if ($multi) { return setupGroupMultiUserId(); }
    else { return setupGroupSingleUserId(); }
}

# The group when just one userid is used for all players
sub setupGroupSingleUserId
{
	my %group = (
		PrefOrder => ['plugin_scrobbler_user',
					  'plugin_scrobbler_password',
					  'plugin_scrobbler_auto_submit',
			                  'plugin_scrobbler_multiuser'],
		PrefsInTable => 1,
		GroupHead => string('PLUGIN_SCROBBLER_HEADER'),
		GroupDesc => string('PLUGIN_SCROBBLER_DESC'),
		GroupLine => 1,
		GroupSub => 1,
		Suppress_PrefSub => 1,
		Suppress_PrefLine => 1,
		Suppress_PrefHead => 1
	);

	my %prefs = (
		'plugin_scrobbler_user' => {
			'validate' => \&Slim::Web::Setup::validateAcceptAll,
			'PrefChoose' => string('PLUGIN_SCROBBLER_USERNAME'),
			'changeIntro' => string('PLUGIN_SCROBBLER_USERNAME')
		},
		'plugin_scrobbler_password' => {
			'validate' => \&Slim::Web::Setup::validateAcceptAll,
			'PrefChoose' => string('PLUGIN_SCROBBLER_PASSWORD'),
			'changeIntro' => string('PLUGIN_SCROBBLER_PASSWORD'),
			'changeMsg' => string('PLUGIN_SCROBBLER_PASSWORD_CHANGED'),
			'inputTemplate' => 'setup_input_passwd.html'
		},
		'plugin_scrobbler_auto_submit' => {
			'validate' => \&Slim::Web::Setup::validateTrueFalse ,
			'PrefChoose' => string('PLUGIN_SCROBBLER_AUTOSUBMIT'),
                        'changeIntro' => string('PLUGIN_SCROBBLER_AUTOSUBMIT_2'),
			'options' =>
				{
				'1' => string('ON'),
				'0' => string('OFF')
				},
			'currentValue' =>
			    sub {return Slim::Utils::Prefs::get("plugin_scrobbler_auto_submit");}
		},
		'plugin_scrobbler_multiuser' => {
                        'validate' => \&Slim::Web::Setup::validateTrueFalse ,
                        'PrefChoose' => string('PLUGIN_SCROBBLER_MULTI_ACCOUNTS'),
                        'changeIntro' => string('PLUGIN_SCROBBLER_MULTI_ACCOUNTS_2'),
                        'options' =>
                                {
                                '1' => string('ON'),
                                '0' => string('OFF')
                                }
		}

	);

	return (\%group, \%prefs);
}

# Hack to workaround slimserver's memory of recently-set preferences
my $freshUseridHack=0;

# The group used with multiple accounts. This is constructed dynamically
# based on the list of userids.
sub setupGroupMultiUserId()
{
    # @prefArray is the list of preferences, which will be inserted into
    # PrefOrder property in the result group
    my @prefArray = ();

    # $useridChoice is the choice map used in the entry for the default
    # userid property
    my %useridChoice = ();

    my %prefs = ();

    push @prefArray, "plugin_scrobbler_default_userid";
    $useridChoice{""} = string('PLUGIN_SCROBBLER_NONE');

    my %ups = getAllUserIDPasswords();
    my @userids = sort keys %ups;
    foreach my $userid (@userids) {
	push @prefArray, "plugin_scrobbler_user_${userid}_pw";
	$useridChoice{$userid} = $userid;

	my $prefname = string('PLUGIN_SCROBBLER_PASSWORD_FOR') . " '${userid}'";
	$prefs{"plugin_scrobbler_user_${userid}_pw"} = {
	    'validate' => \&Slim::Web::Setup::validateAcceptAll,
	    'PrefSize' => "medium",
	    'PrefChoose' => $prefname,
	    'changeIntro' => $prefname,
	    'changeMsg' => string('PLUGIN_SCROBBLER_PASSWORD_CHANGED'),
	    'inputTemplate' => 'setup_input_passwd.html',
	};
    }

    $prefs{"plugin_scrobbler_default_userid"} = {
	'validate' => \&Slim::Web::Setup::validateAcceptAll,
	'PrefSize' => "medium",
	'PrefChoose' => string('PLUGIN_SCROBBLER_DEFAULT_ACCOUNT'),
	'changeIntro' => string('PLUGIN_SCROBBLER_DEFAULT_ACCOUNT_2'),
	'options' => \%useridChoice,
        'currentValue' => sub {return Slim::Utils::Prefs::get("plugin_scrobbler_default_userid");}
    };

    # Fields to allow the user to add a new userid/password
    push @prefArray, "plugin_scrobbler_new_${freshUseridHack}userid";
    push @prefArray, "plugin_scrobbler_new_${freshUseridHack}pw";

    $prefs{"plugin_scrobbler_new_${freshUseridHack}userid"} = {
	'validate' => \&Slim::Web::Setup::validateAcceptAll,
	'PrefSize' => "medium",
	'PrefChoose' => string('PLUGIN_SCROBBLER_NEW_USERID'),
	'changeIntro' => string('PLUGIN_SCROBBLER_NEW_USERID_2'),
    };

    $prefs{"plugin_scrobbler_new_${freshUseridHack}pw"} = {
	'validate' => \&Slim::Web::Setup::validateAcceptAll,
	'PrefSize' => "medium",
	'PrefChoose' => string('PLUGIN_SCROBBLER_NEW_PASSWORD'),
	'changeIntro' => string('PLUGIN_SCROBBLER_NEW_PASSWORD_2'),
	'changeMsg' => string('PLUGIN_SCROBBLER_PASSWORD_CHANGED'),
	'inputTemplate' => 'setup_input_passwd.html',
    };

    # The fields shown on both the single-user and multi-user
    # displays
    push @prefArray, "plugin_scrobbler_auto_submit";
    push @prefArray, "plugin_scrobbler_multiuser";

    $prefs{"plugin_scrobbler_auto_submit"} = {
	'validate' => \&Slim::Web::Setup::validateTrueFalse,
	'PrefChoose' => string('PLUGIN_SCROBBLER_AUTOSUBMIT'),
	'changeIntro' => string('PLUGIN_SCROBBLER_AUTOSUBMIT_2'),
	'options' => {
	    '1' => string('ON'),
	    '0' => string('OFF'),
	},
    };
    
    $prefs{"plugin_scrobbler_multiuser"} = {
	'validate' => \&Slim::Web::Setup::validateTrueFalse,
	'PrefChoose' => string('PLUGIN_SCROBBLER_MULTI_ACCOUNTS'),
	'changeIntro' => string('PLUGIN_SCROBBLER_MULTI_ACCOUNTS_2'),
	'options' => {
	    '1' => string('ON'),
	    '0' => string('OFF'),
	}
    };

    
    # Finally, the group
    my %group = (
		 PrefOrder => \@prefArray,
		 PrefsInTable => 1,
		 GroupHead => string('PLUGIN_SCROBBLER_HEADER'),
		 GroupDesc => string('PLUGIN_SCROBBLER_DESC_MULTIUSERID'),
		 GroupLine => 1,
		 GroupSub => 1,
		 Suppress_PrefSub => 1,
		 Suppress_PrefLine => 1,
		 Suppress_PrefHead => 1
		 );

    return (\%group, \%prefs);
}

# Cleans up the userid/password list. Removes any deleted userids from
# the userid list, and adds any new userid to the userid list.
sub cleanUpPasswords
{
    my $changed=0;

    my $prop = Slim::Utils::Prefs::get("plugin_scrobbler_useridlist");
    my @userids;
    if ($prop) {
	@userids = split /,/, $prop;
    }
    else {
	@userids = ();
    }

    my $defuserid = Slim::Utils::Prefs::get("plugin_scrobbler_default_userid") || "";

    my @newuserids = ();
    # First, check for deleted userid. These will have no password set
    foreach my $userid (@userids) {
	my $pw=Slim::Utils::Prefs::get("plugin_scrobbler_user_${userid}_pw");
	if ($pw) {
	    push @newuserids, $userid;
	}
	else {
            Plugins::Scrobbler::scrobbleMsg("Userid $userid deleted\n");
 	    Slim::Utils::Prefs::delete("plugin_scrobbler_user_${userid}_pw");
	    if ($userid eq $defuserid) {
		Slim::Utils::Prefs::set("plugin_scrobbler_default_userid", "");
	    }
	    $changed=1;
	}
    }

    # Now look to see if we have a new userid
    my $newuser=Slim::Utils::Prefs::get("plugin_scrobbler_new_${freshUseridHack}userid");
    my $newpw=Slim::Utils::Prefs::get("plugin_scrobbler_new_${freshUseridHack}pw");
    if ($newuser) {
	# Check that newuser isn't already in the list
	my $found = 0;
	foreach my $u (@newuserids) {
	    if ($u eq $newuser) {$found = 1;}
	}
	if ($found) {
	    Plugins::Scrobbler::scrobbleMsg("Userid $newuser already known, just setting password\n");
	}
	else {
	    Plugins::Scrobbler::scrobbleMsg("Userid $newuser added\n");
	    $changed=1;
	    push @newuserids, $newuser;
	}
	Slim::Utils::Prefs::set("plugin_scrobbler_user_${newuser}_pw", $newpw);
    }
    Slim::Utils::Prefs::delete("plugin_scrobbler_new_${freshUseridHack}userid");
    Slim::Utils::Prefs::delete("plugin_scrobbler_new_${freshUseridHack}pw");

    if (($newuser) || ($newpw)) {
	$freshUseridHack++;
    }

    if ($changed) {
	$prop = join ',', @newuserids;
	Slim::Utils::Prefs::set("plugin_scrobbler_useridlist", $prop);
	Slim::Utils::Prefs::writePrefs();
    }
}

sub initSetting
{
    my $setting = shift;
    my $default = shift;
	
    if (!Slim::Utils::Prefs::isDefined($setting))
    {
	my $oldSetting = $setting;

	$oldSetting =~ s/^plugin_//;
	$oldSetting =~ s/_/-/g;

	if (Slim::Utils::Prefs::isDefined($oldSetting))
	{
	    my $value = Slim::Utils::Prefs::get($oldSetting);

	    Slim::Utils::Prefs::set($setting, $value);
	    Slim::Utils::Prefs::delete($oldSetting);
	    Plugins::Scrobbler::scrobbleMsg("Migrating $oldSetting to $setting - value is $value\n");
	}
	else {
	    Slim::Utils::Prefs::set($setting, $default);
            Plugins::Scrobbler::scrobbleMsg("Setting $setting to default value $default\n");
	}
    }
}


1;

__DATA__

PLUGIN_SCROBBLER
	EN	Audioscrobbler Submitter

PLUGIN_SCROBBLER_ACTIVATED
	EN	Audioscrobbler activated...

PLUGIN_SCROBBLER_DEACTIVATED
	EN	Audioscrobbler deactivated...

PLUGIN_SCROBBLER_ENABLED
	EN	Audioscrobbler is ON
	
PLUGIN_SCROBBLER_DISABLED
	EN	Audioscrobbler is OFF
	
PLUGIN_SCROBBLER_HIT_PLAY_TO_SUBMIT
	EN	Press PLAY to submit now

PLUGIN_SCROBBLER_SUBMITTING
	EN	Submitting data to Audioscrobbler...

PLUGIN_SCROBBLER_HEADER
	EN	Last.FM / Audioscrobbler

PLUGIN_SCROBBLER_DESC
	EN	Choose your settings for the SlimScrobbler

PLUGIN_SCROBBLER_USERNAME
	EN	Last.FM/Audioscrobbler Username 

PLUGIN_SCROBBLER_PASSWORD
	EN	Last.FM/Audioscrobbler Password 

PLUGIN_SCROBBLER_PASSWORD_CHANGED
	EN	Password Changed

PLUGIN_SCROBBLER_AUTOSUBMIT
	EN	Submit Automatically

PLUGIN_SCROBBLER_AUTOSUBMIT_2
	EN	Audioscrobbler - AutoSubmit 

PLUGIN_SCROBBLER_MAX_PENDING
	EN	Max Pending Requests 

PLUGIN_SCROBBLER_MAX_PENDING_2
	EN	Audioscrobbler - Max Pending Requests

PLUGIN_SCROBBLER_BAD_CONFIG
	EN	Please set username and password

PLUGIN_SCROBBLER_OF
	EN	of

PLUGIN_SCROBBLER_SELECT_ACCOUNT
	EN	Select Audioscrobbler Account

PLUGIN_SCROBBLER_USE_DEFAULT_ACCOUNT
	EN	Use Server Default

PLUGIN_SCROBBLER_NONE
	EN	None

PLUGIN_SCROBBLER_MULTI_ACCOUNTS
	EN	Support for Multiple Usernames

PLUGIN_SCROBBLER_MULTI_ACCOUNTS_2
	EN	Audioscrobbler - Multiple Usernames

PLUGIN_SCROBBLER_PASSWORD_FOR
	EN	Password for

PLUGIN_SCROBBLER_DEFAULT_ACCOUNT
	EN	Account to use for new players

PLUGIN_SCROBBLER_DEFAULT_ACCOUNT_2
	EN	Audioscrobbler - Default Account

PLUGIN_SCROBBLER_NEW_USERID
	EN	Add new username

PLUGIN_SCROBBLER_NEW_USERID_2
	EN	Audioscrobbler - new username added

PLUGIN_SCROBBLER_NEW_PASSWORD
	EN	Password for new username

PLUGIN_SCROBBLER_NEW_PASSWORD_2
	EN	Audioscrobbler - Password for new username

PLUGIN_SCROBBLER_DESC_MULTIUSERID
	EN	Use the 'Add new username' field to configure an Audioscrobbler account. You can then use the player's on-screen menu to select which account to use for that player. Delete an account by clearing the password field.
