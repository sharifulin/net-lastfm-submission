use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'Net::LastFM::Submission',
    license             => 'perl',
    dist_author         => 'Anatoly Sharifulin <sharifulin@gmail.com>',
    dist_version_from   => 'lib/Net/LastFM/Submission.pm',
    build_requires => {
        'Test::More' => 0,
    },
    add_to_cleanup      => [ 'Net-LastFM-Submission-*' ],
    create_makefile_pl => 'traditional',
);

$builder->create_build_script();
