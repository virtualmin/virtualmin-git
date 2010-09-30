
do 'virtualmin-git-lib.pl';

sub module_install
{
# Remove apache config that overrides gitweb on CentOS
if ($gconfig{'os_type'} eq 'redhat-linux') {
	&unlink_file("/etc/httpd/conf.d/git.conf");
	}
}

