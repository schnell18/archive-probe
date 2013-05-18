#!/usr/bin/perl -w
# Test case for nested archive.
#
# Author:          JustinZhang <fgz@qad.com>
# Creation Date:   2013-05-13
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
my $test_data_no = 'tc1';
my $map = {};
my $tmpdir = tempdir('_arXXXXXXXX', DIR => File::Spec->tmpdir());
my $probe = Archive::Probe->new();
SKIP: {
    skip "unrar is not installed", 4 unless $probe->_is_cmd_avail('unrar');

    $probe->working_dir($tmpdir);
    $probe->add_pattern(
        'version.abc',
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
        'target.abc',
        sub {
            my ($pattern, $file_ref) = @_;

            if (@$file_ref) {
                $map->{target} = $probe->strip_dir($tmpdir, $file_ref->[0]);
            }
            else {
                $map->{target} = '';
            }
    });
    my $base_dir = catdir($test_data_dir, $test_data_no);
    $probe->reset_matches();
    $probe->search($base_dir, 1);

    # verify that the target.abc file is found
    my $exp = catfile('rar_w_dir.rar__', 'leading_dir', 'target.abc');
    is(
        $map->{target},
        $exp,
        'abc file search in rar w/ directory'
    );
    my $a = catfile($tmpdir, 'rar_w_dir.rar__', 'leading_dir', 'target.abc');
    ok(-f $a, 'existence of target.abc');

    # verify that the version.abc file is found
    $exp = catdir('rar_wo_dir.rar__', 'version.abc');
    is(
        $map->{version},
        $exp,
        'abc file search in rar w/o directory'
    );
    my $b = catfile($tmpdir, 'rar_wo_dir.rar__', 'version.abc');
    ok(-f $b, 'existence of version.abc');
}

SKIP: {
    skip "unzip is not installed", 4 unless $probe->_is_cmd_avail('unzip');

    $probe->working_dir($tmpdir);
    $probe->add_pattern(
        'config\.xml',
        sub {
            my ($pattern, $file_ref) = @_;

            if (@$file_ref) {
                $map->{xml} = $probe->strip_dir($tmpdir, $file_ref->[0]);
            }
            else {
                $map->{xml} = '';
            }
    });
    $probe->add_pattern(
        'index\.jsp',
        sub {
            my ($pattern, $file_ref) = @_;

            if (@$file_ref) {
                $map->{jsp} = $probe->strip_dir($tmpdir, $file_ref->[0]);
            }
            else {
                $map->{jsp} = '';
            }
    });
    my $base_dir = catdir($test_data_dir, $test_data_no);
    $probe->reset_matches();
    $probe->search($base_dir, 1);

    # verify that the target.abc file is found
    my $exp = catfile('webapp.zip__', 'WEB-INF', 'config.xml');
    is(
        $map->{xml},
        $exp,
        'file search in zip w/ leading directory'
    );
    my $a = catfile($tmpdir, 'webapp.zip__', 'WEB-INF', 'config.xml');
    ok(-f $a, 'existence of config.xml');

    # verify that the index.jsp file is found
    $exp = catdir('webapp.zip__', 'index.jsp');
    is(
        $map->{jsp},
        $exp,
        'file search in zip w/o leading directory'
    );
    my $b = catfile($tmpdir, 'webapp.zip__', 'index.jsp');
    ok(-f $b, 'existence of index.jsp');
}
# cleanup the temp directory to free disk space
rmtree($tmpdir);

# vim: set ai nu nobk expandtab sw=4 ts=4:
