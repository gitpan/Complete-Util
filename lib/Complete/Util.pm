package Complete::Util;

our $DATE = '2014-12-25'; # DATE
our $VERSION = '0.19'; # VERSION

use 5.010001;
use strict;
use warnings;

use Complete;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(
                       hashify_answer
                       arrayify_answer
                       combine_answers
                       complete_array_elem
                       complete_hash_key
                       complete_env
                       complete_file
                       complete_program
               );

our %SPEC;

$SPEC{':package'} = {
    v => 1.1,
    summary => 'General completion routine',
};

$SPEC{hashify_answer} = {
    v => 1.1,
    summary => 'Make sure we return completion answer in hash form',
    description => <<'_',

This function accepts a hash or an array. If it receives an array, will convert
the array into `{words=>$ary}' first to make sure the completion answer is in
hash form.

Then will add keys from `meta` to the hash.

_
    args => {
        arg => {
            summary => '',
            schema  => ['any*' => of => ['array*','hash*']],
            req => 1,
            pos => 0,
        },
        meta => {
            summary => 'Metadata (extra keys) for the hash',
            schema  => 'hash*',
            pos => 1,
        },
    },
    result_naked => 1,
    result => {
        schema => 'hash*',
    },
};
sub hashify_answer {
    my $ans = shift;
    if (ref($ans) ne 'HASH') {
        $ans = {words=>$ans};
    }
    if (@_) {
        my $meta = shift;
        for (keys %$meta) {
            $ans->{$_} = $meta->{$_};
        }
    }
    $ans;
}

$SPEC{arrayify_answer} = {
    v => 1.1,
    summary => 'Make sure we return completion answer in array form',
    description => <<'_',

This is the reverse of `hashify_answer`. It accepts a hash or an array. If it
receives a hash, will return its `words` key.

_
    args => {
        arg => {
            summary => '',
            schema  => ['any*' => of => ['array*','hash*']],
            req => 1,
            pos => 0,
        },
    },
    result_naked => 1,
    result => {
        schema => 'array*',
    },
};
sub arrayify_answer {
    my $ans = shift;
    if (ref($ans) eq 'HASH') {
        $ans = $ans->{words};
    }
    $ans;
}

$SPEC{complete_array_elem} = {
    v => 1.1,
    summary => 'Complete from array',
    description => <<'_',

Will sort the resulting completion list, so you don't have to presort the array.

_
    args => {
        array => { schema=>['array*'=>{of=>'str*'}], pos=>0, req=>1 },
        word  => { schema=>[str=>{default=>''}], pos=>1 },
        ci    => { schema=>['bool'] },
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
    my $ci    = $args{ci} // $Complete::OPT_CI;

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
        ci    => { schema=>['bool'] },
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
    my $ci    = $args{ci} // $Complete::OPT_CI;

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
        ci    => { schema=>['bool'] },
    },
    result_naked => 1,
    result => {
        schema => 'array',
    },
};
sub complete_env {
    my %args  = @_;
    my $word  = $args{word} // "";
    my $ci    = $args{ci} // $Complete::OPT_CI;
    if ($word =~ /^\$/) {
        complete_array_elem(word=>$word, array=>[map {"\$$_"} keys %ENV],
                            ci=>$ci);
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
        ci    => { schema=>'bool' },
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
    my $ci   = $args{ci} // $Complete::OPT_CI;

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
        map_case => {
            schema  => 'bool',
        },
        exp_im_path => {
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
    require Complete::Path;
    require File::Glob;

    my %args   = @_;
    my $word   = $args{word} // "";
    my $ci          = $args{ci} // $Complete::OPT_CI;
    my $map_case    = $args{map_case} // $Complete::OPT_MAP_CASE;
    my $exp_im_path = $args{exp_im_path} // $Complete::OPT_EXP_IM_PATH;
    my $filter = $args{filter};

    # if word is starts with "~/" or "~foo/" replace it temporarily with user's
    # name (so we can restore it back at the end). this is to mimic bash
    # support. note that bash does not support case-insensitivity for "foo".
    my $result_prefix;
    my $starting_path = '.';
    if ($word =~ s!\A(~[^/]*)/!!) {
        $result_prefix = "$1/";
        my @dir = File::Glob::glob($1); # glob will expand ~foo to /home/foo
        return [] unless @dir;
        $starting_path = $dir[0];
    } elsif ($word =~ s!\A((?:\.\.?/+)+|/+)!!) {
        # just an optimization to skip sequences of '../'
        $starting_path = $1;
        $result_prefix = $1;
        $starting_path =~ s#/+\z## unless $starting_path =~ m!\A/!;
    }

    # prepare list_func
    my $list = sub {
        my ($path, $intdir, $isint) = @_;
        opendir my($dh), $path or return undef;
        my @res;
        for (sort readdir $dh) {
            # skip . and .. if leaf is empty, like in bash
            next if ($_ eq '.' || $_ eq '..') && $intdir eq '';
            next if $isint && !(-d "$path/$_");
            push @res, $_;
        }
        \@res;
    };

    # prepare filter_func
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

    Complete::Path::complete_path(
        word => $word,
        ci => $ci, map_case => $map_case, exp_im_path => $exp_im_path,
        list_func => $list,
        is_dir_func => sub { -d $_[0] },
        filter_func => $filter,
        starting_path => $starting_path,
        result_prefix => $result_prefix,
    );
}

$SPEC{combine_answers} = {
    v => 1.1,
    summary => 'Given two or more answers, combine them into one',
    description => <<'_',

This function is useful if you want to provide a completion answer that is
gathered from multiple sources. For example, say you are providing completion
for the Perl tool `cpanm`, which accepts a filename (a tarball like `*.tar.gz`),
a directory, or a module name. You can do something like this:

    combine_answers(
        complete_file(word=>$word, ci=>1),
        complete_module(word=>$word, ci=>1),
    );

_
    args => {
        answers => {
            schema => [
                'array*' => {
                    of => ['any*', of=>['hash*','array*']], # XXX answer_t
                    min_len => 1,
                },
            ],
            req => 1,
            pos => 0,
            greedy => 1,
        },
    },
    args_as => 'array',
    result_naked => 1,
    result => {
        schema => 'hash*',
        description => <<'_',

Return a combined completion answer. Words from each input answer will be
combined, order preserved and duplicates removed. The other keys from each
answer will be merged.

_
    },
};
sub combine_answers {
    require List::Util;

    return undef unless @_;
    return $_[0] if @_ < 2;

    my $final = {words=>[]};
    my $encounter_hash;
    my $add_words = sub {
        my $words = shift;
        for my $entry (@$words) {
            push @{ $final->{words} }, $entry
                unless List::Util::first(
                    sub {
                        (ref($entry) ? $entry->{word} : $entry)
                            eq
                                (ref($_) ? $_->{word} : $_)
                            }, @{ $final->{words} }
                        );
        }
    };

    for my $ans (@_) {
        if (ref($ans) eq 'ARRAY') {
            $add_words->($ans);
        } elsif (ref($ans) eq 'HASH') {
            $encounter_hash++;
            $add_words->($ans->{words} // []);
            for (keys %$ans) {
                next if $_ eq 'words';
                $final->{$_} = $ans->{$_};
            }
        }
    }
    $encounter_hash ? $final : $final->{words};
}

# TODO: complete_filesystem (probably in a separate module)
# TODO: complete_hostname (/etc/hosts, ~/ssh/.known_hosts, ...)
# TODO: complete_package (deb, rpm, ...)

1;
# ABSTRACT: General completion routine

__END__

=pod

=encoding UTF-8

=head1 NAME

Complete::Util - General completion routine

=head1 VERSION

This document describes version 0.19 of Complete::Util (from Perl distribution Complete-Util), released on 2014-12-25.

=head1 DESCRIPTION

=head1 FUNCTIONS


=head2 arrayify_answer(%args) -> array

Make sure we return completion answer in array form.

This is the reverse of C<hashify_answer>. It accepts a hash or an array. If it
receives a hash, will return its C<words> key.

Arguments ('*' denotes required arguments):

=over 4

=item * B<arg>* => I<array|hash>

=back

Return value:

 (array)


=head2 combine_answers($answers, ...) -> hash

Given two or more answers, combine them into one.

This function is useful if you want to provide a completion answer that is
gathered from multiple sources. For example, say you are providing completion
for the Perl tool C<cpanm>, which accepts a filename (a tarball like C<*.tar.gz>),
a directory, or a module name. You can do something like this:

 combine_answers(
     complete_file(word=>$word, ci=>1),
     complete_module(word=>$word, ci=>1),
 );

Arguments ('*' denotes required arguments):

=over 4

=item * B<answers>* => I<array>

=back

Return value:

 (hash)

Return a combined completion answer. Words from each input answer will be
combined, order preserved and duplicates removed. The other keys from each
answer will be merged.


=head2 complete_array_elem(%args) -> array

Complete from array.

Will sort the resulting completion list, so you don't have to presort the array.

Arguments ('*' denotes required arguments):

=over 4

=item * B<array>* => I<array>

=item * B<ci> => I<bool>

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

=item * B<ci> => I<bool>

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

=item * B<exp_im_path> => I<bool>

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

=item * B<map_case> => I<bool>

=item * B<word> => I<str> (default: "")

=back

Return value:

 (array)


=head2 complete_hash_key(%args) -> array

Complete from hash keys.

Arguments ('*' denotes required arguments):

=over 4

=item * B<ci> => I<bool>

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


=head2 hashify_answer(%args) -> hash

Make sure we return completion answer in hash form.

This function accepts a hash or an array. If it receives an array, will convert
the array into `{words=>$ary}' first to make sure the completion answer is in
hash form.

Then will add keys from C<meta> to the hash.

Arguments ('*' denotes required arguments):

=over 4

=item * B<arg>* => I<array|hash>

=item * B<meta> => I<hash>

Metadata (extra keys) for the hash.

=back

Return value:

 (hash)

=for Pod::Coverage ^(complete_array)$

=head1 SEE ALSO

L<Complete>

If you want to do bash tab completion with Perl, take a look at
L<Complete::Bash> or L<Getopt::Long::Complete> or L<Perinci::CmdLine>.

Other C<Complete::*> modules.

=head1 HOMEPAGE

Please visit the project's homepage at L<https://metacpan.org/release/Complete-Util>.

=head1 SOURCE

Source repository is at L<https://github.com/sharyanto/perl-SHARYANTO-Complete-Util>.

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
