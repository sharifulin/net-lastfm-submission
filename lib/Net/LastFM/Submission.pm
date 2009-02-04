package Net::LastFM::Submission;
use strict;

use LWP::UserAgent;
use HTTP::Request::Common 'GET', 'POST';
use Digest::MD5 'md5_hex';
use Carp 'croak';

use constant DEBUG => $ENV{'SUBMISSION_DEBUG'} || 0;

our $VERSION = '0.2';
our $URL     = 'http://post.audioscrobbler.com/';

sub new {
	my $class = shift;
	my $param = ref $_[0] eq 'HASH' ? shift : {@_};
	
	my $self  = {
		'proto'  => '1.2.1',
		'limit'  => 50, # last.fm limit
		
		'client' => {
			'id'  => $param->{'client_id' } || 'tst', # test client id
			'ver' => $param->{'client_ver'} || '1.0', # test client version
		},
		'user'   => {
			'name'     => $param->{'user'    } || croak('Need user name'),
			'password' => $param->{'password'},
		},
		'api'    => {
			'key'     => $param->{'api_key'    },
			'secret'  => $param->{'api_secret' },
		},
		'auth'   => {
			'session' => $param->{'session_key'},
		},
		
		'ua'     => $param->{'ua' } || LWP::UserAgent->new('timeout' => 10, 'agent' => join '/', __PACKAGE__, $VERSION),
		
		'enc'    => $param->{'enc'} || 'cp1251',
	};
	
	if (defined $self->{'user'}->{'password'}) {
		$self->{'auth'}->{'type'} = 'standard';
	} else {
		croak 'Need shared data (api_key/api_secret/session_key) for Web Services authentication' if grep { !$_ } @{$self->{'api'}}{'key', 'secret'}, $self->{'auth'}->{'secret_key'};
		$self->{'auth'}->{'type'} = 'web';
	}
	
	if (DEBUG) {
		warn "Last.fm Submissions Protocol v$self->{'proto'}";
		warn "Client Identifier: $self->{'client'}->{'id'}/$self->{'client'}->{'ver'}";
		warn $self->{'auth'}->{'type'} eq 'web' ? 'Web Services Authentication' : 'Standard Authentication';
	}
	
	bless $self, ref $class || $class;
}

sub handshake {
	my $self = shift;
	my $time = time;
	
	$self->{'auth'}->{'token'} = md5_hex(($self->{'auth'}->{'type'} eq 'web' ? $self->{'api'}->{'secret'} : md5_hex $self->{'user'}->{'password'}).$time);
	
	return $self->{'hs'} = $self->_parse_response for $self->{'ua'}->request(
		grep { DEBUG && warn $_->as_string; 1 }
		GET(join '?', $URL, join '&',
			'hs=true',
			"p=$self->{'proto' }",
			"c=$self->{'client'}->{'id'  }",
			"v=$self->{'client'}->{'ver' }",
			"u=$self->{'user'  }->{'name'}",
			"t=$time",
			"a=$self->{'auth'}->{'token'}",
			$self->{'auth'}->{'type'} eq 'web' ? ("api_key=$self->{'api'}->{'key'}", "sk=$self->{'auth'}->{'session'}") : (),
		)
	);
}

sub now_playing {
	my $self  = shift;
	my $param = ref $_[0] eq 'HASH' ? shift : {@_};
	
	return $self->_error('Need the now-playing URL returned by the handshake request') unless $self->{'hs'}->{'url'}->{'np'};
	return $self->_error('Need Session ID string returned by the handshake request'  ) unless $self->{'hs'}->{'sid'};
	return $self->_error('Need artist/title name') if grep { !$param->{$_} } 'artist', 'title';
	
	$self->_encode($param->{'enc'}) for @$param{'artist', 'title', 'album'};
	
	return $self->_parse_response for $self->{'ua'}->request(
		grep { DEBUG && warn $_->as_string;1 }
		POST($self->{'hs'}->{'url'}->{'np'}, [
			's' => $self->{'hs'}->{'sid'},
			'a' => $param->{'artist'},
			't' => $param->{'title' },
			'b' => $param->{'album' },
			'l' => $param->{'length'},
			'n' => $param->{'id'    },
			'm' => $param->{'mb_id' },
		])
	);
}

sub submit {
	my $self = shift;
	my $list = ref $_[0] eq 'HASH' ? [@_] : [{@_}];
	
	return $self->_error('Need the now-playing URL returned by the handshake request') unless $self->{'hs'}->{'url'}->{'np'};
	return $self->_error('Need Session ID string returned by the handshake request'  ) unless $self->{'hs'}->{'sid'};
	warn "Use first $self->{'limit'} tracks for submissions" if DEBUG;
	
	$list = [
		grep {
			my $enc = $_->{'enc'};
			$self->_encode($enc) for @$_{'artist', 'title', 'album'};
			1;
		}
		grep { $_->{'title'} && $_->{'artist'} }
		splice @$list, 0, $self->{'limit'}
	];
	return $self->_error('Need artist/title name') unless @$list;
	
	my $i;
	return $self->_parse_response for $self->{'ua'}->request(
		grep { DEBUG && warn $_->as_string;1 }
		POST($self->{'hs'}->{'url'}->{'sm'}, [
			's' => $self->{'hs'}->{'sid'},
			map {
				$i = defined $i ? $i+1 : 0;
				(
					"a[$i]" => $_->{'artist'},
					"t[$i]" => $_->{'title' },
					"i[$i]" => $_->{'time'  } || time,
					"o[$i]" => $_->{'source'} ||  'R',
					"r[$i]" => $_->{'rating'},
					"l[$i]" => $_->{'length'},
					"b[$i]" => $_->{'album' },
					"n[$i]" => $_->{'id'    },
					"m[$i]" => $_->{'mb_id' },
				);
			}
			@$list
		])
	);
}

sub _error {
	shift;
	return {'error' => 'ERROR', 'reason' => shift};
}

sub _parse_response {
	shift; warn join "\n", $_->status_line, $_->content if DEBUG;
	return $_->is_success && $_->content =~ /^ (OK) ( \n (\w+) \n (\S+) \n (\S+) )? /sx
		? {'status' => $1, $2 ? ('sid' => $3, 'url' => {'np' => $4, 'sm' => $5} ) : ()}
		: {'code' => $_->code, map { ('error' => $_->[0], $_->[1] ? ('reason' => $_->[1]) : ()) } [$_->content =~ /^(\S+)(?:\s+(.*))?/]}
	;
}

sub _encode {
	my $self = shift;
	my $enc  = shift || $self->{'enc'};
	
	use Encode ();
	DEBUG && warn("Encode data $enc to utf8"), $_ = Encode::encode_utf8 Encode::decode($enc, $_) unless Encode::is_utf8($_);
	Encode::_utf8_off($_);
	
	1;
}

1;

__END__
=head1 NAME

Net::LastFM::Submission - Perl interface to the Last.fm Submissions Protocol

=head1 SYNOPSIS

    use Net::LastFM::Submission;
    
    my $submit = Net::LastFM::Submission->new(
        'user'      => 'XXX',
        'password'  => 'YYY',
    );
    
    $submit->handshake;
    
    $submit->submit(
        'artist' => 'Artist name',
        'title'  => 'Track title',
        'time'   => time - 10*60, # 10 minutes ago
    );
    
    $submit->now_playing(
        'artist' => 'Artist name',
        'title'  => 'Track title',
    );

=head1 DESCRIPTION

The module provides a simple Perl interface to the Last.fm Submissions Protocol (current version is 1.2.1).

The Last.fm Submissions Protocol is designed for the submission of now-playing and recent historical track data to Last.fm user profiles (aka 'Scrobbling'). 

L<http://www.lastfm.ru/api/submissions>

=head1 METHODS

=head2 new(I<%args>)

This is a constructor for Net::LastFM::Submission object. It takes list of parameters or hashref parameter.

    # list
    my $submit = Net::LastFM::Submission->new(
        'user'     => 'XXX',
        'password' => 'YYY',
    );
    
    # hashref
    my $submit = Net::LastFM::Submission->new({
        'user'     => 'XXX',
        'password' => 'YYY',
    });

This is a list of support parameters:

=over 9

=item * I<user>

The name of the Last.FM user. Required.

=item * I<password>

The password of the Last.FM user. Required for Standard authentication only.
It is used for generate authentication token.
See L<http://www.lastfm.ru/api/submissions#1.2>.

=item * I<api_key>

The API key from your Web Services account. Required for Web Services authentication only.

=item * I<api_secret>

The API secret from your Web Services account. Required for Web Services authentication only.
It is used for generate authentication token.
See L<http://www.lastfm.ru/api/submissions#1.3>.

=item * I<secret_key>

The Web Services session key generated via the authentication protocol. Required for Web Services authentication only.

=item * I<client_id>

Is an identifier for the client. Optional.
Default value is B<tst>.
See L<http://www.lastfm.ru/api/submissions#1.1>.

=item * I<client_ver>

Is the version of the client being used. Optional.
Default value is B<1.0>.

=item * I<ua>

Is an user agent. Optional.
Default is L<LWP::UserAgent> with timeout 10 seconds.

=item * I<enc>

Is the encoding of data, module try to encode a data (artist/title/album) unless data is UTF-8. See L<Encode>. Optional.
Default value is B<cp1251>.

=back


=head2 handshake()

The initial negotiation with the submissions server to establish authentication and connection details for the session.
See L<http://www.lastfm.ru/api/submissions#handshake>.

    $submit->handshake;

If the handshake was successful, the returned hashref has the format:

    {
        'status' => 'OK',
        'sid'    => 'Session ID', # the scrobble session id
        'url'    => {
            'np'  => 'Now-Playing URL',
            'sm'  => 'Submission URL'
        }
    }

If the handshake was break, the returned hashref has the format:

    {
        'error'  => 'BANNED/BADAUTH/BADTIME/FAILED',
        'code'   => '200/500', # code of status line response
        'reason' => '...'      # reason of error
    }


=head2 now_playing(I<%args>)

Optional lightweight notification of now-playing data at the start of the track for realtime information purposes.
See L<http://www.lastfm.ru/api/submissions#np>.

It takes list of parameters or hashref parameter.

    # list
    $submit->now_playing(
        'artist' => 'Artist name',
        'title'  => 'Track title',
    );
    
    # hashref
    $submit->now_playing({
        'artist' => 'Artist name',
        'title'  => 'Track title',
    });

This is a list of support parameters:

=over 7

=item * I<artist>

The artist name. Required.

=item * I<title>

The track name. Required.

=item * I<album>

The album title, or an empty string if not known.

=item * I<length>

The length of the track in seconds, or an empty string if not known.

=item * I<id>

The position of the track on the album, or an empty string if not known.

=item * I<mb_id>

The MusicBrainz Track ID, or an empty string if not known.

=item * I<enc>

Is the encoding of data, module try to encode a data (artist/title/album) unless data is UTF-8. Optional.
Default value is parameter enc of self object.

=back

If the notification was successful, the returned hashref has the format:

    {
        'status' => 'OK',
    }

If the notification was break, the returned hashref has the format:

    {
        'error'  => 'ERROR/BADSESSION',
        'code'   => '200/500', # code of status line response
        'reason' => '...'      # reason of error
    }


=head2 submit(I<%args>)

Submission of full track data at the end of the track for statistical purposes.
See L<http://www.lastfm.ru/api/submissions#subs>.

It takes list of parameters (information about one track) or list of hashref parameters (limit of Last.FM is 50).

    # list
    $submit->submit(
        'artist' => 'Artist name',
        'title'  => 'Track title',
    );
    
    # hashref
    $submit->submit(
        grep { $_->{'source'} = 'R';1 }
        {
            'artist' => 'Artist name 1',
            'title'  => 'Track title 1',
            'time'   => time - 10*60,
        }
        {
            'artist' => 'Artist name 2',
            'title'  => 'Track title 2',
        }
    );

This is a list of support parameters:

=over 10

=item * I<artist>

The artist name. Required.

=item * I<title>

The track name. Required.

=item * I<time>

The time the track started playing, in UNIX timestamp format. Optional.
Default value is current time.

=item * I<source>

The source of the track. Optional.
Default value is B<R>.

=item * I<rating>

A single character denoting the rating of the track. Empty if not applicable. 

=item * I<length>

The length of the track in seconds. Required when the source is P, optional otherwise.

=item * I<album>

The album title, or an empty string if not known.

=item * I<id>

The position of the track on the album, or an empty string if not known.

=item * I<mb_id>

The MusicBrainz Track ID, or an empty string if not known.

=item * I<enc>

Is the encoding of data, module try to encode a data (artist/title/album) unless data is UTF-8. Optional.
Default value is parameter enc of self object.

=back

If the submit was successful, the returned hashref has the format:

    {
        'status' => 'OK',
    }

If the submit was break, the returned hashref has the format:

    {
        'error'  => 'ERROR/BADSESSION/FAILED',
        'code'   => '200/500', # code of status line response
        'reason' => '...'      # reason of error
    }

=head1 DEBUG MODE

Module supports debug mode.

    BEGIN { $ENV{SUBMISSION_DEBUG}++ };
    use Net::LastFM::Submission;

=head1 SEE ALSO

=over 3

=item * L<Net::LastFM>

A simple interface to the Last.fm API. Moose-like interface. Very simple and powerful.

=item * L<Audio::Scrobbler>

Perl interface to audioscrobbler.com/last.fm. Old interface for submit.

=item * L<Music::Audioscrobbler::Submit>

Module providing routines to submit songs to last.fm using 1.2 protocol. Use path to a track or Music::Tag or hashref. Very big :).

=back

=head1 AUTHOR

Anatoly Sharifulin, C<< <sharifulin at gmail.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-net-lastfm-submission at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Net-LastFM-Submission>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT & DOCUMENTATION

You can find documentation for this module with the perldoc command.

    perldoc Net::LastFM::Submission

You can also look for information at:

=over 5

=item * Github

L<http://github.com/sharifulin/net-lastfm-submission/tree/master>

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Net-LastFM-Submission>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Net-LastFM-Submission>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Net-LastFM-Submission>

=item * Search CPAN

L<http://search.cpan.org/dist/Net-LastFM-Submission>

=back

=head1 COPYRIGHT & LICENSE

Copyright (C) 2009 Anatoly Sharifulin

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
