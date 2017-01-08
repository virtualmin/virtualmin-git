#!/usr/local/bin/perl
# Show all Git repositories for this user
use strict;
use warnings;
our (%access, %text, %in);
our $module_name;

require './virtualmin-git-lib.pl';
&ReadParse();
my $showd;
if ($in{'show'}) {
	$showd = &virtual_server::get_domain_by("dom", $in{'show'});
	$showd || &error($text{'index_eshow'});
	}
&ui_print_header($showd ? &virtual_server::domain_in($showd) : undef,
		 $text{'index_title'}, "", undef, 1, 1);

# Check if Git is installed
my $err = &git_check();
if ($err) {
	&ui_print_endpage($err);
	}

# Check if plugin is enabled
no warnings "once";
if (&indexof($module_name, @virtual_server::plugins) < 0) {
	if (&virtual_server::can_edit_templates()) {
		my $cgi = $virtual_server::module_info{'version'} >= 3.47 ?
			"edit_newfeatures.cgi" : "edit_newplugins.cgi";
		&ui_print_endpage(&text('index_eplugin',
			"../virtual-server/$cgi"));
		}
	else {
		&ui_print_endpage($text{'index_eplugin2'});
		}
	}
use warnings "once";

# Show repositories for Virtualmin domains visible to the current user
my ($domcount, $accesscount);
my (@reps, @mydoms);
foreach my $d ($in{'show'} ? ( $showd ) : &virtual_server::list_domains()) {
	$domcount++;
	next if (!&can_edit_domain($d));
	$accesscount++;
	next if (!$d->{$module_name});
	push(@reps, &list_reps($d));
	push(@mydoms, $d);
	}
if (!@mydoms) {
	&ui_print_endpage(!$domcount ? $text{'index_edoms2'} :
			  !$accesscount ? $text{'index_edoms'} :
					  $text{'index_edoms3'});
	}

# Build table of repositories
my @table;
foreach my $r (@reps) {
	my $dom = $r->{'dom'}->{'dom'};
	my $proto = $r->{'dom'}->{'ssl'} ? "https" : "http";
	my $url = "$proto://$r->{'dom'}->{'dom'}/git/gitweb.cgi?p=".
               &urlize("$r->{'rep'}.git");
	my $ur = &urlize($r->{'rep'}."\@".$r->{'dom'}->{'id'});
	my @actions = (
		&ui_link("delete.cgi?show=$in{'show'}&rep=".$ur,
			 $text{'delete'}),
		&ui_link($url, $text{'index_browse'}, undef, "target=_blank"),
		&ui_link("help.cgi?show=$in{'show'}&dom=$r->{'dom'}->{'id'}&".
			 "rep=$r->{'rep'}", $text{'index_help'}),
		);
	push(@table, [ $r->{'rep'}, $showd ? ( ) : ( $dom ),
		       $r->{'desc'}, $r->{'dir'}, &ui_links_row(\@actions) ]);
	}

# Show table of repos
if ($access{'max'} && $access{'max'} > @reps) {
	print "<b>",&text('index_canadd0', $access{'max'}-@reps),
	      "</b><p>\n";
	}
print &ui_form_columns_table(
	"delete.cgi",
	undef,
	0,
	undef,
	[ [ 'show', $in{'show'} ] ],
	[ $text{'index_rep'},
	  $showd ? ( ) : ( $text{'index_dom'} ),
	  $text{'index_desc'},
	  $text{'index_dir'},
	  $text{'index_action'} ],
	100,
	\@table,
	undef,
	0,
	undef,
	$text{'index_none'});

print "<p>\n";
if ($access{'max'} && @reps >= $access{'max'}) {
	# Cannot add any more
	print $text{'index_max'},"<p>\n";
	}
else {
	# Show form to add a repository
	print &ui_form_start("add.cgi");
	print &ui_hidden("show", $in{'show'});
	print &ui_table_start($text{'index_header'}, undef, 2,
			      [ "width=30% nowrap" ]);

	# Repo name
	print &ui_table_row($text{'index_rep'},
			    &ui_textbox("rep", undef, 20), 1);

	# Description
	print &ui_table_row($text{'index_desc'},
	    &ui_textbox("desc", $showd ? "Git repository for $showd->{'owner'}"
				       : "My Git repository", 40), 1);

	# In domain
	print &ui_table_row($text{'index_dom'},
		    &ui_select("dom", undef,
			[ map { [ $_->{'id'}, $_->{'dom'} ] } @mydoms ]));

	# Users to grant
	my @unames;
	if ($showd) {
		foreach my $u (&virtual_server::list_domain_users(
				$showd, 0, 1, 1, 1)) {
			push(@unames, &virtual_server::remove_userdom(
					$u->{'user'}, $showd));
			}
		}
	if (@unames) {
		print &ui_table_row($text{'index_grant'},
			&ui_multi_select(
			    "users",
			    !$showd || $showd->{'parent'} ? [ ] :
				[ [ $showd->{'user'}, $showd->{'user'} ] ],
			    [ map { [ $_, $_ ] } @unames ],
			    5, 0, 0,
			    $text{'index_allusers'},
			    $text{'index_grantusers'},
			    ));
		}

	# Allow anonymous access
	print &ui_table_row($text{'index_anonro'},
		&ui_yesno_radio("anon", 0));

	print &ui_table_end();
	print &ui_submit($text{'create'});
	print &ui_form_end();
	}

&ui_print_footer("/", $text{'index'});

