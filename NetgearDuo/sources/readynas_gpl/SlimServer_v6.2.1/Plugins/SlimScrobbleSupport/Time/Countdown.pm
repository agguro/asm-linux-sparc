                           
# Countdown.pm 
# Copyright Stewart Loving-Gibbard (sloving-gibbard@uswest.net) March 2003
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License,
# version 2.

# This is a simple module to provide a countdown timer that can be started,
# stopped, and reset. Time remaining and time elapsed can be queried at
# any point.

use strict;

# If I'm not supposed to go into the Time:: namespace without clearance,
# someone please tell me!

package Time::Countdown;

# I really don't understand OO Perl very well - actually, the
# whole idea makes me queasy - so if you see obvious problems,
# please tell me & feel free tofix.

# Stewart Loving-Gibbard
# sloving-gibbard@uswest.net

use Time::HiRes;
use Time::Stopwatch;

sub new()
{
   my $invocant = shift;
   my $self = bless({}, ref $invocant || $invocant);

   # My stopwatch object
   $self->{myStopwatch} = Time::Stopwatch->new;

   # Clear the Countdown
   $self->reset(0);

   return $self;
}

# Reset the Countdown and get it ready to run.
# Pass in number of seconds for Countdown.
# When ready, start the countdown with run().
sub reset()
{
   my $self = shift;

   # Time in seconds the Countdown should run for
   $self->{timeForCountdownToRun} = shift;

   # Clear our stopwatch
   $self->{myStopwatch}->clear();
}


# Start the Countdown running after a reset or re-running after
# a pause.
sub run()
{
   my $self = shift;
   
   $self->{myStopwatch}->start();
}


# Pause the Countdown. To restart it again, use run().
sub pause()
{
   my $self = shift;

   $self->{myStopwatch}->stop();

}


# Has this Countdown completed?
sub hasCountdownCompleted
{
   my $self = shift;

   return ($self->getRemainingTime() eq 0);
}


# Get the total amount the Countdown will run - the original
# value given for Reset().
sub getCountdownTime()
{
   my $self = shift;

   return $self->{timeForCountdownToRun};
}


# Get the elapsed time in the Countdown. When the Countdown has
# completed it will return the original value given to reset().
sub getElapsedTime()
{
   my $self = shift;

   # Get the time we've run so far.
   my $elapsedTime = $self->{myStopwatch}->getElapsedTime();

   # If we didn't do this it would be behaving more like a stopwatch, and I've
   # written a separate class for that.
   if ($elapsedTime > $self->{timeForCountdownToRun})
   {
      $elapsedTime = $self->{timeForCountdownToRun}
   }

   return $elapsedTime;
}


# Get the remaining time in the Countdown 
sub getRemainingTime()
{
   my $self = shift;

   return ( $self->{timeForCountdownToRun} - $self->getElapsedTime() );
}


# Packages must return true
1;

