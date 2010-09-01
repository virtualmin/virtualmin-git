#!/usr/local/bin/perl
# Delete one Git repository

require './virtualmin-git-lib.pl';
&ReadParse();

# Get the domain and repository
($repdom) = grep { $_ ne "confirm" && $_ ne "show" } (keys %in);
($repname, $id) = split(/\@/, $repdom);
$dom = &virtual_server::get_domain($id);
&can_edit_domain($dom) || &error($text{'add_edom'});
@reps = &list_reps($dom);
($rep) = grep { $_->{'rep'} eq $repname } @reps;
$rep || &error($text{'delete_erep'});

$button = $in{$repdom};
if ($button eq &entities_to_ascii($text{'delete'})) {
	# Deleting repo
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
		$size = &disk_usage_kb($rep->{'dir'});
		print &ui_form_start("delete.cgi");
		print &ui_hidden($repdom, $in{$repdom});
		print &ui_hidden("show", $in{'show'});
		print &text('delete_rusure', "<tt>$repname</tt>",
			    &nice_size($size*1024)),"<p>\n";
		print &ui_form_end([ [ "confirm", $text{'delete_ok'} ] ]);
		print "</center>\n";

		&ui_print_footer("index.cgi?show=$in{'show'}",
				 $text{'index_return'});
		}
	}
elsif ($button eq &entities_to_ascii($text{'index_browse'})) {
	# Redirect to gitweb
	&redirect("http://$dom->{'dom'}/git/gitweb.cgi?p=".
		  &urlize("$rep->{'rep'}.git"));
	}
elsif ($button eq &entities_to_ascii($text{'index_help'})) {
	# Redirect to help page
	&redirect("help.cgi?dom=$dom->{'id'}&rep=".&urlize($rep->{'rep'}).
		  "&show=".&urlize($in{'show'}));
	}
else {
	&error($text{'delete_emode'});
	}

