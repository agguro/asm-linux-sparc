#    LastFM.pm 
#
#    Copyright (c) 2006 James Craig (james.craig@london.com)
#
#    This program is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program; if not, write to the Free Software
#    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#
# CHANGES
# 1.1.4 05-01-06
# ignore discovery mode if listening to personal radio & vice versa
# 
# 1.1.3 22-11-05
# add links to save station/stationfeed
# correct player menu behaviour
# add track info mode
#
# 1.1.2 21-11-05
# don't WARN on track underrun - happening too often
# show discovery as a command on web page
# 1.1.1	20-11-05 
# fixed web page
# 1.1.0 20-11-05
# option of choosing station on startup
# manage station list from web page
# generate similar artist station automatically
# tidy web page logic
# switch to prod lastfm server
# add record-to-profile command etc.
# add discovery mode station for subscribers
#
# 1.0.4 13-11-05
# changes to web page
# fix prefs order
# 1.0.3 12-11-05
# added spanish translation courtesy of Nestor Spedalieri
# on screen display of warning state
# 1.0.2 10-11-05
# check for track overrun, allow restart from menu if so
# 1.0.1 07-11-05
# fix bug in subscriber menu
# 1.0.0	31-10-05

package Plugins::LastFM::Plugin;

use Slim::Utils::Strings qw(string);
use Slim::Utils::Prefs;
use Slim::Utils::Misc;

use Class::Struct;
use Digest::MD5 qw(md5_hex);
use Data::Dumper;

## Global variables ###
my @lastfm_commands = qw/skip love ban rtp/; #discovery gets added later 			
my @lastfm_subscriber_options = qw/neighbours personal loved/; 	#are there any others? 

my $lastfm_history_size = 5;					# make this a pref?
my $lastfm_timeout = 60;					# how long between scheduled updates
my $lastfm_command_timeout = 10;				# how long to wait for an update after sending a command
#my $lastfm_server_address = 'http://wsdev.audioscrobbler.com';
my $lastfm_server_address = 'http://ws.audioscrobbler.com';
my %players;

# SLIMSERVER API ###################
use vars qw($VERSION);
$VERSION = substr(q$Revision: 1.1.0 $,10);

sub strings {
	return "
PLUGIN_LASTFM_MODULE_NAME
	EN	LastFM

PLUGIN_LASTFM_CHOOSE_PLAYER
	EN	Please choose a player and return to this page!
	ES	Por favor, elegir un reproductor y regresar a esta página!

PLUGIN_LASTFM_CONNECTING
	EN	Connecting to LastFM...
	ES	Conectando a LastFM...

PLUGIN_LASTFM_CONNECTION_ERROR
	EN	Error connecting to LastFM! Check network connection and www.Last.fm status
	ES	Error al conectarse a LastFM! Verfificar la conexión de red y el status de www.LastFM.com

PLUGIN_LASTFM_SESSION_ERROR
	EN	Error connecting to LastFM! Check username & password
	ES	Error al conectarse a LastFM! Verificar el nombre de usuario & contraseña

PLUGIN_LASTFM_UPDATING
	EN	Updating LastFM...
	ES	Actualizando LastFm...

PLUGIN_LASTFM_UPDATE_FAILED
	EN	Error sending update to LastFM!
	ES	Error al enviar la actualización a LastFM!

PLUGIN_LASTFM_WARNING
	EN	Warning: LastFM error detected.

PLUGIN_LASTFM_PRESS_PLAY
	EN	Press play to start LastFM...
	ES	Presionar play para iniciar LastFM...

PLUGIN_LASTFM_WAIT
	EN	Waiting for LastFM track details...
	ES	Esperando detalles de la pista de LastFM...

PLUGIN_LASTFM_UPDATE_SUCCESS
	EN	Update sent to LastFM!
	ES	Actualización enviada a LastFM!

PLUGIN_LASTFM_SKIP
	EN	SKIP current track
	ES	SALTEAR pista actual

PLUGIN_LASTFM_LOVE
	EN	LOVE current track
	ES	AMAR pista actual

PLUGIN_LASTFM_BAN
	EN	BAN current track
	ES	PROHIBIR la pista actual

PLUGIN_LASTFM_PERSONAL
	EN	Personal

PLUGIN_LASTFM_DISCOVERY
	EN	Discovery Mode

PLUGIN_LASTFM_NEIGHBOURS
	EN	Neighbours
	ES	Vecinos

PLUGIN_LASTFM_LOVED
	EN	Loved
	ES	Amada

PLUGIN_LASTFM_RTP
	EN	Record to Profile

PLUGIN_LASTFM_RANDOM
	EN	Random
	ES	Al Azar

PLUGIN_LASTFM_SIMILAR_ARTISTS
	EN	Similar Artists
	ES	Artistas Similares

PLUGIN_LASTFM_STATION
	EN	Station
	ES	Estación

PLUGIN_LASTFM_CHANGE_STATION
	EN	Change LastFM Station
	ES	Cambiar la Estación LastFM

SETUP_GROUP_PLUGIN_LASTFM
	EN	LastFM Internet Radio
	ES	Radio por Internet LastFM
	
SETUP_GROUP_PLUGIN_LASTFM_DESC
	EN	Listen to and control the LastFM internet radio station
	ES	Escuchar y controlar la estación de radio por internet de LastFM

SETUP_PLUGIN_LASTFM_PASSWORD_CHANGED
	EN	Your LastFM password has been changed
	ES	Se ha cambiado la contraseña para LastFM

SETUP_PLUGIN_LASTFM_PASSWORD
	EN	LastFM Password
	ES	Contraseña de LastFM

SETUP_PLUGIN_LASTFM_USERNAME
	EN	LastFM Username
	ES	Nombre de Usuario de LastFM

SETUP_PLUGIN_LASTFM_ALBUMSIZE
	EN	LastFM Album art size
	ES	Tamaño del Arte de Tapa de LastFM

SETUP_PLUGIN_LASTFM_STATIONS
	EN	Enter your favourite LastFM Stations
	ES	Ingresar las Estaciones Favoritas de LastFM

SETUP_PLUGIN_LASTFM_STATIONS_DESC
	EN	e.g. group/groupname for \"group\" radio, user/username for \"user\" radio, globaltags/tagname for \"tag\" radio, artist/artistname/similarartists for \"similar artist\" radio
	
SETUP_PLUGIN_LASTFM_STATIONS_CHANGED
	EN	LastFM Stations changed
	ES	Estaciones de LastFM cambiadas

SETUP_PLUGIN_LASTFM_USESCROBBLER
	EN	Use login details from SlimScrobbler plugin
	ES	Utilizar los detalles de conexión del plugin SlimScrobbler

SETUP_PLUGIN_LASTFM_USESCROBBLER_CHANGED
	EN	Use SlimScrobbler login setting changed

";}

sub addMenu {
	my $menu = "RADIO";
	return $menu;
}

sub getDisplayName { 
	return $::VERSION =~ m/6\./ ? 'PLUGIN_LASTFM_MODULE_NAME' : string('PLUGIN_LASTFM_MODULE_NAME');
}

sub initPlugin {
	# web setup doesn't seem to work if array pref is empty
	if (! Slim::Utils::Prefs::getArray("plugin_lastfm_stations")) {
		Slim::Utils::Prefs::set('plugin_lastfm_stations', ['group/SlimScrobbler']);
	}
	if (! Slim::Utils::Prefs::get('plugin_lastfm_albumsize')) {
		Slim::Utils::Prefs::set('plugin_lastfm_albumsize','albumcover_small');
	}
	# if this is run for the first time
	if (! defined Slim::Utils::Prefs::get('plugin_lastfm_usescrobbler')) {
		# if there's a SlimScrobbler pref set and the plugin is not disabled...
		if (!grep {$_ eq 'Scrobbler'} Slim::Utils::Prefs::getArray('disabledplugins') and
			defined Slim::Utils::Prefs::get('plugin_scrobbler_multiuser')) {
			Slim::Utils::Prefs::set('plugin_lastfm_usescrobbler',1);
		} else {
			Slim::Utils::Prefs::set('plugin_lastfm_usescrobbler',0);
		}
	}
}

sub setupGroup {
	my @prefOrder = (
		'plugin_lastfm_stations',
		'plugin_lastfm_albumsize',
		);
	if (!Slim::Utils::Prefs::get('plugin_lastfm_usescrobbler')) {
		unshift @prefOrder, 'plugin_lastfm_password';
		unshift @prefOrder, 'plugin_lastfm_username';
	}
	if (!grep {$_ eq 'Scrobbler'} Slim::Utils::Prefs::getArray('disabledplugins') and
		defined Slim::Utils::Prefs::get('plugin_scrobbler_multiuser')) {
		push @prefOrder, 'plugin_lastfm_usescrobbler';
	}

	my %Group = (
		PrefOrder => \@prefOrder,
		GroupHead => string( 'SETUP_GROUP_PLUGIN_LASTFM' ),
		GroupDesc => string( 'SETUP_GROUP_PLUGIN_LASTFM_DESC' ),
		GroupLine => 1,
		GroupSub  => 1,
		Suppress_PrefSub  => 1,
		Suppress_PrefLine => 1
	);

	my %Prefs = (
		plugin_lastfm_username => {
		},
		plugin_lastfm_password => { 
			'onChange' => sub {
				my $encoded = md5_hex($_[1]->{plugin_lastfm_password}->{new} );
				Slim::Utils::Prefs::set( 'plugin_lastfm_password', $encoded );
				refreshSessions();
			}
			,'inputTemplate' => 'setup_input_pwd.html'
			,'changeMsg' => string('SETUP_PLUGIN_LASTFM_PASSWORD_CHANGED')
		},
		plugin_lastfm_stations => { 
			'isArray' => 1
			,'arrayAddExtra' => 1
			,'arrayDeleteNull' => 1
			,'arrayDeleteValue' => ''
			,'arrayBasicValue' => 0
			,'PrefSize' => 'large'
			,'inputTemplate' => 'setup_input_array_txt.html'
			,'PrefInTable' => 1
			,'showTextExtValue' => 0
			,'onChange' => sub {
				my ($client,$changeref,$paramref,$pageref) = @_;
				if (exists($changeref->{'plugin_lastfm_stations'}{'Processed'})) {
					return;
				}
				Slim::Web::Setup::processArrayChange($client,
													 'plugin_lastfm_stations',
													 $paramref, 
													 $pageref);
				$changeref->{'plugin_lastfm_stations'}{'Processed'} = 1;
			}
			,'changeMsg' => string('SETUP_PLUGIN_LASTFM_STATIONS_CHANGED')
		},
		plugin_lastfm_albumsize => { 
			'options' => {
				none => 'none', 
				albumcover_small => 'small',
				albumcover_medium => 'medium',
			       	albumcover_large => 'large',
			}, 
			'optionSort' => 'V', 
		},
		'plugin_lastfm_usescrobbler' => {
                        'validate' => \&Slim::Web::Setup::validateTrueFalse ,
                        'options' =>
                                {
                                '1' => string('ON'),
                                '0' => string('OFF')
                                }
		}
	);

	return( \%Group, \%Prefs );
}

## WEB #######################

sub webPages {
	my %pages = ("index\.htm" => \&handleWebIndex);

	if (grep {$_ eq 'LastFM::Plugin'} Slim::Utils::Prefs::getArray('disabledplugins')) {
		Slim::Web::Pages::addLinks("radio", { 'PLUGIN_LASTFM_MODULE_NAME' => undef });
	} else {
		Slim::Web::Pages::addLinks("radio", { 'PLUGIN_LASTFM_MODULE_NAME' => "plugins/LastFM/index.html" });
	}
	
    return (\%pages);
}

sub handleWebIndex {
	my ($client, $params) = @_;

	# without a player, don't do anything
	if ($client = Slim::Player::Client::getClient($params->{player})) {
		my $macaddress = $client->macaddress;

		if (defined $params->{p0}) {
			if ( $params->{p0} eq 'delete' ) {
				deleteStation($params->{p1});
			} elsif ( $params->{p0} eq 'add') {
				addStation($params->{p1});
			} elsif ($params->{p0} eq 'playlfm') {
				playLastFM($client,$params->{p1});
			}
		}

		if (getLastFMStatus($client)) {

			if (defined $params->{p0}) {
				if ( $params->{p0} eq 'command') {
					commandLastFM($params->{player},$params->{p1});
				}
			}

			#possible commands
			$params->{commands} = $players{$macaddress}->commands;
			$params->{rtp} = $players{$macaddress}->rtp;
			$params->{disco} = $players{$macaddress}->disco;

			# show any track data we may have
			my %data = %{$players{$macaddress}->datahash};
			@$params{keys %data} = values %data;

			#add the selected album art size
			#web page status is keyed off the presence of this field
			$params->{albumart} = $data{Slim::Utils::Prefs::get("plugin_lastfm_albumsize")};
		}

		#status flag, if any
		if (my $status = $players{$macaddress}->status) { 
			$params->{status} = $status;
		}

		my @stationNames = genStationNames($client);
		$params->{stationnames} = \@stationNames;

		# add the recently played history
		$params->{history} = $players{$macaddress}->history;

		# add the user' name
		my ($user) = getUserDetails($macaddress);
		$params->{user} = $user;
		
		# calculate refresh interval
		my $check_time = time();
		my $elapsed = $check_time - $players{$macaddress}->last_check_time;
		$params->{refresh} = ($players{$macaddress}->remaining - $elapsed) + 5;
	}
	$params->{refresh} = $lastfm_timeout unless ($params->{refresh} and $params->{refresh} > 5);
	lastFMmsg("web page refresh: ".$params->{refresh}."\n");
	return Slim::Web::HTTP::filltemplatefile('plugins/LastFM/index.html', $params);
}

# Main mode ################################################################

my %mainModeFunctions = (
	'left' => sub  {
		my $client = shift;
		Slim::Buttons::Common::popModeRight($client);
	},
	'right' => sub  {
		my $client = shift;
		action($client,'right');
	},
	'down' => sub {
		my $client = shift;
		my $button = shift;
		if ($button !~ /repeat/) {
			if (getLastFMStatus($client)) {
				$players{$client->macaddress}->listitem($players{$client->macaddress}->listitem+1);
				$client->pushDown();
			} else {
				$client->bumpDown();
			}
		}
	},
	'up' => sub {
		my $client = shift;
		my $button = shift;
		if ($button !~ /repeat/) {
			if (getLastFMStatus($client)) {
				$players{$client->macaddress}->listitem($players{$client->macaddress}->listitem-1);
				$client->pushUp();
			} else {
				$client->bumpUp();
			}
		}
	},
   	'play' => sub {
	   my $client = shift;
		action($client,'play');
	},
	# direct function access for IR map
   	'lastfm_skip' => sub {
		my $client = shift;
		if (getLastFMStatus($client)) {
			commandLastFM($client->macaddress, 'skip');
		}
	},
	'lastfm_love' => sub {
		my $client = shift;
		if (getLastFMStatus($client)) {
			commandLastFM($client->macaddress, 'love');
		}
	},
	'lastfm_ban' => sub {
		my $client = shift;
		if (getLastFMStatus($client)) {
			commandLastFM($client->macaddress, 'ban');
		}
	},
);

sub getFunctions {
	return \%mainModeFunctions;
}

sub action {
	my $client = shift;
	my $button = shift;
	
	# connected
	if (getLastFMStatus($client)) {
		# choose station
		my @commands = @{$players{$client->macaddress}->commands};
		if ($players{$client->macaddress}->listitem > @commands) { 
			chooseStations($client);
		# commands
		} elsif ($players{$client->macaddress}->listitem != 0 ) { 
			Slim::Display::Animation::showBriefly($client, 
				$client->string('PLUGIN_LASTFM_MODULE_NAME'), 
				$client->string('PLUGIN_LASTFM_UPDATING'));
			commandLastFM($client->macaddress, $commands[$players{$client->macaddress}->listitem-1]);
			$players{$client->macaddress}->listitem(0);
			$client->update();
		# 0 - INFO line
		} else { 
			if ($button eq 'play' and $players{$client->macaddress}->status eq 'WARN') {
				playLastFM($client);
			} elsif ($button eq 'right') {
				# push on another mode displaying the track/station info
				my $data = $players{$client->macaddress}->datahash;
				my @infoStringList = (
					$client->string('TRACK') .': '.$data->{track},
					$client->string('ARTIST').': '.$data->{artist},
					$client->string('ALBUM') .': '.$data->{album},
					$client->string('PLUGIN_LASTFM_STATION').': '.$data->{station},
					'Feed: '.$data->{stationfeed},
				);
				my %params = (
					header => '{PLUGIN_LASTFM_MODULE_NAME} {count}',
					listRef => \@infoStringList,
					parentMode => Slim::Buttons::Common::mode($client),
				);        
				Slim::Buttons::Common::pushModeLeft($client,'INPUT.Choice',\%params);
			} else {
				Slim::Display::Animation::bumpRight($client);
			}
		}
	# not connected
	} else {
		if ($button eq 'play') {
			playLastFM($client);
		} else {
			chooseStations($client);
		}
	}
}

sub setMode() 
{
	my $client = shift;
	my $method = shift;
	
	if ($method eq 'pop') {
		if (!$context{$client}->{blocking}) {
			$client->lines(\&lines);
		}
	} else {
		$client->lines(\&lines);
	}
}

sub lines
{
	my $client = shift;
	my ($line1, $line2, $overlay1, $overlay2);

	$line1 = $client->string('PLUGIN_LASTFM_MODULE_NAME');

	if (getLastFMStatus($client)) {
		my @items = ("Info");
		my @commands = @{$players{$client->macaddress}->commands};
		for (@commands) {
			push @items, $client->string('PLUGIN_LASTFM_'.(uc $_));
		}
		push @items, $client->string('PLUGIN_LASTFM_CHANGE_STATION');
		
		$players{$client->macaddress}->listitem($players{$client->macaddress}->listitem % scalar(@items));
		$line1 .= " (".($players{$client->macaddress}->listitem + 1)." OF ".scalar(@items).")";

		if ($players{$client->macaddress}->status eq 'WARN') {
			$line1 = $client->string('PLUGIN_LASTFM_WARNING');
		} else {
			$overlay1 = $players{$client->macaddress}->station; 
			#$overlay1 .=" : ".$players{$client->macaddress}->stationfeed;		
		}

		$line2 = $items[$players{$client->macaddress}->listitem];
		$overlay2 = Slim::Display::Display::symbol('rightarrow');

		if ($line2 eq 'Info') {
			$overlay2 = $client->symbols(Slim::Display::Display::symbol('notesymbol'));
			$line2 = Slim::Music::Info::getCurrentTitle($client, Slim::Player::Playlist::song($client));
		} elsif ($line2 eq $client->string('PLUGIN_LASTFM_RTP')) {
			if ($players{$client->macaddress}->rtp == 1) {
				$overlay2 = '[x]';
			} else {
				$overlay2 = '[  ]';
			}
		} elsif ($line2 eq $client->string('PLUGIN_LASTFM_DISCOVERY')) {
			if ($players{$client->macaddress}->disco == 1) {
				$overlay2 = '[x]';
			} else {
				$overlay2 = '[  ]';
			}
		}
	} else {
		if ($players{$client->macaddress}->status eq 'FAILEDCONNECT' ) {
			$line2 = $client->string('PLUGIN_LASTFM_CONNECTION_ERROR')
		} elsif ($players{$client->macaddress}->status eq 'FAILEDLOGIN' ) {
			$line2 = $client->string('PLUGIN_LASTFM_SESSION_ERROR')
		} elsif ($players{$client->macaddress}->status eq 'STARTING' ) {
			$line2 = $client->string('PLUGIN_LASTFM_WAIT');
		} else {
			$line2 = $client->string('PLUGIN_LASTFM_PRESS_PLAY');
			$overlay2 = Slim::Display::Display::symbol('rightarrow');
		}
	}
	return ($line1, $line2,
		$overlay1, $overlay2
	);
}

#### STATION MODE - for the selection of stations
sub chooseStations {
	my $client = shift;

	@stationList = genStationNamesLevel1($client);
	@stationStringList = map $client->string('PLAY')." $_", @stationList;

	my %params = (
		header => '{PLUGIN_LASTFM_CHANGE_STATION} {count}',
		listRef => \@stationStringList,
		callback => \&stationModeCallback,
		onPlay => sub {
			my $client = shift;
			stationModeCallback($client,'RIGHT');
       		},
		valueRef => \$context{$client}->{stationModeIndex},
		parentMode => Slim::Buttons::Common::mode($client),
		overlayRef => [undef,Slim::Display::Display::symbol('rightarrow')],
		stations => \@stationList,	  
        );        
	Slim::Buttons::Common::pushModeLeft($client,'INPUT.Choice',\%params);
}

sub stationModeCallback {
    my ($client,$exittype) = @_;
    $exittype = uc($exittype);

    if ($exittype eq 'LEFT') {
	    Slim::Buttons::Common::popModeRight($client);
    } elsif ($exittype eq 'RIGHT') {
	my $listIndex = Slim::Buttons::Common::param($client, 'listIndex');
    	my $items = Slim::Buttons::Common::param($client, 'stations');
	my @stationTypeStringList = genStationNames($client,$items->[$listIndex]);
	if (@stationTypeStringList > 1) {
		my %params = (
              		header => '{PLUGIN_LASTFM_CHANGE_STATION} {count}',
              		listRef => \@stationTypeStringList,
               		callback => \&stationTypeCallback,
               		onPlay => sub {
               			my $client = shift;
				stationTypeCallback($client,'RIGHT');
               		},
              		valueRef => \$context{$client}->{stationTypeIndex},
               		parentMode => Slim::Buttons::Common::mode($client),
               		overlayRef => [undef,Slim::Display::Display::symbol('rightarrow')],
               		stations => \@stationTypeStringList,	  
               	);        
		Slim::Buttons::Common::pushModeLeft($client,'INPUT.Choice',\%params);
    	} else {
    		playLastFM($client, $stationTypeStringList[0]);
		$players{$client->macaddress}->listitem(0);
		Slim::Buttons::Common::popMode($client);
		$client->update();
	}
    } else {
		$client->bumpRight();
    }
}

#### STATION TYPE MODE - for the selection of station subtypes
sub stationTypeCallback {
    my ($client,$exittype) = @_;
    $exittype = uc($exittype);

    if ($exittype eq 'LEFT') {
	    Slim::Buttons::Common::popModeRight($client);
    } elsif ($exittype eq 'RIGHT') {
		my $listIndex = Slim::Buttons::Common::param($client, 'listIndex');
    	my $items = Slim::Buttons::Common::param($client, 'listRef');
    	my $selectedStation = $items->[$listIndex];
		playLastFM($client, $selectedStation);
		$players{$client->macaddress}->listitem(0);
		Slim::Buttons::Common::popMode($client);
		$client->update();
    } else {
		$client->bumpRight();
    }

}

### start of actual code

struct LastFMStatus => {
	session => '$',			#lastfm session id
	stream_url => '$',		#stream url
	streaming => '$',		#1/0 - stream status from LastFM
	rtp => '$',			#1/0 - record to profile status
	disco => '$',		#1/0 - discovery status
	subscriber => '$',		#1/0 - true/false
	station => '$',			#station name
	stationfeed => '$',		#station feed name
	artist => '$',			#artist name
	last_check_time => '$',	#
	duration => '$',		#length of current track
	progress => '$',		#position in current track
	remaining => '$',		#time remaining in current track
	listitem => '$',		#position in top-level menu
	base_url => '$',		#lastfm streaming server address
	history => '$',			#array - recently played tracks
	status => '$',			#our status
	datahash => '$',		#hashref - everything we get from LastFM in an update goes here
	commands => '$',		#arrayref of commands
};

sub getLastFMStatus {
	my $client = shift;
	
	createPlayer($client->macaddress);
   	
	# definitely not streaming if this is true - timer may not have been called yet so don't change status
	if (Slim::Player::Source::playmode($client) eq "stop") { 
		$players{$client->macaddress}->streaming(0); 
	}
   	
   	return $players{$client->macaddress}->streaming;
}

sub updateLastFMStatus {
	my $client = shift;
	 
	createPlayer($client->macaddress);
	
	# update the last checked time and remaining time
	my $check_time = time();
	my $elapsed = $check_time - $players{$client->macaddress}->last_check_time;

	$players{$client->macaddress}->last_check_time($check_time);
	$players{$client->macaddress}->remaining($players{$client->macaddress}->remaining - $elapsed); 
	$players{$client->macaddress}->remaining($lastfm_timeout)
       		if ($players{$client->macaddress}->remaining > $lastfm_timeout or $players{$client->macaddress}->remaining < 1);
	
	# we're playing (probably) so connect to LastFM for an update	
	if (Slim::Player::Source::playmode($client) ne "stop"
			and defined $players{$client->macaddress}->stream_url 
			and Slim::Player::Playlist::song($client) eq $players{$client->macaddress}->stream_url) {
    	my $lastfm_url = $players{$client->macaddress}->base_url."/np.php?session=".$players{$client->macaddress}->session;
		lastFMmsg("Connecting to $lastfm_url\n");
		my $http = Slim::Networking::SimpleAsyncHTTP->new(
			\&gotLastFMUpdate,
			\&failedLastFMUpdate,
			{client => $client}
		);
		$http->get($lastfm_url);
		return 1;
	}
	
	# we're not playing if we got here, but set the status & timer for next round
	$players{$client->macaddress}->streaming(0);
	$players{$client->macaddress}->status(undef);
	setLastFMTimer($client);
}
			
sub gotLastFMUpdate {
	my $http = shift;
	
	my $client = $http->params('client');
	my $macaddress = $client->macaddress;
	my $lastFMData = $http->content();
	$http->close();
	
	my %data = parseLastFMData($lastFMData);
	
	$players{$macaddress}->streaming( 0 );
	$players{$macaddress}->datahash(\%data);
	
	if ($data{ERROR} =~ /Invalid Session/) {
		lastFMmsg("Invalid Session: resetting session/stream!\n");
		$players{$macaddress}->session(undef);
		$players{$macaddress}->stream_url(undef);
	} elsif ($data{streaming} eq 'true') {
		$players{$macaddress}->streaming( 1 );
		$players{$macaddress}->status(undef);
		$players{$macaddress}->station( $data{station});
		$players{$macaddress}->stationfeed( $data{stationfeed});
		$players{$macaddress}->duration( $data{trackduration});
		$players{$macaddress}->progress( $data{trackprogress});
		$players{$macaddress}->artist( $data{artist});
		$players{$macaddress}->rtp( $data{recordtoprofile});
		$players{$macaddress}->disco( $data{discovery});
			
		# set the remaining time if there's a duration available
		if (defined $players{$macaddress}->duration) {
			$players{$macaddress}->remaining(
				($players{$macaddress}->duration - $players{$macaddress}->progress) + 10); 
			if ($players{$macaddress}->progress > $players{$macaddress}->duration ) {
				$players{$macaddress}->status('WARN');
				lastFMmsg("Track Overrun!");
			}
			#if ($players{$macaddress}->progress < 0) {
			#	$players{$macaddress}->status('WARN');
			#	lastFMmsg("Track underrun!");
			#}
		}
				
		my $title = "$data{track} ".$client->string('BY')." $data{artist} ".$client->string('FROM')." $data{album}";
		if ($title ne Slim::Music::Info::getCurrentTitle($client,$players{$macaddress}->stream_url)) {
			if (Slim::Music::Info::getCurrentTitle($client,$players{$macaddress}->stream_url) 
					ne $players{$macaddress}->stream_url
				and Slim::Music::Info::getCurrentTitle($client,$players{$macaddress}->stream_url) 
					ne $client->string('PLUGIN_LASTFM_MODULE_NAME')) {
				# add the current track to history
				my @history = @{$players{$macaddress}->history};
				unshift @history,Slim::Music::Info::getCurrentTitle($client,$players{$macaddress}->stream_url);
				pop @history if (@history > $lastfm_history_size);
				$players{$macaddress}->history(\@history);
			}
			# update the current track
			Slim::Music::Info::setCurrentTitle($players{$macaddress}->stream_url,$title);
		}
		$client->update();
	}

	# timeout if we're not streaming
	$players{$macaddress}->remaining($lastfm_timeout) 
		unless ($players{$macaddress}->streaming);
	$players{$macaddress}->remaining($lastfm_timeout) 
		if ($players{$macaddress}->remaining > $lastfm_timeout or $players{$macaddress}->remaining < 0) ;

	# refresh the info in n seconds
	setLastFMTimer($client);

	return $players{$macaddress}->streaming;
}

sub failedLastFMUpdate {
	my $http = shift;
	lastFMmsg ("Connection failed!\n");
	if (my $client = $http->params('client') || Slim::Player::Client::getClient($http->params('playername'))) {
		$players{$client->macaddress}->status('WARN');
		Slim::Display::Animation::showBriefly($client, 
				$client->string('PLUGIN_LASTFM_MODULE_NAME'), 
				$client->string('PLUGIN_LASTFM_UPDATE_FAILED'));
		# refresh the info in n seconds
		setLastFMTimer($client);
	}
}

sub commandLastFM {
	my $playername = shift;
	my $command = shift;
	my $page = 'control.php';
	
	# discovery mode not compatible with personal radio
	if ($command eq 'discovery') {
		if ($players{$playername}->station !~ m/personal/i) {
			$command = 'settings/discovery/';
			if ($players{$playername}->disco == 1) {
				$command .= 'off';
				$players{$playername}->disco(0);
			} else {
				$command .= 'on';
				$players{$playername}->disco(1);
			}
			switchLastFMStation($playername,$command);
		}
	} else {
		if ($command eq 'rtp') {
			#toggle rtp/nortp
			#also temporarily change values for correct user feedback
			#(these will be overwritten by the scheduled update)
			if ($players{$playername}->rtp) {
				$command = 'nortp';
				$players{$playername}->rtp(0);
			} else {
				$players{$playername}->rtp(1);
			}
		}
		postToLastFM($playername,$page, {command => $command} );
	}	
}

sub postToLastFM {
	my $playername = shift;
	my $page = shift;
	my $params = shift;
	
    	my $lastfm_url = $players{$playername}->base_url."/$page";

    	my $post = "session=".$players{$playername}->session;
    	for (keys %{$params}) {
		$post .= "\&$_=".Slim::Web::HTTP::escape($params->{$_});
	}
    
    	lastFMmsg("Sending $lastfm_url\?$post\n");
    	my $http = Slim::Networking::SimpleAsyncHTTP->new(
			\&gotLastFMControl,
			\&failedLastFMUpdate,
			{playername => $playername}
	);
	$http->get("$lastfm_url\?$post");
}

sub gotLastFMControl {
	my $http = shift;
	
	my $client = Slim::Player::Client::getClient($http->params('playername'));
	my $lastFMData = $http->content();
	$http->close();
	
	lastFMmsg("$lastFMData\n");
	if ($lastFMData =~ /FAILED/) {
		if ($client) {
			Slim::Display::Animation::showBriefly($client, 
				$client->string('PLUGIN_LASTFM_MODULE_NAME'), 
				$client->string('PLUGIN_LASTFM_UPDATE_FAILED'));
		}
		return 0;
	} 
	
	if ($client) {
		Slim::Display::Animation::showBriefly($client, 
			$client->string('PLUGIN_LASTFM_MODULE_NAME'), 
			$client->string('PLUGIN_LASTFM_UPDATE_SUCCESS'));
	}
	
	# refresh the info in n seconds
	setLastFMTimer($client,$lastfm_command_timeout);
	
	return 1;
}

sub getLastFMStreamURL {     
	my $client = shift;
	my $force = shift;
	
	$playername = $client->macaddress;

	my ($lastfm_user, $lastfm_password_md5sum) = getUserDetails($client->macaddress,1);

	return 0 unless (defined $lastfm_user and defined $lastfm_password_md5sum);

	return 1 if ($players{$playername}->stream_url and !$force);
	
	$players{$playername}->status(undef);
	
	my $lastfm_url = "$lastfm_server_address/radio/handshake.php?version=1.0.1&platform=slim&username=$lastfm_user&passwordmd5=$lastfm_password_md5sum";
	lastFMmsg("Connecting to: $lastfm_url\n");

	# we don't use async here, because when we exit, I want to be sure the new session url has been populated
	my $http = Slim::Player::Protocols::HTTP->new({
		'url'    => $lastfm_url,
		'create' => 0,
    });
        
    if (defined $http) {
		my $lastFMData = $http->content();
		$http->close();
		
		my %data = parseLastFMData($lastFMData);
		$players{$playername}->session($data{session});
		if ($lastFMData =~ /FAILED/) {
			$players{$playername}->status('FAILEDLOGIN');
			return 0;
		}
				
		$players{$playername}->stream_url($data{stream_url}); 
		$players{$playername}->base_url("http://$data{base_url}$data{base_path}");
		$players{$playername}->remaining($lastfm_timeout/2);
		$players{$playername}->last_check_time(time());
		$players{$playername}->subscriber($data{subscriber});
		
		if ($data{subscriber} == 1) {
			$players{$playername}->commands([@lastfm_commands,'discovery']);
		} else {
			$players{$playername}->commands([@lastfm_commands]);
		}
		return 1;
    } 
    
	$players{$playername}->status('FAILEDCONNECT');
    lastFMmsg("Connection failed!\n");
    return 0;
}

sub playLastFM {
	my $client = shift;
	my $station = shift;

	if (!getLastFMStatus($client)) {
		if (refreshSessions($client->macaddress)) {
			setLastFMTimer($client);
			$client->execute(['playlist','play',
			$players{$client->macaddress}->stream_url,
			$client->string('PLUGIN_LASTFM_MODULE_NAME')]);
			$players{$client->macaddress}->status('STARTING');
		} else {
			return 0;
		}
	}
	if ($station and $station ne '') {
		switchLastFMStation($client->macaddress,$station);
	}
}

sub refreshSessions {
	my $player = shift;
	my $status = 0;
	
	for ($player or keys %players) {
		my $client = Slim::Player::Client::getClient($_);
		$status = getLastFMStreamURL($client,1) if $client;
	}
	# return the true status if only 1 player 
	return $status if ($player);
	
	# otherwise always success
	return 1;
}

# utility functions ##############
sub getUserDetails{
	my $macaddress = shift;
	my $want_password = shift;
	
	my ($lastfm_user, $lastfm_password);

	if (!Slim::Utils::Prefs::get('plugin_lastfm_usescrobbler')) {
		$lastfm_user   = Slim::Utils::Prefs::get( 'plugin_lastfm_username' );
		$lastfm_password = Slim::Utils::Prefs::get( 'plugin_lastfm_password' );	
	} else {
		my $client = Slim::Player::Client::getClient($macaddress);
		($lastfm_user,$lastfm_password) =  Plugins::Scrobbler::getUserIDPasswordForClient($client);
		
		# only encrypt the password if we wanted it - does md5_hex cause performance hit?
		$lastfm_password = md5_hex($lastfm_password) if (defined $want_password);
	}
	return ($lastfm_user,$lastfm_password);
}

sub lastFMmsg{
	$text = shift;
	if ($::d_plugins) { 
		msg("LastFM: $text");
	}
} 

sub createPlayer {
	my $client = shift;
	return if ($players{$client});

	$players{$client} = LastFMStatus->new();
	$players{$client}->last_check_time(time());
	$players{$client}->remaining($lastfm_timeout/2);
	$players{$client}->streaming(0);
	$players{$client}->listitem(0);
	$players{$client}->subscriber(0);
	$players{$client}->session("UNSET");
}

sub parseLastFMData {
	my $lastFMData = shift;
	my %data;
	for (split /\n/, $lastFMData) {
		# strip whitespace from end of line
		m/^(.+?)=(.*?)\s*$/;
		$data{$1} = $2;
		lastFMmsg("$1 = $2\n");
	}
	return %data;
}

sub getLastFMStatusTimer{
	my $client = shift;
	updateLastFMStatus($client);
}

sub setLastFMTimer {
	my $client = shift;
	my $interval = shift;
	
	$interval = $players{$client->macaddress}->remaining unless ($interval);
	
	# timer to check alarms on an interval
	lastFMmsg("Setting timer for ".$interval." seconds for ".$client->macaddress."\n");
	Slim::Utils::Timers::killTimers($client, \&getLastFMStatusTimer);
	Slim::Utils::Timers::setTimer($client, Time::HiRes::time() + $interval, \&getLastFMStatusTimer);
}

## station related stuff
sub switchLastFMStation {
	my $playername = shift;
	my $selectedstation = shift;

	my $page = "adjust.php";
	$selectedstation = "lastfm://$selectedstation";

	postToLastFM($playername,$page,{url => $selectedstation});
}

sub deleteStation {
	my $station = shift;
	
	#tidy up the generated stations
	$station =~ s/\/(neighbours|loved|personal)$//i;

	@newStations = grep {$_ ne $station} Slim::Utils::Prefs::getArray('plugin_lastfm_stations');
	Slim::Utils::Prefs::set('plugin_lastfm_stations',\@newStations);
}

sub addStation {
	my $station = shift;
	
	#tidy up stations coming from LastFM details
	$station =~ s/^http:\/\/www.last.fm\/(.*)\/$/$1/i;

	@newStations = grep {$_ ne $station} Slim::Utils::Prefs::getArray('plugin_lastfm_stations');
	push @newStations, $station;
	Slim::Utils::Prefs::set('plugin_lastfm_stations',\@newStations);
}

sub genStationNamesLevel1 {
	my $client = shift;
	my $macaddress = $client->macaddress;

	my @stations = Slim::Utils::Prefs::getArray("plugin_lastfm_stations");
	my ($user) = getUserDetails($macaddress);
	unshift @stations, "user/$user";

	if (getLastFMStatus($client)) {
		#add similar artists if playing
		if ( my $artist = $players{$macaddress}->artist) {
			unshift @stations, "artist/$artist/similarartists";
		}
	}

	return @stations;

}

sub genStationNames {
	my $client = shift;
	my $selectedstation = shift;
	my $macaddress = $client->macaddress;
	my @stations;
	my @allstations;

	if (!$selectedstation) {
		#we want all of them
		@stations = genStationNamesLevel1($client);
	} else {
		push @stations, $selectedstation;
	}

	for my $station (@stations) {	
		if ( $station =~ m/user\//) {
			if ($players{$macaddress}->subscriber) {
				for (@lastfm_subscriber_options) {
					if ($_ ne personal or !$players{$macaddress}->disco) {
						push @allstations,"$station/$_";
					}
				}
			} else {
				push @allstations,"$station/$lastfm_subscriber_options[0]";
			}
		} else {
			push @allstations,$station;
		}
	}
	return @allstations;
}


1;


# Local Variables:
# tab-width:4
# indent-tabs-mode:t
# End:
