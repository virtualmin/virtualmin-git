use Test::Strict tests => 3;                      # last test to print

syntax_ok( 'postinstall.pl' );
strict_ok( 'postinstall.pl' );
warnings_ok( 'postinstall.pl' );
