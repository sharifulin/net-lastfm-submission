#!/usr/bin/perl
use utf8; # encoding="utf-8"
use strict;

use lib qw(../lib ..);
BEGIN { $ENV{'SUBMISSION_DEBUG'}++ };
use Net::LastFM::Submission;
use Data::Dumper;

warn $Net::LastFM::Submission::VERSION;

my $conf = require '.lastfmrc';

my $submit = Net::LastFM::Submission->new(map { $_ => $conf->{$_} } 'user', 'password');

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
