#!/usr/bin/perl
use strict;

use lib '../lib';
BEGIN { $ENV{'SUBMISSION_DEBUG'}++ };
use Net::LastFM::Submission;
use Data::Dumper;

my $submit = Net::LastFM::Submission->new(
	'user'      => 'sharifulin',
	'password'  => '********',
	'enc'       => 'latin1',
);

warn Dumper $submit->handshake;

warn Dumper $submit->submit(
	'artist' => 'Artist name',
	'title'  => 'Track title',
	'time'   => time - 10*60,
);

warn Dumper $submit->now_playing(
	'artist' => 'Артист',
	'title'  => 'Песня',
	'enc'    => 'cp1251',
);
