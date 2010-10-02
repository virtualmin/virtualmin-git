#!/usr/local/bin/perl
# Show all Git repositories for this user

require './virtualmin-git-lib.pl';
&ReadParse();
if ($in{'show'}) {
	$showd = &virtual_server::get_domain_by("dom", $in{'show'});
	$showd || &error($text{'index_eshow'});
	}
&ui_print_header($showd ? &virtual_server::domain_in($showd) : undef,
		 $text{'index_title'}, "", undef, 1, 1);

# Check if Git is installed
$err = &git_check();
if ($err) {
	&ui_print_endpage($err);
	}

# Check if plugin is enabled
if (&indexof($module_name, @virtual_server::plugins) < 0) {
	if (&virtual_server::can_edit_templates()) {
		$cgi = $virtual_server::module_info{'version'} >= 3.47 ?
			"edit_newfeatures.cgi" : "edit_newplugins.cgi";
		&ui_print_endpage(&text('index_eplugin',
			"../virtual-server/$cgi"));
		}
	else {
		&ui_print_endpage($text{'index_eplugin2'});
		}
	}

# Show repositories for Virtualmin domains visible to the current user
foreach $d ($in{'show'} ? ( $showd ) : &virtual_server::list_domains()) {
	$domcount++;
	next if (!&can_edit_domain($d));
	$accesscount++;
	next if (!$d->{$module_name});
	$svncount++;
	push(@reps, &list_reps($d));
	push(@mydoms, $d);
	}
if (!@mydoms) {
	&ui_print_endpage(!$domcount ? $text{'index_edoms2'} :
			  !$accesscount ? $text{'index_edoms'} :
					  $text{'index_edoms3'});
	}

# Build table of repositories
@table = ( );
foreach $r (@reps) {
	$dom = $r->{'dom'}->{'dom'};
	@actions = (
		&ui_submit($text{'delete'},
			   $r->{'rep'}."\@".$r->{'dom'}->{'id'}),
		&ui_submit($text{'index_browse'},
			   $r->{'rep'}."\@".$r->{'dom'}->{'id'}),
		&ui_submit($text{'index_help'},
			   $r->{'rep'}."\@".$r->{'dom'}->{'id'}),
		);
	push(@table, [ $r->{'rep'}, $showd ? ( ) : ( $dom ),
		       $r->{'desc'}, $r->{'dir'}, join(" ", @actions) ]);
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
	@unames = ( );
	if ($showd) {
		foreach $u (&virtual_server::list_domain_users(
				$showd, 0, 1, 1, 1)) {
			push(@unames, &virtual_server::remove_userdom(
					$u->{'user'}, $showd));
			}
		}
	if (@unames) {
		print &ui_table_row($text{'index_grant'},
			&ui_multi_select(
			    "users",
			    [ ],
			    [ map { [ $_, $_ ] } @unames ],
			    5, 0, 0,
			    $text{'index_allusers'},
			    $text{'index_grantusers'},
			    ));
		}

	print &ui_table_end();
	print &ui_submit($text{'create'});
	print &ui_form_end();
	}

&ui_print_footer("/", $text{'index'});

