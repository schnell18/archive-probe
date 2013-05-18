package Archive::Probe;
#
# This class contains common logic to extract files matching given
# pattern in a set of archive files 
# Pre-requisite: unrar, 7za should be in PATH
#                Get free unrar from: http://www.rarlab.com/rar_add.htm
# Author:          JustinZhang <fgz@qad.com>
# Creation Date:   2013-05-06
#
use strict;
use warnings;
use Carp;
use File::Path;
use File::Copy;
use File::Spec::Functions qw(catdir catfile devnull);

our $VERSION = "0.8";

=pod

=head1 NAME

Archive::Probe - A generic library to search file within archive

=head1 SYNOPSIS

    use Archive::Probe;

    my $tmpdir = '<temp_dir>';
    my $base_dir = '<directory_of_archive_files>';
    my $probe = Archive::Probe->new();
    $probe->working_dir($tmpdir);
    $probe->add_pattern(
        '<your_pattern_here>',
        sub {
            my ($pattern, $file_ref) = @_;

            # do something with result files
    });
    $probe->search($base_dir, 1);

=head1 DESCRIPTION

Archive::Probe is a generic library to search file within archive.

It allows you to test the existence of a particular file, which can be
described in regular expression, and optionally to extract that file and
inspect the file content in custom code. It supports common archive types
such as .tar, .tgz, .bz2, .rar, .zip, .7z. One archive file can contain
archive file of same or other type. And level of nesting is unlimited.
This module depends on unrar, 7za and tar which should be in PATH.
The 7za is part of open source software 7zip. You can get it from:
www.7-zip.org. The unrar is freeware which can be downloaded from:
http://www.rarlab.com/rar_add.htm.

=cut

=head1 METHODS

=head2 $probe = Archive::Probe->new()

Creates a new C<Archive::Probe> object.

=cut

sub new {
    my $self = shift;

    my $class = ref $self || $self;
    return bless {}, $class;
}

=head2 $probe->add_pattern(regex, coderef)

Register a file pattern to search with in the archive file(s) and the
callback code to handle the matched files. The callback will be passed
two arguments:

=over 4

=item $pattern

This is the pattern of the matched files.

=item $file_ref

This is the array reference to the files matched the pattern. The existence
of the files is controlled by the second argument to the C<search()> method.

=back

=cut

sub add_pattern {
    my ($self, $pattern, $callback) = @_;

    # validate pattern and callback
    confess("Pattern is mandatory\n") unless $pattern;
    confess("Code reference is expected\n") unless ref($callback) eq 'CODE';

    my $pattern_map = $self->_search_pattern();
    if (!$pattern_map) {
        $pattern_map = {};
        $self->_search_pattern($pattern_map);
    }

    $pattern_map->{$pattern} = [$callback];
}

=head2 $probe->search(base_dir, extract_matched)

Search registered files under 'base_dir' and invoke the callback.
It requires two arguments:

=over 4

=item $base_dir

This is the directory containing the archive file(s).

=item $extract_matched

Extract or copy the matched files to the working directory
if this parameter evaluate to true.

=back

=cut

sub search {
    my ($self, $base_dir, $do_extract) = @_;
    
    my $dirs_ref = [$base_dir];
    $self->_walk_tree($dirs_ref, sub {
        my ($file) = @_;

        my $ctx = '';
        # Test if the file matches regestered pattern
        $self->_match($do_extract, $base_dir, $ctx, $file);
        if ($self->_is_archive_file($file)) {
            my $ctx = $file . '__';
            $ctx = $self->strip_dir($base_dir, $ctx);
            $self->_search_in_archive($do_extract, $base_dir, $ctx, $file);
        }
    });

    # check search result & invoke callback
    $self->_callback();
}

=head2 $probe->reset_matches()

Reset the matched files list.

=cut

sub reset_matches {
    my ($self) = @_;

    my $patterns = $self->_search_pattern();
    foreach my $pat (keys(%$patterns)) {
        undef($patterns->{$pat}[1]);
    }
}

sub strip_dir {
    my ($self, $base_dir, $path) = @_;

    my $dir1 = $base_dir;
    my $path1 = $path;

    my $path_sep = '/';
    $path_sep = '\\' if $^O eq 'MSWin32';

    $dir1 .= $path_sep unless substr($dir1, -1, 1) eq $path_sep;
    if (index($path1, $dir1) == 0) {
        $path1 = substr($path1, length($dir1));
    }
    return $path1;
}

=head1 ACCESSORS

=head2 $probe->working_dir([directory])

Set or get the working directory where the temporary files will be created.

=cut

sub working_dir {
    my ($self, $value) = @_;

    if(defined $value) {
    	my $oldval = $self->{working_dir};
    	$self->{working_dir} = $value;
    	return $oldval;
    }

    return $self->{working_dir};
}

=head2 $show_extracting_output->working_dir([BOOL])

Enable or disable the output of command line archive tool.

=cut

sub show_extracting_output {
    my ($self, $value) = @_;

    if(defined $value) {
    	my $oldval = $self->{show_extracting_output};
    	$self->{show_extracting_output} = $value;
    	return $oldval;
    }

    return $self->{show_extracting_output};
}

sub _extract_matched {
    my ($self, $base_dir, $ctx, $file, $do_extract) = @_;

    my $dest;
    my $work_dir = $self->working_dir();
    # extract the matched file here
    if ($ctx ne '') {
        # parent file location = $base_dir + substr($ctx, 0, -2)
        my $parent = catfile($base_dir, substr($ctx, 0, -2));
        my $extract_dir = catdir($work_dir, $ctx);
        if ($do_extract) {
            my $ret = $self->_extract_archive_file(
                $parent,
                $file,
                $extract_dir
            );
            if (!$ret) {
                carp("$file can not be extracted from $parent, ignored\n");
                return undef;
            }
        }
        $dest = catfile($extract_dir, $file);
    }
    else {
        # matched files are unarchived
        # copy to working directory as-is
        # create absent local dir first
        my $local_path = $self->strip_dir($base_dir, $file);
        $dest = catfile($work_dir, $local_path);

        if ($do_extract) {
            my $dir2 = catdir($work_dir, $self->_dir_name($local_path));
            mkpath($dir2) unless -d $dir2;
            my $ret = copy($file, $dest);
            if (!$ret) {
                carp("Can't copy file $file to $dest due to: $!\n");
                return undef;
            }
        }
    }
    return $dest;
}

sub _match {
    my ($self, $do_extract, $base_dir, $ctx, $file) = @_;

    my $matches = 0;
    my $part = $self->strip_dir(catdir($base_dir, $ctx), $file);
    my $patterns = $self->_search_pattern();
    foreach my $pat (keys(%$patterns)) {
        if ($part =~ /$pat/) {
            $matches ++;
            my $dest = $self->_extract_matched(
                $base_dir,
                $ctx,
                $file,
                $do_extract
            );
            # do not add file to matched list if extract fails
            next unless $dest;

            my $pat_ref = $patterns->{$pat};
            if (!defined($pat_ref->[1])) {
                $pat_ref->[1] = [$dest];
            }
            else {
                push @{$pat_ref->[1]}, $dest;
            }
        }
    }
    return $matches;
}

sub _callback {
    my ($self) = @_;

    my $patterns = $self->_search_pattern();
    foreach my $pat (keys(%$patterns)) {
        my $pat_ref = $patterns->{$pat};
        if (ref($pat_ref->[0]) eq 'CODE' && defined($pat_ref->[1])) {
            $pat_ref->[0]->($pat, $pat_ref->[1]);
        }
    }
}

sub _walk_tree {
    my ($self, $dirs_ref, $file_handler) = @_;

    my @dirs = ();

    foreach my $dir (@$dirs_ref) {
        if(-d $dir ) {
            my $ret = opendir(DIR, $dir);
            if (!$ret) {
                carp("Can't read directory due to: $!\n");
                next;
            }

            while(my $entry = readdir(DIR)) {
                my $full_path = catfile($dir, $entry);
                if(-f $full_path) {
                    $file_handler->($full_path);
                }
                elsif($entry ne '.' && $entry ne '..' && -d $full_path) {
                    push @dirs, $full_path;
                }
            }
            closedir(DIR);
        }
    }

    if(@dirs) {
        $self->_walk_tree(\@dirs, $file_handler);
    }
}

sub _search_in_archive {
    my ($self, $do_extract, $base_dir, $ctx, $file) = @_;

    if ($file =~ /\.zip$|\.7z$/) {
        $self->_peek_archive(
            $do_extract,
            $base_dir,
            $ctx,
            $file,
            '7za l',
            '(-+)\s+(-+)\s+(-+)\s+(-+)\s+(-+)',
            '---+',
            '',
            sub {
                my ($entry, undef, undef, undef, undef, $file_pos_7z) = @_;
                my (undef, undef, $a, undef) = split(' ', $entry, 4);
                return undef if $a =~ /^D/;
                if ($file_pos_7z && $file_pos_7z < length($entry)) {
                   my $f = substr($entry, $file_pos_7z);
                   return $f;
                }
                return undef;
            }
        ); 
    }
    elsif ($file =~ /\.rar$/) {
        $self->_peek_archive(
            $do_extract,
            $base_dir,
            $ctx,
            $file,
            "unrar vb",
            '',
            '',
            '',
            sub {
                my ($entry) = @_;
                return $entry;
            }
        ); 
    }
    elsif ($file =~ /\.tgz$|\.tar\.gz$|\.tar\.Z$/) {
        $self->_peek_archive(
            $do_extract,
            $base_dir,
            $ctx,
            $file,
            "tar -tzf",
            '',
            '',
            '\/$',
            sub {
                my ($entry) = @_;
                return $entry;
            }
        ); 
    }
    elsif ($file =~ /\.bz2$/) {
        $self->_peek_archive(
            $do_extract,
            $base_dir,
            $ctx,
            $file,
            "tar -tjf",
            '',
            '',
            '\/$',
            sub {
                my ($entry) = @_;
                return $entry;
            }
        ); 
    }
    elsif ($file =~ /\.tar$/) {
        $self->_peek_archive(
            $do_extract,
            $base_dir,
            $ctx,
            $file,
            "tar -tf",
            '',
            '',
            '\/$',
            sub {
                my ($entry) = @_;
                return $entry;
            }
        ); 
    }
}

sub _peek_archive {
    my ($self,
        $do_extract,
        $base_dir,
        $ctx,
        $file,
        $list_cmd,
        $begin_pat,
        $end_pat,
        $ignore_pat,
        $sub
    ) = @_;

    my $tmpdir = $self->working_dir();
    my $cmd = join(" ", "$list_cmd", qq{"$file"});

    my @col_indexes;
    my $file_list_begin = 0;
    my $ret = open(my $fh, "$cmd 2>&1 |");
    if (!$ret) {
        carp("Can't run $cmd due to: $!\n");
        return;
    }

    while(<$fh>) {
        chomp;
        my $line = $_;
        if ($begin_pat) {
            if (! $file_list_begin) {
                # determine if the start of file list and
                # calculate start position of each column
                my @captures = $line =~ /$begin_pat/g;
                if (@captures) {
                    my $pos = 0;
                    $file_list_begin = 1;
                    foreach my $cap (@captures) {
                        push @col_indexes, index($line, $cap, $pos);
                        $pos += length($cap);
                    }
                }
                next; 
            }
        }

        if ($ignore_pat) {
            next if /$ignore_pat/;
        }

        if ($end_pat) {
            last if /$end_pat/;
        }

        my $f = $sub->($line, @col_indexes);
        # ignore empty line, usually directory
        next unless $f;
        $self->_match($do_extract, $base_dir, $ctx, $f);
        if ($self->_is_archive_file($f)) {
            my $extract_dir = catdir($tmpdir, $ctx);
            my $ret = $self->_extract_archive_file($file, $f, $extract_dir);
            if ($ret) {
                my $new_ctx = catfile($ctx, $f . '__');
                $self->_search_in_archive(
                    $do_extract,
                    $tmpdir,
                    $new_ctx,
                    catfile($extract_dir, $f)
                );
            }
            else {
                carp("$f can not be extracted from $file, ignored\n");
            }
        }
    }
    close($fh);
}

sub _extract_archive_file {
    my ($self, $parent, $file, $extract_dir) = @_;

    mkpath($extract_dir) unless -d $extract_dir;
    my $cmd = "";
    if ($parent =~ /\.zip$|\.7z$/) {
        # specify dummy password to make 7za fail fast
        # instead of waiting for user input password when
        # the zip file is password-protected
        $cmd = $self->_build_cmd(
            '7za x -y -pxxx',
            $extract_dir,
            $parent,
            $file
        );
    }
    elsif ($parent =~ /\.rar$/) {
        $cmd = $self->_build_cmd(
            'unrar x -o+',
            $extract_dir,
            $parent,
            $file
        );
    }
    elsif ($parent =~ /\.tgz$|\.tar\.gz$|\.tar\.Z$/) {
        # The "-o" avoid to restore the owner as it could be root
        $cmd = $self->_build_cmd(
            'tar -xzof',
            $extract_dir,
            $parent,
            $file
        );
    }
    elsif ($parent =~ /\.bz2$/) {
        # The "-o" avoid to restore the owner as it could be root
        $cmd = $self->_build_cmd(
            'tar -xjof',
            $extract_dir,
            $parent,
            $file
        );
    }
    elsif ($parent =~ /\.tar$/) {
        # The "-o" avoid to restore the owner as it could be root
        $cmd = $self->_build_cmd(
            'tar -xof',
            $extract_dir,
            $parent,
            $file
        );
    }
    my $cmd_shell = sprintf("%s 2>%s 1>&2", $cmd, devnull());
    $cmd_shell = "$cmd 1>&2" if $self->show_extracting_output();
    my $ret = system($cmd_shell);
    return $ret == 0;
}

sub _build_cmd {
    my ($self, $extract_cmd, $dir, $parent, $file) = @_;

    my $quote     = q["];
    my $chdir_cmd = q[cd];
    if ($^O eq 'MSWin32') {
        $chdir_cmd = q[cd /d];
    }
    return sprintf(
        "%s %s%s%s && %s %s%s%s %s",
        $chdir_cmd,
        $quote,
        $dir,
        $quote,
        $extract_cmd,
        $quote,
        $parent,
        $quote,
        $self->_escape($file)
    );
}

sub _escape {
    my ($self, $str) = @_;

    my $ret = $str;
    if ($ret =~ /'|"|\\|\s+|&/) {
        if ($ret =~ /"/) {
            $ret = qq['$ret'];
        }
        else {
            $ret = qq["$ret"];
        }
    }
    return $ret;
}

sub _is_archive_file {
    my ($self, $file) = @_;

    return $file =~ /\.(zip|7z|rar|tgz|bz2|tar|tar\.gz|tar\.Z)$/
}

sub _property {
    my ($self, $attr, $value) = @_;

    if(defined $value) {
    	my $oldval = $self->{$attr};
    	$self->{$attr} = $value;
    	$self->{_properties_with_value} = {}
    	    if(!exists $self->{_properties_with_value});
    	$self->{_properties_with_value}{$attr} = 1;
    	return $oldval;
    }

    return $self->{$attr};
}

sub _remove_property ($$) {
    my ($self, $attr) = @_;

    $self->{$attr} = undef;
}

sub _search_pattern {
    my ($self, $value) = @_;

    if(defined $value) {
    	my $oldval = $self->{search_pattern};
    	$self->{search_pattern} = $value;
    	return $oldval;
    }

    return $self->{search_pattern};
}

sub _dir_name {
    my ($self, $path) = @_;

    my $path_sep = '/';
    $path_sep = '\\' if $^O eq 'MSWin32';
    my $idx = rindex($path, $path_sep);
    if ($idx > 0) {
        return substr($path, 0, $idx);
    }
    else {
        return '';
    }
}

1;

=pod

=head1 HOW IT WORKS

C<Archive::Probe> provides plumbing boiler code to search files in nested
archive files. It does the heavy lifting to extract mininal files necessary
to fulfill the inquiry.

=head1 BUG REPORTS

Please report bugs or other issues to E<lt>schnell18@rt.cpan.orgE<gt>.

=head1 AUTHOR

This module is developed by Justin Zhang E<lt>fgz@cpan.orgE<gt>.

=head1 COPYRIGHT

This library is free software; you may redistribute and/or modify it
under the same terms as Perl itself.

=cut

# vim: set ai nu nobk expandtab sw=4 ts=4:
