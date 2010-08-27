
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
        return "$d->{'home'}/etc/svn.basic.passwd";
        }
}

1;

