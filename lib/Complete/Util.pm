package Complete::Util;

our $DATE = '2014-12-05'; # DATE
our $VERSION = '0.14'; # VERSION

use 5.010001;
use strict;
use warnings;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(
                       complete_array_elem
                       complete_hash_key
                       complete_env
                       complete_file
                       complete_program
               );

our %SPEC;

$SPEC{complete_array_elem} = {
    v => 1.1,
    summary => 'Complete from array',
    description => <<'_',

Will sort the resulting completion list, so you don't have to presort the array.

_
    args => {
        array => { schema=>['array*'=>{of=>'str*'}], pos=>0, req=>1 },
        word  => { schema=>[str=>{default=>''}], pos=>1 },
        ci    => { schema=>[bool=>{default=>0}] },
    },
    result_naked => 1,
    result => {
        schema => 'array',
    },
};
sub complete_array_elem {
    my %args  = @_;
    my $array = $args{array} or die "Please specify array";
    my $word  = $args{word} // "";
    my $ci    = $args{ci};

    my $wordu = uc($word);
    my @words;
    for (@$array) {
        next unless 0==($ci ? index(uc($_), $wordu) : index($_, $word));
        push @words, $_;
    }
    $ci ? [sort {lc($a) cmp lc($b)} @words] : [sort @words];
}

*complete_array = \&complete_array_elem;

$SPEC{complete_hash_key} = {
    v => 1.1,
    summary => 'Complete from hash keys',
    args => {
        hash  => { schema=>['hash*'=>{}], pos=>0, req=>1 },
        word  => { schema=>[str=>{default=>''}], pos=>1 },
        ci    => { schema=>[bool=>{default=>0}] },
    },
    result_naked => 1,
    result => {
        schema => 'array',
    },
};
sub complete_hash_key {
    my %args  = @_;
    my $hash  = $args{hash} or die "Please specify hash";
    my $word  = $args{word} // "";
    my $ci    = $args{ci};

    complete_array_elem(word=>$word, array=>[keys %$hash], ci=>$ci);
}

$SPEC{complete_env} = {
    v => 1.1,
    summary => 'Complete from environment variables',
    description => <<'_',

On Windows, environment variable names are all converted to uppercase. You can
use case-insensitive option (`ci`) to match against original casing.

_
    args => {
        word  => { schema=>[str=>{default=>''}], pos=>0 },
        ci    => { schema=>[bool=>{default=>0}] },
    },
    result_naked => 1,
    result => {
        schema => 'array',
    },
};
sub complete_env {
    my %args  = @_;
    my $word  = $args{word} // "";
    my $ci    = $args{ci};
    if ($word =~ /^\$/) {
        complete_array_elem(word=>$word, array=>[map {"\$$_"} keys %ENV], ci=>$ci);
    } else {
        complete_array_elem(word=>$word, array=>[keys %ENV], ci=>$ci);
    }
}

$SPEC{complete_program} = {
    v => 1.1,
    summary => 'Complete program name found in PATH',
    description => <<'_',

Windows is supported, on Windows PATH will be split using /;/ instead of /:/.

_
    args => {
        word  => { schema=>[str=>{default=>''}], pos=>0 },
        ci => { schema=>'bool' },
    },
    result_naked => 1,
    result => {
        schema => 'array',
    },
};
sub complete_program {
    require List::MoreUtils;

    my %args = @_;
    my $word = $args{word} // "";
    my $ci   = $args{ci};

    my $word_re = $ci ? qr/\A\Q$word/i : qr/\A\Q$word/;

    my @res;
    my @dirs = split(($^O =~ /Win32/ ? qr/;/ : qr/:/), $ENV{PATH});
    for my $dir (@dirs) {
        opendir my($dh), $dir or next;
        for (readdir($dh)) {
            push @res, $_ if $_ =~ $word_re && !(-d "$dir/$_") && (-x _);
        };
    }

    [sort(List::MoreUtils::uniq(@res))];
}

$SPEC{complete_file} = {
    v => 1.1,
    summary => 'Complete file and directory from local filesystem',
    args => {
        word => {
            schema  => [str=>{default=>''}],
            pos     => 0,
        },
        ci => {
            summary => 'Case-insensitive matching',
            schema  => 'bool',
        },
        filter => {
            summary => 'Only return items matching this filter',
            description => <<'_',

Filter can either be a string or a code.

For string filter, you can specify a pipe-separated groups of sequences of these
characters: f, d, r, w, x. Dash can appear anywhere in the sequence to mean
not/negate. An example: `f` means to only show regular files, `-f` means only
show non-regular files, `drwx` means to show only directories which are
readable, writable, and executable (cd-able). `wf|wd` means writable regular
files or writable directories.

For code filter, you supply a coderef. The coderef will be called for each item
with these arguments: `$name`. It should return true if it wants the item to be
included.

_
            schema  => ['any*' => {of => ['str*', 'code*']}],
        },
    },
    result_naked => 1,
    result => {
        schema => 'array',
    },
};
sub complete_file {
    my %args   = @_;
    my $word   = $args{word} // "";
    my $ci     = $args{ci};
    my $filter = $args{filter};

    # if word is starts with "~/" or "~foo/" replace it temporarily with user's
    # name (so we can restore it back at the end). this is to mimic bash
    # support. note that bash does not support case-insensitivity for "foo".
    my $res_prefix; # to be added again to final result
    my $search_prefix = ''; # to be added when searching
    my $res_num_remove = 0;
    if ($word =~ s!\A(~[^/]*)/!!) {
        $res_prefix = "$1/";
        my @dir = glob($1); # glob will expand ~foo to /home/foo
        return [] unless @dir;
        $search_prefix = $dir[0] =~ m!/\z! ? $dir[0] : "$dir[0]/";
        $res_num_remove = length($search_prefix);
    } elsif ($word =~ s!\A((?:\.\.?/+)+|/+)!!) {
        $search_prefix = $1;
        $search_prefix =~ s#/+\z## unless $search_prefix =~ m!\A/!;
    } else {
        $search_prefix = '';
    }

    # prepare filter sub
    if ($filter && !ref($filter)) {
        my @seqs = split /\s*\|\s*/, $filter;
        $filter = sub {
            my $name = shift;
            my @st = stat($name) or return 0;
            my $mode = $st[2];
            my $pass;
          SEQ:
            for my $seq (@seqs) {
                my $neg = sub { $_[0] };
                for my $c (split //, $seq) {
                    if    ($c eq '-') { $neg = sub { $_[0] ? 0 : 1 } }
                    elsif ($c eq 'r') { next SEQ unless $neg->($mode & 0400) }
                    elsif ($c eq 'w') { next SEQ unless $neg->($mode & 0200) }
                    elsif ($c eq 'x') { next SEQ unless $neg->($mode & 0100) }
                    elsif ($c eq 'f') { next SEQ unless $neg->($mode & 0100000)}
                    elsif ($c eq 'd') { next SEQ unless $neg->($mode & 0040000)}
                    else {
                        die "Unknown character in filter: $c (in $seq)";
                    }
                }
                $pass = 1; last SEQ;
            }
            $pass;
        };
    }

    # split word by dirs, as we want to dig level by level (needed when doing
    # case-insensitive search on a case-sensitive fs). XXX we should optimize
    # and not split .. or .
    my @intermediate_dirs = split m!/+!, $word;
    @intermediate_dirs = ('') if !@intermediate_dirs;
    push @intermediate_dirs, '' if $word =~ m!/\z!;

    # extract leaf path, because this one is treated differently
    my $leaf = pop @intermediate_dirs;
    @intermediate_dirs = ('') if !@intermediate_dirs;

    #say "D:search_prefix=<$search_prefix>";
    #say "D:intermediate_dirs=[",join(", ", map{"<$_>"} @intermediate_dirs),"]";
    #say "D:leaf=<$leaf>";

    # candidate for intermediate paths. when doing case-insensitive search,
    # there maybe multiple candidate paths for each dir, for example if
    # word='../foo/s' and there is '../foo/Surya', '../Foo/sri', '../FOO/SUPER'
    # then candidate paths would be ['../foo', '../Foo', '../FOO'] and the
    # filename should be searched inside all those dirs. everytime we drill down
    # to deeper subdirectories, we adjust this list.
    my @candidate_paths;

    for my $i (0..$#intermediate_dirs) {
        my $intdir = $intermediate_dirs[$i];
        my @dirs;
        if ($i == 0) {
            # first path elem, we search search_prefix first since
            # candidate_paths is still empty.
            @dirs = ($search_prefix);
        } else {
            # subsequent path elem, we search all candidate_paths
            @dirs = @candidate_paths;
        }

        if ($i == $#intermediate_dirs && $intdir eq '') {
            @candidate_paths = @dirs;
            last;
        }

        my @new_candidate_paths;
        for my $dir (@dirs) {
            #say "D:  intdir opendir($dir)";
            opendir my($dh), ($dir eq '' ? '.' : $dir) or next;
            # check if the deeper level is a directory with the expected name
            my $re = $ci ? qr/\A\Q$intdir\E\z/i : qr/\A\Q$intdir\E\z/;
            #say "D:  re=$re";
            for (sort readdir $dh) {
                #say "D:  $_";
                next unless $_ =~ $re;
                # skip . and .. if leaf is empty, like in bash
                next if ($_ eq '.' || $_ eq '..') && $intdir eq '';
                my $p = $dir =~ m!\A\z|/\z! ? "$dir$_" : "$dir/$_";
                next unless -d $p;
                push @new_candidate_paths, $p;
            }
        }
        #say "D:  candidate_paths=[",join(", ", map{"<$_>"} @new_candidate_paths),"]";
        return [] unless @new_candidate_paths;
        @candidate_paths = @new_candidate_paths;
    }

    my @res;
    for my $dir (@candidate_paths) {
        #say "D:opendir($dir)";
        opendir my($dh), ($dir eq '' ? '.' : $dir) or next;
        my $re = $ci ? qr/\A\Q$leaf/i : qr/\A\Q$leaf/;
        #say "D:re=$re";
        for (sort readdir $dh) {
            next unless $_ =~ $re;
            # skip . and .. if leaf is empty, like in bash
            next if ($_ eq '.' || $_ eq '..') && $leaf eq '';
            my $p = $dir =~ m!\A\z|/\z! ? "$dir$_" : "$dir/$_";
            next if $filter && !$filter->($p);

            # process into final result
            substr($p, 0, $res_num_remove) = '' if $res_num_remove;
            $p = "$res_prefix$p" if length($res_prefix);
            $p .= "/" if -d $p;

            push @res, $p;
        }
    }

    \@res;
}

# TODO: complete_filesystem (probably in a separate module)
# TODO: complete_hostname (/etc/hosts, ~/ssh/.known_hosts, ...)
# TODO: complete_package (deb, rpm, ...)

1;
# ABSTRACT: General completion routines

__END__

=pod

=encoding UTF-8

=head1 NAME

Complete::Util - General completion routines

=head1 VERSION

This document describes version 0.14 of Complete::Util (from Perl distribution Complete-Util), released on 2014-12-05.

=head1 DESCRIPTION

=head1 FUNCTIONS


=head2 complete_array_elem(%args) -> array

Complete from array.

Will sort the resulting completion list, so you don't have to presort the array.

Arguments ('*' denotes required arguments):

=over 4

=item * B<array>* => I<array>

=item * B<ci> => I<bool> (default: 0)

=item * B<word> => I<str> (default: "")

=back

Return value:

 (array)


=head2 complete_env(%args) -> array

Complete from environment variables.

On Windows, environment variable names are all converted to uppercase. You can
use case-insensitive option (C<ci>) to match against original casing.

Arguments ('*' denotes required arguments):

=over 4

=item * B<ci> => I<bool> (default: 0)

=item * B<word> => I<str> (default: "")

=back

Return value:

 (array)


=head2 complete_file(%args) -> array

Complete file and directory from local filesystem.

Arguments ('*' denotes required arguments):

=over 4

=item * B<ci> => I<bool>

Case-insensitive matching.

=item * B<filter> => I<code|str>

Only return items matching this filter.

Filter can either be a string or a code.

For string filter, you can specify a pipe-separated groups of sequences of these
characters: f, d, r, w, x. Dash can appear anywhere in the sequence to mean
not/negate. An example: C<f> means to only show regular files, C<-f> means only
show non-regular files, C<drwx> means to show only directories which are
readable, writable, and executable (cd-able). C<wf|wd> means writable regular
files or writable directories.

For code filter, you supply a coderef. The coderef will be called for each item
with these arguments: C<$name>. It should return true if it wants the item to be
included.

=item * B<word> => I<str> (default: "")

=back

Return value:

 (array)


=head2 complete_hash_key(%args) -> array

Complete from hash keys.

Arguments ('*' denotes required arguments):

=over 4

=item * B<ci> => I<bool> (default: 0)

=item * B<hash>* => I<hash>

=item * B<word> => I<str> (default: "")

=back

Return value:

 (array)


=head2 complete_program(%args) -> array

Complete program name found in PATH.

Windows is supported, on Windows PATH will be split using /;/ instead of /:/.

Arguments ('*' denotes required arguments):

=over 4

=item * B<ci> => I<bool>

=item * B<word> => I<str> (default: "")

=back

Return value:

 (array)

=for Pod::Coverage ^(complete_array)$

=head1 SEE ALSO

L<Complete>

If you want to do bash tab completion with Perl, take a look at
L<Complete::Bash> or L<Getopt::Long::Complete> or L<Perinci::CmdLine>.

Other C<Complete::*> modules.

=head1 HOMEPAGE

Please visit the project's homepage at L<https://metacpan.org/release/Complete-Util>.

=head1 SOURCE

Source repository is at L<https://github.com/perlancar/perl-Complete-Util>.

=head1 BUGS

Please report any bugs or feature requests on the bugtracker website L<https://rt.cpan.org/Public/Dist/Display.html?Name=Complete-Util>

When submitting a bug or request, please include a test-file or a
patch to an existing test-file that illustrates the bug or desired
feature.

=head1 AUTHOR

perlancar <perlancar@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2014 by perlancar@cpan.org.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
