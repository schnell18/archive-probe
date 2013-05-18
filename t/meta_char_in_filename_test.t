#!/usr/bin/perl -w
# Test case to search file w/ meta char in the name
#
# Author:          JustinZhang <fgz@qad.com>
# Creation Date:   2013-05-14
#
#
BEGIN {
    if (-d 't') {
        # running from the base directory
        push @INC, 't';
    }
}
use strict;
use Cwd;
use File::Path;
use File::Spec::Functions qw(rel2abs updir catdir catfile);
use File::Temp qw(tempdir);
use Test::More qw(no_plan);
use TestBase;
use Archive::Probe;

my $test_data_dir = get_test_data_dir();
my $test_data_no = 'tc4';
my $map = {};
my $tmpdir = tempdir('_arXXXXXXXX', DIR => File::Spec->tmpdir());
my $probe = Archive::Probe->new();
SKIP: {
    skip "unrar is not installed", 5 unless $probe->_is_cmd_avail('unrar');
    skip "unzip is not installed", 5 unless $probe->_is_cmd_avail('unzip');

    $probe->working_dir($tmpdir);
    $probe->add_pattern(
        'abc.d$',
        sub {
            my ($pattern, $file_ref) = @_;

            if (@$file_ref) {
                $map->{dot_d} = $probe->strip_dir($tmpdir, $file_ref->[0]);
            }
            else {
                $map->{dot_d} = '';
            }
    });
    $probe->add_pattern(
        'version\.abc',
        sub {
            my ($pattern, $file_ref) = @_;

            if (@$file_ref) {
                $map->{version} = $probe->strip_dir($tmpdir, $file_ref->[0]);
            }
            else {
                $map->{version} = '';
            }
    });
    $probe->add_pattern(
        '\.hpp$',
        sub {
            my ($pattern, $file_ref) = @_;

            if (@$file_ref) {
                $map->{hpp} = $probe->strip_dir($tmpdir, $file_ref->[0]);
            }
            else {
                $map->{hpp} = '';
            }
    });
    $probe->add_pattern(
        '\.go',
        sub {
            my ($pattern, $file_ref) = @_;

            if (@$file_ref) {
                $map->{go} = $probe->strip_dir($tmpdir, $file_ref->[0]);
            }
            else {
                $map->{go} = '';
            }
    });
    my $base_dir = catdir($test_data_dir, $test_data_no);
    $probe->reset_matches();
    $probe->search($base_dir, 1);

    # verify abc's.zip exists
    my $abc = catfile(
        $tmpdir,
        'a.rar__',
        'abc\'s.zip'
    );
    ok(-f $abc, 'single quote in file name zip existence test');

    # verify that the abc.d file is found
    my $exp = catfile(
        'a.rar__',
        'abc\'s.zip__',
        'abc.d'
    );
    is(
        $map->{dot_d},
        $exp,
        'single quote in zip file name test'
    );

    # verify that the version.abc file is found
    $exp = catfile(
        'a.zip__',
        '\\version.abc'
    );
    is(
        $map->{version},
        $exp,
        'bashslash in file name test'
    );

    # verify that the "quick & dirty sort.hpp" file is found
    $exp = catfile(
        'b.zip__',
        'cpp',
        'quick & dirty sort.hpp'
    );
    is(
        $map->{hpp},
        $exp,
        'space in file name test'
    );

    # verify that the "hell.go" file is found
    $exp = catfile(
        'c.zip__',
        "\\Rock & Roll 't.zip__",
        'go',
        'hello.go'
    );
    is(
        $map->{go},
        $exp,
        'space, single quote, backslash in file name test'
    );
}

# cleanup the temp directory to free disk space
rmtree($tmpdir);

# vim: set ai nu nobk expandtab sw=4 ts=4:
