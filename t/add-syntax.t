use Test::Strict tests => 3;                      # last test to print

syntax_ok( 'add.cgi' );
strict_ok( 'add.cgi' );
warnings_ok( 'add.cgi' );
