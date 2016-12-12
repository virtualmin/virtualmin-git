use Test::Strict tests => 3;                      # last test to print

syntax_ok( 'help.cgi' );
strict_ok( 'help.cgi' );
warnings_ok( 'help.cgi' );
