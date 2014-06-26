#!perl

use 5.010;
use strict;
use warnings;
#use Log::Any '$log';

use Complete::Util qw(break_cmdline_into_words);
use Test::More;

is_deeply(break_cmdline_into_words(cmdline=>q[]), [qw//]);
is_deeply(break_cmdline_into_words(cmdline=>q[a]), [qw/a/]);
is_deeply(break_cmdline_into_words(cmdline=>q[a b ]), [qw/a b/]);
is_deeply(break_cmdline_into_words(cmdline=>q[ a b]), [qw/a b/]);
is_deeply(break_cmdline_into_words(cmdline=>q[a "b c"]), ["a", "b c"]);
is_deeply(break_cmdline_into_words(cmdline=>q[a "b c]), ["a", "b c"]);
is_deeply(break_cmdline_into_words(cmdline=>q[a 'b "c']), ['a', 'b "c']);
is_deeply(break_cmdline_into_words(cmdline=>q[a\ b]), ["a b"]);

done_testing;
