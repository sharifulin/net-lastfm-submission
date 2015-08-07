#!/usr/bin/perl

# scrobble.pl
# a fork of /src/DRSTEVE/net-lastfmapi-0.63/bin/scrobble.pl
# using Net::LastFM::Submission instead 

use strict;
use warnings;

use v5.10; # for say()
use Encode;
use File::HomeDir;
use Net::LastFM::Submission;
use Path::Tiny;

my $username;
my $password;

my $credentials_found;
my $data = eval { path( File::HomeDir->my_home, '.net-lastfm-submission-scrobbler.credentials' )->slurp_utf8 };
unless($@){
	say("found credentials in <home-dir>/.net-lastfm-submission-scrobbler.credentials");
	($username,$password) = split(/\t/,$data);
	$credentials_found = 1;
}

unless ($username) {
	say "Enter thy username";
	$username = <STDIN>;
	chomp($username);
}
unless ($password) {
	say "Enter thy password";
	$password = <STDIN>;
	chomp($password);
}

my $track = "@ARGV";
unless ($track) {
    say "Enter thy track, like Artist - Title (or provide the same, as argument(s) to this script, next time)";
    $track = <STDIN>;
}
chomp($track);
$track = encode_utf8($track);
my @track = split /\s*-\s*/, $track;
my %params;
$params{track} = pop @track;
$params{artist} = shift @track;
$params{album} = shift @track if @track;

say "submitting...";

	my $submit = Net::LastFM::Submission->new(
		'user'      => $username,
		'password'  => $password,
	);
	
	$submit->handshake;
	
	my $result = $submit->submit(
		'artist' => $params{artist},
		'title'  => $params{track},
		'time'   => time(),
	);

# a track reported as "now playing" will disappear upon your next action, unless you "submit" it later on
#	my $result = $submit->now_playing(
#		'artist' => $params{artist},
#		'title'  => $params{track},
#	);

if($result->{status} && $result->{status} eq 'OK'){
	say "done. all good.";
}else{
	say "got an error: ". $result->{error} ." ". $result->{reason};
}

unless(	$credentials_found ){
	say "may I save your credentials (plain-text) to your home-dir, into a dotfile?\n[y] for yes, anything else for No";
	my $choice = <STDIN>;

	if($choice =~ /^y/i){
		say("saving credentials to <home-dir>/.net-lastfm-submission-scrobbler.credentials");
		path( File::HomeDir->my_home, '.net-lastfm-submission-scrobbler.credentials' )->spew_utf8($username ."\t". $password);
	}else{
		say("will ask you for credentials again, next time");
	}
}
