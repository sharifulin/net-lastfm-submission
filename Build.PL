use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'Net::LastFM::Submission',
    dist_abstract       => 'Perl interface to the Last.fm Submissions Protocol',
    license             => 'perl',
    dist_author         => 'Anatoly Sharifulin <sharifulin@gmail.com>',
    dist_version_from   => 'lib/Net/LastFM/Submission.pm',
    build_requires => {
        'Test::More' => 0,
        'Test::Pod::Coverage' => 0,
        'Pod::Coverage' => 0,
    },
    requires => {
        'perl' => '5.008',
        'LWP::UserAgent' => 0,
        'HTTP::Request::Common' => 0,
        'Encode' => 0,
        'Digest::MD5' => 0,
        'Carp' => 0,
    },
    add_to_cleanup      => [ 'Net-LastFM-Submission-*' ],
    create_makefile_pl => 'traditional',
);

$builder->create_build_script();
