#!/usr/local/bin/perl
# Delete one Git repository
use strict;
use warnings;
our (%text, %in);

require './virtualmin-git-lib.pl';
&ReadParse();

# Get the domain and repository
my $repdom = $in{'rep'};
my ($repname, $id) = split(/\@/, $repdom);
my $dom = &virtual_server::get_domain($id);
&can_edit_domain($dom) || &error($text{'add_edom'});
my @reps = &list_reps($dom);
my ($rep) = grep { $_->{'rep'} eq $repname } @reps;
$rep || &error($text{'delete_erep'});

if ($in{'confirm'}) {
	# Do it!
	&delete_rep($dom, $rep);
	&webmin_log("delete", "repo", $repname,
		    { 'dom' => $dom->{'dom'} });
	&redirect("index.cgi?show=$in{'show'}");
	}
else {
	# Ask first
	&ui_print_header(&virtual_server::domain_in($dom),
			 $text{'delete_title'}, "");

	print "<center>\n";
	my $size = &disk_usage_kb($rep->{'dir'});
	print &ui_form_start("delete.cgi");
	print &ui_hidden("rep", $repdom);
	print &ui_hidden("action", "delete");
	print &ui_hidden("show", $in{'show'});
	print &text('delete_rusure', "<tt>$repname</tt>",
		    &nice_size($size*1024)),"<p>\n";
	print &ui_form_end([ [ "confirm", $text{'delete_ok'} ] ]);
	print "</center>\n";

	&ui_print_footer("index.cgi?show=$in{'show'}",
			 $text{'index_return'});
	}
