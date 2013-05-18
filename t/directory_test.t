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

# verify that the version.abc file is found
$exp = catdir('rar_wo_dir.rar__', 'version.abc');
is(
    $map->{version},
    $exp,
    'abc file search in rar w/o directory'
);

# cleanup the temp directory to free disk space
rmtree($tmpdir);

# vim: set ai nu nobk expandtab sw=4 ts=4:
