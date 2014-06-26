#!perl

use 5.010;
use strict;
use warnings;
#use Log::Any '$log';

use Complete::Util qw(parse_shell_cmdline);
use Test::More;

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
