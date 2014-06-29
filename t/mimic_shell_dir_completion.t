#!perl

use 5.010;
use strict;
use warnings;

use Test::More 0.98;

use Complete::Util qw(mimic_shell_dir_completion);

test_complete(
    completion => [],
    result     => [],
);
test_complete(
    completion => ['a', 'a/'],
    result     => ['a', 'a/'],
);
test_complete(
    completion => ['a'],
    result     => ['a'],
);
test_complete(
    completion => ['a/'],
    result     => ['a/', 'a/ '],
);

wDONE_TESTING:
done_testing;

sub test_complete {
    my (%args) = @_;

    my $name = $args{name} // join(",", @{ $args{completion} });
    my $res = mimic_shell_dir_completion($args{completion});
    is_deeply($res, $args{result}, "$name (result)")
        or diag explain($res);
}
