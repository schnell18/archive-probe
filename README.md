NAME
----
Archive::Probe - A generic library to search file within archive

SYNOPSIS
--------
````perl
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
````

DESCRIPTION
-----------

Archive::Probe is a generic library to search file within archive.

It facilitates searching of particular file by name or content inside
deeply nested archive with mixed types. It supports common archive
types such as .tar, .tgz, .bz2, .rar, .zip .7z and Java archive such
as .jar, .war, .ear. If the target archive file contains another
archive file of same or other type, this module extracts the embedded
archive to fulfill the inquiry. The level of embedding is unlimited.
This module depends on unzip, unrar, 7za and tar which are assumed to
be present in PATH. The 7za is part of 7zip utility. It is preferred
tool to deal with .zip archive it runs faster and handles meta
character better than unzip. The 7zip is open source software and you
download and install it from [www.7-zip.org][1] or install the binary
package p7zip with your favorite package management software. The
unrar is freeware and you get it from [rarlab][2].


METHODS
-------

    $probe = Archive::Probe->new()

Creates a new "Archive::Probe" object.

    $probe->add_pattern(regex, coderef)

Register a file pattern to search with in the archive file(s) and the
callback code to handle the matched files. The callback will be passed
two arguments:

$pattern
    This is the pattern of the matched files.

$file_ref
    This is the array reference to the files matched the pattern. The
    existence of the files is controlled by the second argument to the
    "search()" method.

    $probe->search(base_dir, extract_matched)

Search registered files under 'base_dir' and invoke the callback. It
requires two arguments:

$base_dir
    This is the directory containing the archive file(s).

$extract_matched
    Extract or copy the matched files to the working directory if this
    parameter evaluate to true.

    $probe->reset_matches()

Reset the matched files list.

ACCESSORS
---------

    $probe->working_dir([directory])

Set or get the working directory where the temporary files will be
created.

    $show_extracting_output->working_dir([BOOL])

Enable or disable the output of command line archive tool.

HOW IT WORKS
------------

"Archive::Probe" provides low level code to search files in nested
archive files. It does the heavy lifting to extract mininal files
necessary to fulfill the inquiry.

BUG REPORTS
-----------

Please report bugs or other issues to <schnell18@gmail.com>.

AUTHOR
------

This module is developed by Justin Zhang <schnell18@gmail.com>.

COPYRIGHT
---------

Copyright 2013 schnell18
This library is free software; you may redistribute and/or modify it
under the same terms as Perl itself.

[1]: http://www.7-zip.org "7zip official site"
[2]: http://www.rarlab.com/rar_add.htm "RAR Lab download page"