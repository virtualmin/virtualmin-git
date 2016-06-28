#!/usr/local/bin/perl
# Create one Git repository
use strict;
use warnings;
our (%access, %text, %in);
our $module_name;

require './virtualmin-git-lib.pl';
&ReadParse();

# Validate inputs
&error_setup($text{'add_err'});
$in{'rep'} =~ /^[a-z0-9\.\-\_]+$/i || &error($text{'add_erep'});
my $dom = &virtual_server::get_domain($in{'dom'});
&can_edit_domain($dom) || &error($text{'add_edom'});

# Check limit on repositories
my @reps;
if ($access{'max'}) {
	foreach my $d (&virtual_server::list_domains()) {
		next if (!$d->{$module_name});
		next if (!&can_edit_domain($d));
		push(@reps, &list_reps($d));
		}
	@reps >= $access{'max'} && &error($text{'index_max'});
	}

# Run the create command
my $rep = { 'rep' => $in{'rep'} };
my $err = &create_rep($dom, $rep, $in{'desc'}, $in{'anon'});
&error("<pre>$err</pre>") if ($err);

# Grant selected users
my @grants = split(/\r?\n/, $in{'users'});
my %already = map { $_->{'user'}, $_ } &list_users($dom);
my @domusers = &virtual_server::list_domain_users($dom, 0, 1, 1, 1);

my @repousers;
foreach my $uname (@grants) {
        if (!$already{$uname}) {
		# Need to create the user
		my ($domuser) = grep { &virtual_server::remove_userdom(
                                      $_->{'user'}, $dom) eq $uname } @domusers;
                next if (!$domuser);
                my $newuser = { 'user' => $uname,
                                   'enabled' => 1 };
                &set_user_password($newuser, $domuser, $dom);
                &virtual_server::write_as_domain_user($dom,
                        sub { &htaccess_htpasswd::create_user(
                                $newuser, &passwd_file($dom)) });
                &virtual_server::set_permissions_as_domain_user(
                        $dom, 0755, &passwd_file($dom));
                }
	# Add to this repo
	push(@repousers, { 'user' => $uname });
	}
&save_rep_users($dom, $rep, \@repousers);

&webmin_log("add", "repo", $in{'rep'}, { 'dom' => $dom->{'dom'} });
&redirect("index.cgi?show=$in{'show'}");

