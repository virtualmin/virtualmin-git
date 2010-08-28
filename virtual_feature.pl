# Functions for the Git feature

do 'virtualmin-git-lib.pl';
$input_name = $module_name;
$input_name =~ s/[^A-Za-z0-9]/_/g;
&load_theme_library();

# feature_name()
# Returns a short name for this feature
sub feature_name
{
return $text{'feat_name'};
}

# feature_losing(&domain)
# Returns a description of what will be deleted when this feature is removed
sub feature_losing
{
return $text{'feat_losing'};
}

# feature_disname(&domain)
# Returns a description of what will be turned off when this feature is disabled
sub feature_disname
{
return $text{'feat_disname'};
}

# feature_label(in-edit-form)
# Returns the name of this feature, as displayed on the domain creation and
# editing form
sub feature_label
{
return $text{'feat_label'};
}

sub feature_hlink
{
return "label";
}

# feature_check()
# Returns undef if all the needed programs for this feature are installed,
# or an error message if not
sub feature_check
{
return &git_check();
}

# feature_depends(&domain)
# Returns undef if all pre-requisite features for this domain are enabled,
# or an error message if not
sub feature_depends
{
return $_[0]->{'web'} ? undef : $text{'feat_edepweb'};
}

# feature_clash(&domain)
# Returns undef if there is no clash for this domain for this feature, or
# an error message if so
sub feature_clash
{
return undef;
}

# feature_suitable([&parentdom], [&aliasdom], [&subdom])
# Returns 1 if some feature can be used with the specified alias and
# parent domains
sub feature_suitable
{
return $_[1] || $_[2] ? 0 : 1;		# not for alias domains
}

# feature_setup(&domain)
# Called when this feature is added, with the domain object as a parameter
sub feature_setup
{
local ($d) = @_;
&$virtual_server::first_print($text{'setup_git'});
&virtual_server::obtain_lock_web($d);
local $any;
$any++ if (&add_git_directives($d, $d->{'web_port'}));
$any++ if ($d->{'ssl'} &&
           &add_git_directives($d, $d->{'web_sslport'}));
if (!$any) {
	&$virtual_server::second_print(
		$virtual_server::text{'delete_noapache'});
	}
else {
	# Create needed directories ~/etc/ and ~/public_html/git
	local $passwd_file = &passwd_file($d);
	local $phd = &virtual_server::public_html_dir($d);
	if (!-d "$phd/git") {
		&virtual_server::make_dir_as_domain_user(
			$d, "$phd/git", 02755);
		}
	if (!-d "$d->{'home'}/etc") {
		&virtual_server::make_dir_as_domain_user(
			$d, "$d->{'home'}/etc", 0755);
		}

	# Create password files
	if (!-r $passwd_file) {
		&lock_file($passwd_file);
		&virtual_server::open_tempfile_as_domain_user(
			$d, PASSWD, ">$passwd_file", 0, 1);
		&virtual_server::close_tempfile_as_domain_user(
			$d, PASSWD);
		&virtual_server::set_permissions_as_domain_user(
			$d, 0755, $passwd_file);
		&unlock_file($passwd_file);
		}
	&$virtual_server::second_print($virtual_server::text{'setup_done'});
	&virtual_server::register_post_action(\&virtual_server::restart_apache);

	# Grant access to the domain's owner
	my $uinfo;
	if (!$d->{'parent'} &&
	    ($uinfo = &virtual_server::get_domain_owner($d))) {
		&$virtual_server::first_print($text{'setup_gituser'});
		&foreign_require("htaccess-htpasswd", "htaccess-lib.pl");
		local $un = &virtual_server::remove_userdom(
			$uinfo->{'user'}, $d);
		local $newuser = { 'user' => $un,
				   'enabled' => 1 };
		$newuser->{'pass'} = $uinfo->{'pass'};
		&virtual_server::write_as_domain_user($d,
			sub { &htaccess_htpasswd::create_user(
				$newuser, $passwd_file) });
		&$virtual_server::second_print(
			$virtual_server::text{'setup_done'});
		}
	}

# Set default limit from template
if (!exists($d->{$module_name."limit"})) {
        local $tmpl = &virtual_server::get_template($d->{'template'});
        $d->{$module_name."limit"} =
                $tmpl->{$module_name."limit"} eq "none" ? "" :
                 $tmpl->{$module_name."limit"};
        }

# Make sure /git isn't proxied
if (defined(&virtual_server::setup_noproxy_path)) {
	&virtual_server::setup_noproxy_path(
		$d, { }, undef, { 'path' => '/git/' }, 1);
	}

&virtual_server::release_lock_web($d);
}

# add_git_directives(&domain, port)
# Add Apache directives for DAV access to /git
sub add_git_directives
{
local ($d, $port) = @_;
local ($virt, $vconf) = &virtual_server::get_apache_virtual($d->{'dom'}, $port);
if ($virt) {
	local $lref = &read_file_lines($virt->{'file'});
	local ($locstart, $locend) =
		&find_git_lines($lref, $virt->{'line'}, $virt->{'eline'});
	local @lines;
	local $passwd_file = &passwd_file($d);
	local @norewrite;
	if ($apache::httpd_modules{'mod_rewrite'}) {
		@norewrite = ( "RewriteEngine off" );
		}
	if (!$locstart) {
		push(@lines,
			"<Location /git>",
			"DAV on",
			"AuthType Basic",
			"AuthName $d->{'dom'}",
			"AuthUserFile $passwd_file",
			"Require valid-user",
			"Satisfy Any",
			@norewrite,
		        "</Location>");
		}
	splice(@$lref, $virt->{'eline'}, 0, @lines);
	&flush_file_lines();
	undef(@apache::get_config_cache);
	return 1;
	}
else {
	return 0;
	}
}

# remove_git_directives(&domain, port)
# Delete Apache directives for the /git location
sub remove_git_directives
{
local ($d, $port) = @_;
local ($virt, $vconf) = &virtual_server::get_apache_virtual($d->{'dom'}, $port);
if ($virt) {
        local $lref = &read_file_lines($virt->{'file'});
        local ($locstart, $locend) =
                &find_git_lines($lref, $virt->{'line'}, $virt->{'eline'});
        if ($locstart) {
                splice(@$lref, $locstart, $locend-$locstart+1);
                }
        &flush_file_lines();
        undef(@apache::get_config_cache);
        return 1;
        }
else {
        return 0;
        }
}

# find_git_lines(&directives, start, end)
# Returns the start and end lines containing the <Location /git> block
sub find_git_lines
{
local ($dirs, $start, $end) = @_;
local ($locstart, $locend, $i);
for($i=$start; $i<=$end; $i++) {
        if ($dirs->[$i] =~ /^\s*<Location\s+\/git>/i && !$locstart) {
                $locstart = $i;
                }
        elsif ($dirs->[$i] =~ /^\s*<\/Location>/i && $locstart && !$locend) {
                $locend = $i;
                }
        }
return ($locstart, $locend);
}

# feature_modify(&domain, &olddomain)
# Called when a domain with this feature is modified
sub feature_modify
{
local ($d, $oldd) = @_;
&virtual_server::obtain_lock_web($d);
&virtual_server::release_lock_web($d);
}

# feature_delete(&domain)
# Called when this feature is disabled, or when the domain is being deleted
sub feature_delete
{
local ($d) = @_;
&$virtual_server::first_print($text{'delete_git'});
&virtual_server::obtain_lock_web($d);
local $any;
$any++ if (&remove_git_directives($d, $d->{'web_port'}));
$any++ if ($d->{'ssl'} &&
           &remove_git_directives($d, $d->{'web_sslport'}));
&virtual_server::release_lock_web($d);
if (!$any) {
	&$virtual_server::second_print(
		$virtual_server::text{'delete_noapache'});
	}
else {
	&$virtual_server::second_print($virtual_server::text{'setup_done'});
	&virtual_server::register_post_action(\&virtual_server::restart_apache);

	# Remove negative proxy for /git
	if (defined(&virtual_server::delete_noproxy_path)) {
		&virtual_server::delete_noproxy_path(
			$d, { }, undef, { 'path' => '/git/' });
		}
	}
}

# feature_webmin(&domain)
# Returns a list of webmin module names and ACL hash references to be set for
# the Webmin user when this feature is enabled
sub feature_webmin
{
local @doms = map { $_->{'dom'} } grep { $_->{$module_name} } @{$_[1]};
if (@doms) {
	return ( [ $module_name,
		   { 'dom' => join(" ", @doms),
		     'max' => $_[0]->{$module_name.'limit'},
		     'noconfig' => 1 } ] );
	}
else {
	return ( );
	}
}

# feature_limits_input(&domain)
# Returns HTML for editing limits related to this plugin
sub feature_limits_input
{
local ($d) = @_;
return undef if (!$d->{$module_name});
return &ui_table_row(&hlink($text{'limits_max'}, "limits_max"),
	&ui_opt_textbox($input_name."limit", $d->{$module_name."limit"},
			4, $virtual_server::text{'form_unlimit'},
			   $virtual_server::text{'form_atmost'}));
}

# feature_limits_parse(&domain, &in)
# Updates the domain with limit inputs generated by feature_limits_input
sub feature_limits_parse
{
local ($d, $in) = @_;
return undef if (!$d->{$module_name});
if ($in->{$input_name."limit_def"}) {
	delete($d->{$module_name."limit"});
	}
else {
	$in->{$input_name."limit"} =~ /^\d+$/ || return $text{'limit_emax'};
	$d->{$module_name."limit"} = $in->{$input_name."limit"};
	}
return undef;
}

# feature_links(&domain)
# Returns an array of link objects for webmin modules for this feature
sub feature_links
{
local ($d) = @_;
return ( { 'mod' => $module_name,
	   'desc' => $text{'links_link'},
	   'page' => 'index.cgi?show='.$d->{'dom'},
	   'cat' => 'services',
          } );
}

# feature_backup(&domain, file, &opts, &all-opts)
# XXX
sub feature_backup
{
local ($d, $file, $opts) = @_;
&$virtual_server::first_print($text{'feat_backup'});
# XXX
&$virtual_server::second_print($virtual_server::text{'setup_done'});
return 1;
}

# feature_restore(&domain, file, &opts, &all-opts)
# XXX
sub feature_restore
{
local ($d, $file, $opts) = @_;
&$virtual_server::first_print($text{'feat_restore'});
# XXX
&$virtual_server::second_print($virtual_server::text{'setup_done'});
return 1;
}

sub feature_backup_name
{
return $text{'feat_backup_name'};
}

# feature_validate(&domain)
# Checks if this feature is properly setup for the virtual server, and returns
# an error message if any problem is found
sub feature_validate
{
local ($d) = @_;
# XXX
return undef;
}

# mailbox_inputs(&user, new, &domain)
# Returns HTML for additional inputs on the mailbox form. These should be
# formatted to appear inside a table.
sub mailbox_inputs
{
local ($user, $new, $dom) = @_;
return undef if (!$dom || !$dom->{$module_name});
# XXX repo selection?
}

# mailbox_validate(&user, &olduser, &in, new, &domain)
# Validates inputs generated by mailbox_inputs, and returns either undef on
# success or an error message
sub mailbox_validate
{
local ($user, $olduser, $in, $new, $dom) = @_;
return undef if (!$dom || !$dom->{$module_name});
if ($in->{$input_name}) {
	# XXX
	}
return undef;
}

# mailbox_save(&user, &olduser, &in, new, &domain)
# Updates the user based on inputs generated by mailbox_inputs
sub mailbox_save
{
local ($user, $olduser, $in, $new, $dom) = @_;
return undef if (!$dom || !$dom->{$module_name});
# XXX
return $rv;
}

# mailbox_modify(&user, &old, &domain)
# Called when a user is modified by some method other than the edit user form
sub mailbox_modify
{
local ($user, $olduser, $dom) = @_;
return undef if (!$dom || !$dom->{$module_name});
# XXX
}

# mailbox_delete(&user, &domain)
# Removes any extra features for this user
sub mailbox_delete
{
local ($user, $dom) = @_;
return undef if (!$dom || !$dom->{$module_name});
# XXX
}

# mailbox_header(&domain)
# Returns a column header for the user display, or undef for none
sub mailbox_header
{
if ($_[0]->{$module_name}) {
	return $text{'mail_header'};
	}
else {
	return undef;
	}
}

# mailbox_column(&user, &domain)
# Returns the text to display in the column for some user
sub mailbox_column
{
local ($user, $dom) = @_;
# XXX
return undef;
}

# mailbox_defaults_inputs(&defs, &domain)
# Returns HTML for editing defaults for plugin-related settings for new
# users in this virtual server
sub mailbox_defaults_inputs
{
local ($defs, $dom) = @_;
if ($dom->{$module_name}) {
	local %defs;
	&read_file("$module_config_directory/defaults.$dom->{'id'}", \%defs);
	# XXX
	}
}

# mailbox_defaults_parse(&defs, &domain, &in)
# Parses the inputs created by mailbox_defaults_inputs, and updates a config
# file internal to this module to store them
sub mailbox_defaults_parse
{
local ($defs, $dom, $in) = @_;
if ($dom->{$module_name}) {
	local %defs;
	&read_file("$module_config_directory/defaults.$dom->{'id'}", \%defs);
	# XXX
	&write_file("$module_config_directory/defaults.$dom->{'id'}", \%defs);
	}
}

# template_input(&template)
# Returns HTML for editing per-template options for this plugin
sub template_input
{
local ($tmpl) = @_;
local $v = $tmpl->{$module_name."limit"};
$v = "none" if (!defined($v) && $tmpl->{'default'});
return &ui_table_row($text{'tmpl_limit'},
        &ui_radio($input_name."_mode",
                  $v eq "" ? 0 : $v eq "none" ? 1 : 2,
                  [ $tmpl->{'default'} ? ( ) : ( [ 0, $text{'default'} ] ),
                    [ 1, $text{'tmpl_unlimit'} ],
                    [ 2, $text{'tmpl_atmost'} ] ])."\n".
        &ui_textbox($input_name, $v eq "none" ? undef : $v, 10));
}

# template_parse(&template, &in)
# Updates the given template object by parsing the inputs generated by
# template_input. All template fields must start with the module name.
sub template_parse
{
local ($tmpl, $in) = @_;
if ($in->{$input_name.'_mode'} == 0) {
        $tmpl->{$module_name."limit"} = "";
        }
elsif ($in->{$input_name.'_mode'} == 1) {
        $tmpl->{$module_name."limit"} = "none";
        }
else {
        $in->{$input_name} =~ /^\d+$/ || &error($text{'tmpl_elimit'});
        $tmpl->{$module_name."limit"} = $in->{$input_name};
        }
}

1;

