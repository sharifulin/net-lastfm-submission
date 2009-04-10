#!/usr/bin/perl
use strict;

BEGIN { $ENV{'SUBMISSION_DEBUG'}++ };
use lib '../lib';
use Net::LastFM::Submission;
use Data::Dumper;

my $submit = Net::LastFM::Submission->new(
	'user'      => 'net_lastfm',
	'password'  => '12',
	'enc'       => 'latin1',
);

warn Dumper $submit->handshake;

warn Dumper $submit->submit(
	'artist' => 'Artist name',
	'title'  => 'Track title',
	'time'   => time - 10*60,
);

warn Dumper $submit->now_playing(
	'artist' => 'АРТИСТ',
	'title'  => 'Песня',
	'enc'    => 'cp1252',
);
