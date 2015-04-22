
BEGIN { push(@INC, ".."); };
eval "use WebminCore;";
&init_config();
&foreign_require("virtual-server", "virtual-server-lib.pl");
%access = &get_module_acl();

sub can_edit_domain
{
local ($d) = @_;
return &virtual_server::can_edit_domain($d);
}

# list_reps(&domain)
# Returns a list of all repositories in some domain
sub list_reps
{
local ($d) = @_;
local @rv;
local $dir = &virtual_server::public_html_dir($d)."/git";
opendir(DIR, $dir);
while(my $f = readdir(DIR)) {
        if ($f =~ /^(\S+)\.git$/) {
                local $rep = { 'dom' => $d,
                               'rep' => $1,
                               'dir' => "$dir/$f" };
		$rep->{'desc'} = &virtual_server::read_file_contents_as_domain_user($d, $rep->{'dir'}."/description");
		push(@rv, $rep);
                }
        }
closedir(DIR);
return @rv;
}

sub git_check
{
return &text('feat_echeck', "<tt>$config{'git'}</tt>")
        if (!&has_command($config{'git'}));
return undef;
}

# passwd_file(&domain)
# Returns the path to the Git password file for a domain
sub passwd_file
{
local ($d) = @_;
if ($config{'passfile'}) {
        return "$d->{'home'}/$config{'passfile'}";
        }
else {
        return "$d->{'home'}/etc/git.basic.passwd";
        }
}

# create_rep(&domain, &rep, description, [allow-anonymous])
# Creates a new Git repository in some domain
sub create_rep
{
local ($d, $rep, $desc, $anon) = @_;
local $git = &has_command($config{'git'});
$git || return "Git command $config{'git'} was not found!";

# Make the dir and setup a repo in it
$rep->{'dir'} = &virtual_server::public_html_dir($d)."/git/$rep->{'rep'}.git";
if (!-d $rep->{'dir'}) {
	&virtual_server::make_dir_as_domain_user($d, $rep->{'dir'});
	}
local $cmd = "cd ".quotemeta($rep->{'dir'})." && $git --bare init";
local ($out, $ex) = &virtual_server::run_as_domain_user($d, $cmd);
if ($ex) {
	return $out;
	}
&set_rep_permissions($d, $rep);

# Create a <Location> block for the repo
&virtual_server::obtain_lock_web($d);
&add_git_repo_directives($d, $d->{'web_port'}, $rep, $anon);
&add_git_repo_directives($d, $d->{'web_sslport'}, $rep, $anon) if ($d->{'ssl'});
&virtual_server::release_lock_web($d);

# Run update-server-info as Apache
local $webuser = &virtual_server::get_apache_user($d);
local $qdir = quotemeta($rep->{'dir'});
&system_logged(&command_as_user($webuser, 0, 
				"cd $qdir && $git update-server-info"));

# Set description file
if ($desc) {
	local $descfile = "$rep->{'dir'}/description";
	&virtual_server::open_tempfile_as_domain_user($d, DESC, ">$descfile");
	&print_tempfile(DESC, $desc."\n");
	&virtual_server::close_tempfile_as_domain_user($d, DESC);
	}

# Set domain owner name in config file
local $cfile = "$rep->{'dir'}/config";
if (-r $cfile) {
	local $lref = &virtual_server::read_file_lines_as_domain_user(
				$d, $cfile);
	push(@$lref, "", "[gitweb]", "\towner=$d->{'user'}");
	&virtual_server::flush_file_lines_as_domain_user($d, $cfile);
	}

return undef;
}

sub get_git_version
{
my $out = &backquote_command("git --version </dev/null 2>&1");
if ($out =~ /version\s+(\S+)/) {
	return $1;
	}
return undef;
}

# find_gitweb()
# Returns the path to the gitweb.cgi script
sub find_gitweb
{
my $ver = &get_git_version();
my $localcgi = "gitweb.cgi.source";
if ($ver >= 1.7) {
	$localcgi .= ".new";
	}
foreach my $p ("/var/www/git/gitweb.cgi",	# CentOS
	       "/usr/lib/cgi-bin/gitweb.cgi",	# Ubuntu
	       "$module_root_directory/$localcgi") {
	if (-r $p) {
		# Exists .. but does it use a stupid static/ path?
		my $lref = &read_file_lines($p, 1);
		my $static = 0;
		foreach my $l (@$lref) {
			if ($l =~ /\@stylesheets\s*=.*static\//) {
				$static = 1;
				}
			}
		&unflush_file_lines($p);
		if (!$static) {
			return $p;
			}
		}
	}
return undef;
}

# find_gitweb_data()
# Returns the paths to additional files needed by gitweb
sub find_gitweb_data
{
local @files = ( "git-favicon.png", "git-logo.png", "gitweb.css" );
foreach my $p ("/var/www/git",			# CentOS
	       "/var/www",			# Ubuntu
	       $module_root_directory) {
	if (-r "$p/$files[0]") {
		return map { "$p/$_" } @files;
		}
	}
return ( );
}

# set_rep_permissions(&domain, &rep)
# Make a repo mode 770, and set ownership to the Apache user so it can be
# written by SVN
sub set_rep_permissions
{
local ($d, $rep) = @_;
local $qdir = quotemeta($rep->{'dir'});
local $webuser = &virtual_server::get_apache_user($d);
local @uinfo = getpwnam($webuser);
&virtual_server::run_as_domain_user($d, "chmod -R 770 $qdir");
&system_logged("chown -R $uinfo[2] $qdir");
}

# delete_rep(&domain, &rep)
# Delete a Git repository's directory
sub delete_rep
{
local ($d, $rep) = @_;
&unlink_logged($rep->{'dir'});
&virtual_server::obtain_lock_web($d);
&remove_git_repo_directives($d, $d->{'web_port'}, $rep);
&remove_git_repo_directives($d, $d->{'web_sslport'}, $rep) if ($d->{'ssl'});
&virtual_server::release_lock_web($d);
}

# list_users(&domain)
# Returns a list of htaccess user hashes for Git in some domain
sub list_users
{
local ($d) = @_;
&foreign_require("htaccess-htpasswd", "htaccess-lib.pl");
local $users = &htaccess_htpasswd::list_users(&passwd_file($d));
return @$users;
}

# list_rep_users(&domain, &rep)
# Returns a list of user hashes with access to some repo
sub list_rep_users
{
local ($d, $rep) = @_;
local ($virt, $vconf) = &virtual_server::get_apache_virtual($d->{'dom'},
							    $d->{'web_port'});
return () if (!$virt);
local @locs = &apache::find_directive_struct("Location", $vconf);
local ($reploc) = grep { $_->{'words'}->[0] eq "/git/".$rep->{'rep'}.".git" }
		       @locs;
return () if (!$reploc);
local ($limitloc) = &apache::find_directive_struct("LimitExcept",
						   $reploc->{'members'});
local $req = &apache::find_directive_struct("Require",
		$limitloc ? $limitloc->{'members'} : $reploc->{'members'});
return () if (!$req);
local @usernames = @{$req->{'words'}};
shift(@usernames);
return map { { 'user' => $_ } } @usernames;
}

# save_rep_users(&domain, &rep, &users)
# Updates the list of users for some repository
sub save_rep_users
{
local ($d, $rep, $users) = @_;
local @usernames = map { $_->{'user'} } @$users;
local @ports = ( $d->{'web_port'} );
push(@ports, $d->{'web_sslport'}) if ($d->{'ssl'});
foreach my $p (@ports) {
	local ($virt, $vconf, $conf) =
		&virtual_server::get_apache_virtual($d->{'dom'}, $p);
	next if (!$virt);
	local @locs = &apache::find_directive_struct("Location", $vconf);
	local ($reploc) = grep { $_->{'words'}->[0] eq
				 "/git/".$rep->{'rep'}.".git" } @locs;
	next if (!$reploc);
	local ($limitloc) = &apache::find_directive_struct(
				"LimitExcept", $reploc->{'members'});
	&apache::save_directive("Require", [ "user ".join(" ", @usernames) ],
				$limitloc ? $limitloc->{'members'}
					  : $reploc->{'members'}, $conf);
	&flush_file_lines($virt->{'file'});
	}
&virtual_server::register_post_action(\&restart_apache_null);
}

sub restart_apache_null
{
&virtual_server::set_all_null_print();
&virtual_server::restart_apache();
}

# add_git_repo_directives(&domain, port, &repo, [allow-anonymous])
# Add Apache directives for DAV access to some path under /git
sub add_git_repo_directives
{
local ($d, $port, $rep, $anon) = @_;
local ($virt, $vconf) = &virtual_server::get_apache_virtual($d->{'dom'}, $port);
if ($virt) {
	local $lref = &read_file_lines($virt->{'file'});
	local ($locstart, $locend) =
	  &find_git_repo_lines($lref, $virt->{'line'}, $virt->{'eline'}, $rep);
	local @lines;
	if (!$locstart) {
		push(@lines,
		  "<Location /git/$rep->{'rep'}.git>",
		  ($anon ? ("<LimitExcept GET HEAD PROPFIND OPTIONS REPORT>",
			    "Require user",
			    "</LimitExcept>",
			    "<Limit GET HEAD PROPFIND OPTIONS REPORT>",
			    "Satisfy Any",
			    "</Limit>")
		         : ("Require user")),
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

# remove_git_repo_directives(&domain, port, &rep)
# Delete Apache directives for the /git/repo location
sub remove_git_repo_directives
{
local ($d, $port) = @_;
local ($virt, $vconf) = &virtual_server::get_apache_virtual($d->{'dom'}, $port);
if ($virt) {
        local $lref = &read_file_lines($virt->{'file'});
        local ($locstart, $locend) =
	  &find_git_repo_lines($lref, $virt->{'line'}, $virt->{'eline'}, $rep);
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

# find_git_repo_lines(&directives, start, end, &repo)
# Returns the start and end lines containing the <Location /git/repo> block
sub find_git_repo_lines
{
local ($dirs, $start, $end, $rep) = @_;
local $repname = $rep->{'rep'};
local ($locstart, $locend, $i);
for($i=$start; $i<=$end; $i++) {
        if ($dirs->[$i] =~ /^\s*<Location\s+\/git\/\Q$repname\E\.git>/i &&
	    !$locstart) {
                $locstart = $i;
                }
        elsif ($dirs->[$i] =~ /^\s*<\/Location>/i && $locstart && !$locend) {
                $locend = $i;
                }
        }
return ($locstart, $locend);
}

# set_user_password(&svn-user, &virtualmin-user, &domain)
# Sets password fields for a Git user based on their virtualmin user hash
sub set_user_password
{
local ($newuser, $user, $dom) = @_;
if ($user->{'pass_crypt'}) {
	# Hashed password is available, use it
	$newuser->{'pass'} = $user->{'pass_crypt'};
	}
elsif ($user->{'pass'} =~ /^\$/ && $user->{'plainpass'}) {
	# MD5-hashed, re-hash plain version
	&foreign_require("htaccess-htpasswd", "htaccess-lib.pl");
        $newuser->{'pass'} = &htaccess_htpasswd::encrypt_password(
				$user->{'plainpass'});
        }
else {
	# Just copy hashed password
        $newuser->{'pass'} = $user->{'pass'};
        }
}

1;

