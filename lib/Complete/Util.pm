package Complete::Util;

our $DATE = '2014-07-13'; # DATE
our $VERSION = '0.13'; # VERSION

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
    my $filter = $args{filter};

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

    my @all;
    if ($word =~ m!(\A|/)\z!) {
        my $dir = length($word) ? $word : ".";
        opendir my($dh), $dir or return [];
        @all = map { ($dir eq '.' ? '' : $dir) . $_ }
            grep { $_ ne '.' && $_ ne '..' } readdir($dh);
        closedir $dh;
    } else {
        # must add wildcard char, glob() is convoluted. also {a,b} is
        # interpreted by glob() (not so by bash file completion). also
        # whitespace is interpreted by glob :(. later should replace with a
        # saner one, like wildcard2re.
        @all = glob("$word*");
    }

    my @words;
    for (@all) {
        next if $filter && !$filter->($_);
        $_ = "$_/" if (-d $_) && !m!/\z!; # XXX double stat
        #s!.+/(.+)!$1!;
        push @words, $_;
    }

    my $w = complete_array_elem(array=>\@words);
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

This document describes version 0.13 of Complete::Util (from Perl distribution Complete-Util), released on 2014-07-13.

=head1 DESCRIPTION

=head1 FUNCTIONS


=head2 complete_array_elem(%args) -> array

Complete from array.

Arguments ('*' denotes required arguments):

=over 4

=item * B<array>* => I<array>

=item * B<ci> => I<bool> (default: 0)

=item * B<word> => I<str> (default: "")

=back

Return value:


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


=head2 complete_file(%args) -> array

Complete file and directory from local filesystem.

Arguments ('*' denotes required arguments):

=over 4

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


=head2 complete_hash_key(%args) -> array

Complete from hash keys.

Arguments ('*' denotes required arguments):

=over 4

=item * B<ci> => I<bool> (default: 0)

=item * B<hash>* => I<hash>

=item * B<word> => I<str> (default: "")

=back

Return value:


=head2 complete_program(%args) -> array

Complete program name found in PATH.

Windows is supported, on Windows PATH will be split using /;/ instead of /:/.

Arguments ('*' denotes required arguments):

=over 4

=item * B<word> => I<str> (default: "")

=back

Return value:

=for Pod::Coverage ^(complete_array)$

=head1 SEE ALSO

L<Complete>

If you want to do bash tab completion with Perl, take a look at
L<Complete::Bash> and L<Complete::BashGen>.

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

Steven Haryanto <stevenharyanto@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2014 by Steven Haryanto.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
