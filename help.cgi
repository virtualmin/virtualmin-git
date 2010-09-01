#!/usr/local/bin/perl
# Show commands for using some repository

require './virtualmin-git-lib.pl';
&ReadParse();

# Get the domain and repository
$dom = &virtual_server::get_domain($in{'dom'});
&can_edit_domain($dom) || &error($text{'add_edom'});
@reps = &list_reps($dom);
($rep) = grep { $_->{'rep'} eq $in{'rep'} } @reps;
$rep || &error($text{'delete_erep'});
@users = &list_rep_users($dom, $rep);
$user = @users ? $users[0]->{'user'} : "\$username";

&ui_print_header(&virtual_server::domain_in($dom), $text{'help_title'}, "");

&print_git_commands($text{'help_init'},
	"mkdir ~/$rep->{'rep'}",
	"cd ~/$rep->{'rep'}",
	"git init");

&print_git_commands($text{'help_remote'},
	"cd ~/$rep->{'rep'}",
	"git config remote.upload.url http://$user\@$dom->{'dom'}/git/$rep->{'rep'}.git/",
	"echo machine $dom->{'dom'} login $user password \$password &gt;&gt; ~/.netrc");

&print_git_commands($text{'help_first'},
	"cd ~/$rep->{'rep'}",
	"git --bare init",
	"echo hello &gt; hello.txt",
	"git add hello.txt",
	"git commit -m 'initial checkin'",
	"git push upload master");

&print_git_commands($text{'help_pull'},
	"cd ~/$rep->{'rep'}",
	"git pull upload master");

&print_git_commands($text{'help_push'},
	"cd ~/$rep->{'rep'}",
	"git add somefile.pl",
	"git commit",
	"git push upload master");

&ui_print_footer("index.cgi?show=$in{'show'}",
		 $text{'index_return'});

sub print_git_commands
{
my ($header, @lines) = @_;
print "<b>$header</b><p>\n";
print &ui_table_start(undef, "width=100%", 2);
print "<pre>".join("\n", @lines)."</pre>\n";
print &ui_table_end();
print "<p>\n";
}
