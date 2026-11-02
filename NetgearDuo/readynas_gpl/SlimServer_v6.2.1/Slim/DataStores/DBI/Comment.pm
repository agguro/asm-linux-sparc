package Slim::DataStores::DBI::Comment;

# $Id: Comment.pm 3901 2005-08-08 23:26:43Z dsully $

use strict;
use base 'Slim::DataStores::DBI::DataModel';

{
	my $class = __PACKAGE__;

	$class->table('comments');

	$class->columns(Primary => qw/id/);

	$class->columns(Essential => qw/track value/);

	$class->has_a(track => 'Slim::DataStores::DBI::Track');

	$class->add_constructor('commentsOf' => 'track = ?');
}

1;

__END__


# Local Variables:
# tab-width:4
# indent-tabs-mode:t
# End:
