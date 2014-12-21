#!perl

use 5.010;
use strict;
use warnings;

use Test::More 0.98;

use Complete::Util qw(combine_answers);

test_combine(
    name   => 'empty',
    input  => [],
    result => undef,
);

test_combine(
    name   => 'arrays of scalars',
    input  => [[1, 2], [4, 2, 3]],
    result => [1, 2, 4, 3],
);

test_combine(
    name   => 'arrays of scalars+hashes',
    input  => [[1, 2], [4, 2, 3], [{word=>5, description=>"five"}], [5, 7]],
    result => [1, 2, 4, 3, {word=>5, description=>"five"}, 7],
);

test_combine(
    name   => 'arrays + hashes',
    input  => [
        [1, 2],
        {words=>[4, 2, 3], path_sep=>'::', escmode=>'none'},
        [{word=>5, description=>"five"}],
        {words=>[5, 7], path_sep=>'/'},
    ],
    result => {
        words => [1, 2, 4, 3, {word=>5, description=>"five"}, 7],
        path_sep => '/',
        escmode => 'none',
    },
);

done_testing();

sub test_combine {
    my (%args) = @_;

    subtest $args{name} => sub {
        my $res = combine_answers(@{ $args{input} });
        is_deeply($res, $args{result}) or diag explain($res);
    };
}
