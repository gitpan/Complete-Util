#!perl

use 5.010;
use strict;
use warnings;
#use Log::Any '$log';

use File::Which;
use Complete::Util qw(parse_shell_cmdline);
use Test::More;

plan skip_all => "bash needed" unless which("bash");

subtest "_line_to_argv" => sub {
    is_deeply(
        Complete::Util::_line_to_argv(
            q{"1 '$HOME" '$HOME "'   3 4}),
        [qq{1 '$ENV{HOME}}, q{$HOME "}, q{3}, q{4}],
        "basics"
    );

    # this is just a diagnosis output if testing doesn't match. some CPAN
    # Testers setup has ~/fake as their home, don't know how to work around it
    # yet.
    {
        my @res = explain(Complete::Util::_line_to_argv(
            qq{$ENV{HOME} $ENV{HOME}/ /$ENV{HOME} $ENV{HOME}x}));
        my $res = join '', @res;
        my $expected = <<_;
[
  '~',
  '~/',
  '/$ENV{HOME}',
  '$ENV{HOME}x'
]
_
        diag "Warning, there is a mismatch for test 'replace \$HOME with ~':\n".
            "Result:\n$res\n\nExpected:\n$expected"
                unless $res eq $expected;
    }

    is_deeply(
        Complete::Util::_line_to_argv(
            q{"a}),
        [],
        "unclosed quotes"
    );
};

is_deeply(
    parse_shell_cmdline("foo bar baz qux", 0),
    {words => [qw/bar baz qux/], cword=>0},
    "simple 1",
);
is_deeply(
    parse_shell_cmdline("foo bar baz qux", 3),
    {words => [qw/bar baz qux/], cword=>0},
    "simple 2",
);
is_deeply(
    parse_shell_cmdline("foo bar baz qux", 4),
    {words => [qw/baz qux/], cword=>0},
    "simple 3",
);

done_testing;
