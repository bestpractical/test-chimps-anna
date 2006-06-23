#!perl -T

use Test::More tests => 1;

BEGIN {
	use_ok( 'Test::Chimps::Anna' );
}

diag( "Testing Test::Chimps::Anna $Test::Chimps::Anna::VERSION, Perl $], $^X" );
