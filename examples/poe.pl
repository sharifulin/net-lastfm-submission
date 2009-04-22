#!/usr/bin/perl
use strict;
use utf8;

use lib '../lib';
BEGIN { $ENV{'SUBMISSION_DEBUG'}++ };
use POE qw(Component::Net::LastFM::Submission XS::Queue::Array);
use Data::Dumper;

POE::Component::Net::LastFM::Submission->spawn(
	Alias  => 'LASTFM_SUBMIT',
	LastFM => {
		user     => 'net_lastfm',
		password => '12',
	},
);

POE::Session->create(
	options       => { trace => 1 },
	inline_states => {
		_start => sub {
			$_[KERNEL]->post('LASTFM_SUBMIT' => 'handshake' => 'np');
			$_[KERNEL]->yield('_delay');
		},
		_delay => sub { $_[KERNEL]->delay($_[STATE] => 5) },
		
		np => sub {
			warn Dumper @_[ARG0, ARG1, ARG2];
			$_[HEAP]->{__i}++ == 50
				?
					$_[KERNEL]->post(
						'LASTFM_SUBMIT' => 'submit' => 'sb',
						{'artist' => 'ArtistName', 'title'  => 'TrackName', time => time - 10*60}
					)
				: 
					$_[KERNEL]->post(
						'LASTFM_SUBMIT' => 'now_playing' => 'np',
						{'artist' => 'Артист11', 'title'  => 'Песня21'},
						$_[HEAP]->{__i}
					)
			;
		},
		
		sb => sub {
			warn Dumper $_[ARG0];
			$_[KERNEL]->stop;
		},
	}
);

POE::Kernel->run;
