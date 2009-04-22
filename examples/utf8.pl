#!/usr/bin/perl
use utf8; # encoding="utf-8"
use strict;

use lib '../lib';
BEGIN { $ENV{'SUBMISSION_DEBUG'}++ };
use Net::LastFM::Submission;
use Data::Dumper;

warn $Net::LastFM::Submission::VERSION;

my $submit = Net::LastFM::Submission->new(
	'user'      => 'net_lastfm',
	'password'  => '12',
);

$submit->handshake;

warn Dumper $submit->submit(
	'artist' => 'Артист1',
	'title'  => 'Песня1',
	'time'   => time - 10*60,
);

# no module encoding
warn Dumper $submit->now_playing(
	'artist' => 'Артист2',
	'title'  => 'Песня2',
);
