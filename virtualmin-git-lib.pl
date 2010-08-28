
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
                push(@rv, { 'dom' => $d,
                            'rep' => $1,
                            'dir' => "$dir/$f" });
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

# create_rep(&domain, &rep)
# Creates a new Git repository in some domain
sub create_rep
{
local ($d, $rep) = @_;

# Make the dir and setup a repo in it
$rep->{'dir'} = &virtual_server::public_html_dir($d)."/git/$rep->{'rep'}.git";
if (!-d $rep->{'dir'}) {
	&virtual_server::make_dir_as_domain_user($d, $rep->{'dir'});
	}
local $cmd = "cd ".quotemeta($rep->{'dir'})." && $config{'git'} --bare init";
local ($out, $ex) = &virtual_server::run_as_domain_user($d, $cmd);
if ($ex) {
	return $out;
	}
&set_rep_permissions($d, $rep);

# Create a <Location> block for the repo
# XXX

return undef;
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
local ($dom, $rep) = @_;
&virtual_server::unlink_file_as_domain_user($dom, $rep->{'dir'});
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

1;

