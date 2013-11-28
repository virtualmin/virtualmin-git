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
local ($edit) = @_;
return $edit ? $text{'feat_label2'} : $text{'feat_label'};
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
local $phd = &virtual_server::public_html_dir($d);
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

# Setup gitweb if possible
&$virtual_server::first_print($text{'feat_gitweb'});
local $git = &has_command("git") || "git";
local $gitdir = -e "/usr/lib/git-core/git-rev-list" ? "/usr/lib/git-core" :
		$git =~ /^(.*)\// ? $1 : "/usr/bin";
local $src = &find_gitweb();
local $gitweb = "$phd/git/gitweb.cgi";
&virtual_server::copy_source_dest_as_domain_user($d, $src, $gitweb);
&virtual_server::set_permissions_as_domain_user($d, 0755, $gitweb);
my $lref = &virtual_server::read_file_lines_as_domain_user($d, $gitweb);
foreach my $l (@$lref) {
	if ($l =~ /^(our|my)\s+\$GIT\s+=/) {
		$l = "$1 \$GIT = '$git';";
		}
	elsif ($l =~ /^(our|my)\s+\$gitbin\s+=/) {
		$l = "$1 \$gitbin = '$gitdir';";
		}
	if ($l =~ /^(our|my)\s+\$projectroot\s+=/) {
		$l = "$1 \$projectroot = '$phd/git';";
		}
	if ($l =~ /^(our|my)\s+\$GITWEB_CONFIG\s+=/) {
		$l = "$1 \$GITWEB_CONFIG = '';";
		}
	if ($l =~ /^(our|my)\s+\$git_base_url\s+=/) {
		$l = "$1 \$git_base_url = 'http://$d->{'dom'}/git';";
		}
	if ($l =~ /^(our|my)\s+\$snapshots_url\s+=/) {
		$l = "$1 \$snapshots_url = 'http://$d->{'dom'}/git';";
		}
	}
&virtual_server::flush_file_lines_as_domain_user($d, $gitweb);
foreach my $src (&find_gitweb_data()) {
	local $gitfile = $src;
	$gitfile =~ s/^.*\///;
	$gitfile = "$phd/git/$gitfile";
	&virtual_server::copy_source_dest_as_domain_user($d, $src, $gitfile);
	}
&$virtual_server::second_print($virtual_server::text{'setup_done'});

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
		    "Satisfy All",
		    "RedirectMatch ^/git\$ http://$d->{'dom'}/git/gitweb.cgi",
		    "RedirectMatch ^/git/\$ http://$d->{'dom'}/git/gitweb.cgi",
		    @norewrite,
		    "AddHandler cgi-script .cgi",
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
	}

# Remove gitweb.cgi
local $phd = &virtual_server::public_html_dir($d);
&virtual_server::unlink_file_as_domain_user($d, "$phd/git/gitweb.cgi");
foreach my $gitfile (&find_gitweb_data()) {
	$gitfile =~ s/^.*\///;
        $gitfile = "$phd/git/$gitfile";
	&virtual_server::unlink_file_as_domain_user($d, $gitfile);
	}

# Remove negative proxy for /git
if (defined(&virtual_server::delete_noproxy_path)) {
	&virtual_server::delete_noproxy_path(
		$d, { }, undef, { 'path' => '/git/' });
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

sub feature_modules
{
return ( [ $module_name, $text{'feat_module'} ] );
}

# feature_backup(&domain, file, &opts, &all-opts)
# Backup all Git repositories and the users file
sub feature_backup
{
local ($d, $file, $opts) = @_;
&$virtual_server::first_print($text{'feat_backup'});

# Copy actual repositories
local $phd = &virtual_server::public_html_dir($d);
local $tar = &virtual_server::get_tar_command();
local $out = &backquote_command("cd ".quotemeta("$phd/git")." && ".
                                "$tar cf ".quotemeta($file)." . 2>&1");
if ($?) {
        &$virtual_server::second_print(&text('feat_tar', "<pre>$out</pre>"));
        return 0;
        }

# Copy users file
local $pfile = &passwd_file($_[0]);
if (!-r $pfile) {
        &$virtual_server::second_print($text{'feat_nopfile'});
        return 0;
        }
&copy_source_dest($pfile, $file."_users");

&$virtual_server::second_print($virtual_server::text{'setup_done'});
return 1;
}

# feature_restore(&domain, file, &opts, &all-opts)
# Restore Git repositories and the users file
sub feature_restore
{
local ($d, $file, $opts) = @_;
&$virtual_server::first_print($text{'feat_restore'});

# Extract tar file of repositories (deleting old ones first)
local $phd = &virtual_server::public_html_dir($d);
local $tar = &virtual_server::get_tar_command();
&execute_command("rm -rf ".quotemeta("$phd/git")."/*");
local ($out, $ex) = &virtual_server::run_as_domain_user($d,
        "cd ".quotemeta("$phd/git")." && $tar xf ".quotemeta($file)." 2>&1");
if ($ex) {
        &$virtual_server::second_print(&text('feat_untar', "<pre>$out</pre>"));
        return 0;
        }

# Fix repo permissions
foreach my $rep (&list_reps($d)) {
	&set_rep_permissions($d, $rep);
	}

# Copy users file
local $pfile = &passwd_file($d);
local ($ok, $out) = &virtual_server::copy_source_dest_as_domain_user(
                $d, $file."_users", $pfile);
if (!$ok) {
        &$virtual_server::second_print(&text('feat_copypfile2', $out));
        return 0;
        }

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
local $passwd_file = &passwd_file($d);
-r $passwd_file || return &text('feat_evalidatefile', "<tt>$passwd_file</tt>");
local ($virt, $vconf) = &virtual_server::get_apache_virtual($d->{'dom'}, $port);
$virt || return &virtual_server::text('validate_eweb', $d->{'dom'});
local $lref = &read_file_lines($virt->{'file'});
local ($locstart, $locend) =
        &find_git_lines($lref, $virt->{'line'}, $virt->{'eline'});
$locstart || return &text('feat_evalidateloc');
local $phd = &virtual_server::public_html_dir($d);
-d "$phd/git" || return &text('feat_evalidategit', "$phd/git");
return undef;
}

# mailbox_inputs(&user, new, &domain)
# Returns HTML for additional inputs on the mailbox form. These should be
# formatted to appear inside a table.
sub mailbox_inputs
{
local ($user, $new, $dom) = @_;
return undef if (!$dom || !$dom->{$module_name});
local $un = &virtual_server::remove_userdom($user->{'user'}, $dom);
local $suser;
if (!$new) {
	local @users = &list_users($dom);
	($suser) = grep { $_->{'user'} eq $un } @users;
	}
local $main::ui_table_cols = 2;
local @reps = &list_reps($dom);
local @rwreps;
foreach $r (@reps) {
	local @rusers = &list_rep_users($dom, $r);
	local ($ruser) = grep { $_->{'user'} eq $un } @rusers;
	if ($ruser) {
		push(@rwreps, $r->{'rep'});
		}
	}
local %defs;
&read_file("$module_config_directory/defaults.$dom->{'id'}", \%defs);
if (!$suser && !@rwreps) {
	# Use default repositories
	@rwreps = split(/\s+/, $defs{'reps'});
	}
@rwreps = sort { $a cmp $b } @rwreps;
@reps = sort { $a->{'rep'} cmp $b->{'rep'} } @reps;
local @inputs = ( $input_name."_rwreps_opts", $input_name."_rwreps_vals",
		  $input_name."_rwreps_add", $input_name."_rwreps_remove",
		  $input_name."_roreps_opts", $input_name."_roreps_vals",
		  $input_name."_roreps_add", $input_name."_roreps_remove", );
local $hasuser = $suser || $new && $defs{'git'};
local $dis = $hasuser ? 0 : 1;
local $jsenable = &js_disable_inputs([ ], \@inputs, "onClick");
local $jsdisable = &js_disable_inputs(\@inputs, [ ], "onClick");
return &ui_table_row(&hlink($text{'mail_git'}, "git"),
		     &ui_radio($input_name, $hasuser ? 1 : 0,
			       [ [ 1, $text{'yes'}, $jsenable ],
				 [ 0, $text{'no'}, $jsdisable ] ])).
       &ui_table_row(&hlink($text{'mail_reps'}, "reps"),
		     &ui_multi_select(
			$input_name."_rwreps",
			[ map { [ $_, $_ ] } @rwreps ],
			[ map { [ $_->{'rep'}, $_->{'rep'} ] } @reps ],
			3, 0, $hasuser ? 0 : 1,
			$text{'mail_repsopts'}, $text{'mail_repsin'}));
}

# mailbox_validate(&user, &olduser, &in, new, &domain)
# Validates inputs generated by mailbox_inputs, and returns either undef on
# success or an error message
sub mailbox_validate
{
local ($user, $olduser, $in, $new, $dom) = @_;
return undef if (!$dom || !$dom->{$module_name});
if ($in->{$input_name}) {
	local @users = &list_users($dom);
	local $un = &virtual_server::remove_userdom($user->{'user'}, $dom);
	local $oun = &virtual_server::remove_userdom($olduser->{'user'}, $dom);
	local ($suser) = grep { $_->{'user'} eq $oun } @users;

	# Make sure Git user doesn't clash
	if ($new || $user->{'user'} ne $olduser->{'user'}) {
		local ($clash) = grep { $_->{'user'} eq $un } @users;
		return &text('mail_clash', $un) if ($clash);
		}
	}
return undef;
}

# mailbox_save(&user, &olduser, &in, new, &domain)
# Updates the user based on inputs generated by mailbox_inputs
sub mailbox_save
{
local ($user, $olduser, $in, $new, $dom) = @_;
return undef if (!$dom || !$dom->{$module_name});
&foreign_require("htaccess-htpasswd", "htaccess-lib.pl");
local @users = &list_users($dom);
local $suser;
local $un = &virtual_server::remove_userdom($user->{'user'}, $dom);
local $oun = &virtual_server::remove_userdom($olduser->{'user'}, $dom);
local $rv;

&lock_file(&passwd_file($dom));
if (!$new) {
	($suser) = grep { $_->{'user'} eq $oun } @users;
	}
if ($in->{$input_name} && !$suser) {
	# Add the user
	local $newuser = { 'user' => $un,
			   'enabled' => 1 };
	&set_user_password($newuser, $user, $dom);
	&virtual_server::write_as_domain_user($dom,
		sub { &htaccess_htpasswd::create_user(
			$newuser, &passwd_file($dom)) });
	&virtual_server::set_permissions_as_domain_user(
		$dom, 0755, &passwd_file($dom));
	$rv = 1;
	}
elsif (!$in->{$input_name} && $suser) {
	# Delete the user
	&virtual_server::write_as_domain_user($dom,
		sub { &htaccess_htpasswd::delete_user($suser) });
	$rv = 0;
	}
elsif ($in->{$input_name} && $suser) {
	# Update the user
	$suser->{'user'} = $un;
	if ($user->{'passmode'} == 3) {
		$suser->{'pass'} = $user->{'pass'};
		}
	&virtual_server::write_as_domain_user($dom,
		sub { &htaccess_htpasswd::modify_user($suser) });
	$rv = 1;
	}
&unlock_file(&passwd_file($dom));

# Update list of repositories user has access to
local %canrwreps = map { $_, 1 } split(/\r?\n/, $in->{$input_name."_rwreps"});
if (!$in->{$input_name}) {
	%canrwreps = ( );
	}
foreach my $r (&list_reps($dom)) {
	local @rusers = &list_rep_users($dom, $r);
	local ($ruser) = grep { $_->{'user'} eq $oun } @rusers;
	@rusers = grep { $_ ne $ruser } @rusers;
	if ($canrwreps{$r->{'rep'}}) {
		push(@rusers, { 'user' => $un,
				'perms' => 'rw' });
		}
	if ($ruser || $canrwreps{$r->{'rep'}}) {
		# Only save if user was there before or is now
		&save_rep_users($dom, $r, \@rusers);
		}
	}

return $rv;
}

# mailbox_modify(&user, &old, &domain)
# Called when a user is modified by some method other than the edit user form
sub mailbox_modify
{
local ($user, $olduser, $dom) = @_;
return undef if (!$dom || !$dom->{$module_name});
&foreign_require("htaccess-htpasswd", "htaccess-lib.pl");
local @users = &list_users($dom);
local $un = &virtual_server::remove_userdom($user->{'user'}, $dom);
local $oun = &virtual_server::remove_userdom($olduser->{'user'}, $dom);
local ($suser) = grep { $_->{'user'} eq $oun } @users;
return undef if (!$suser);

&lock_file(&passwd_file($dom));

if ($un ne $oun && $suser) {
	# User was re-named
	$suser->{'user'} = $un;
	&htaccess_htpasswd::modify_user($suser);
	foreach my $r (&list_reps($dom)) {
		local @rusers = &list_rep_users($dom, $r->{'rep'});
		local ($ruser) = grep { $_->{'user'} eq $oun } @rusers;
		if ($ruser) {
			$ruser->{'user'} = $un;
			&save_rep_users($dom, $r, \@rusers);
			}
		}
	}

if ($user->{'passmode'} == 3) {
	# Password was changed
	$suser->{'pass'} = $user->{'pass_crypt'} ||
	    &htaccess_htpasswd::encrypt_password($user->{'plainpass'});
	&virtual_server::write_as_domain_user($dom,
		sub { &htaccess_htpasswd::modify_user($suser) });
	}

&unlock_file(&passwd_file($dom));
}

# mailbox_delete(&user, &domain)
# Removes any extra features for this user
sub mailbox_delete
{
local ($user, $dom) = @_;
return undef if (!$dom || !$dom->{$module_name});
&foreign_require("htaccess-htpasswd", "htaccess-lib.pl");

&lock_file(&passwd_file($dom));
local @users = &list_users($dom);
local $un = &virtual_server::remove_userdom($user->{'user'}, $dom);
local ($suser) = grep { $_->{'user'} eq $un } @users;
if ($suser) {
        &virtual_server::write_as_domain_user($dom,
                sub { &htaccess_htpasswd::delete_user($suser) });
        }

# Remove from all repositories
foreach $r (&list_reps($dom)) {
        local @rusers = &list_rep_users($dom, $r->{'rep'});
        local ($ruser) = grep { $_->{'user'} eq $un } @rusers;
        local @newrusers = grep { $_ ne $ruser } @rusers;
        if (@newrusers != @rusers) {
                &save_rep_users($dom, $r, \@newrusers);
                }
        }

&unlock_file(&passwd_file($dom));
}

# mailbox_header(&domain)
# Returns a column header for the user display, or undef for none
sub mailbox_header
{
local ($d) = @_;
if ($d->{$module_name}) {
	@column_users = &list_users($d);
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
local $un = &virtual_server::remove_userdom($user->{'user'}, $dom);
local ($duser) = grep { $_->{'user'} eq $un } @column_users;
return $duser ? $text{'yes'} : $text{'no'};
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
        local @reps = &list_reps($dom);
        return &ui_table_row($text{'mail_git'},
                &ui_yesno_radio($input_name, int($defs{'git'})))."\n".
               &ui_table_row($text{'mail_reps'},
                     &ui_select($input_name."_reps",
                                [ split(/\s+/, $defs{'reps'}) ],
                                [ map { [ $_->{'rep'}, $_->{'rep'} ] } @reps ],
                                3, 1));
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
	$defs{'git'} = $in->{$input_name};
        $defs{'reps'} = join(" ", split(/\0/, $in->{$input_name."_reps"}));
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

