#!perl

use 5.010;
use strict;
use warnings;

use File::chdir;
use File::Temp qw(tempdir);
use Test::More;

use Complete::Util qw(complete_file);

sub mkfiles { open my($fh), ">$_" for @_ }
sub mkdirs  { mkdir $_ for @_ }

my $rootdir = tempdir(CLEANUP=>1);
$CWD = $rootdir;
mkfiles(qw(a ab abc ac bb d .h1));
mkdirs (qw(dir1 dir2 foo));
mkdirs (qw(dir1/sub1 dir2/sub2 dir2/sub3));
mkfiles(qw(foo/f1 foo/f2 foo/g));

mkdirs (qw(Food));
mkdirs (qw(Food/Sub4));
mkfiles(qw(Food/f1 Food/F2));

test_complete(
    word      => '',
    result    => [qw(.h1 Food/ a ab abc ac bb d dir1/ dir2/ foo/)],
);
test_complete(
    word      => 'a',
    result    => [qw(a ab abc ac)],
);
test_complete(
    # dir + file
    word      => 'd',
    result    => [qw(d dir1/ dir2/)],
);
test_complete(
    # file only
    word       => 'd',
    other_args => [filter=>'-d'],
    result     => [qw(d)],
);
test_complete(
    # dir only, use |, not very meaningful test
    word       => 'd',
    other_args => [filter=>'d|-f'],
    result     => [qw(dir1/ dir2/)],
);
test_complete(
    # code filter
    word       => '',
    other_args => [filter=>sub {(-d $_[0]) && $_[0] =~ /^f/}],
    result     => [qw(foo/)],
);
test_complete(
    # subdir 1
    word      => 'foo/',
    result    => ["foo/f1", "foo/f2", "foo/g"],
);
test_complete(
    # subdir 2
    word      => 'foo/f',
    result    => ["foo/f1", "foo/f2"],
);

subtest ci => sub {
    test_complete(
        word      => 'f',
        ci        => 1,
        result    => ["Food/", "foo/"],
    );
    test_complete(
        word      => 'F',
        ci        => 1,
        result    => ["Food/", "foo/"],
    );
    test_complete(
        word      => 'Food/f',
        ci        => 1,
        result    => ["Food/F2", "Food/f1"],
    );
    # XXX test foo/ and Foo/ exists, but this requires that fs is case-sensitive
};

# XXX test ../blah
# XXX test /abs
# XXX test ~/blah and ~user/blah

DONE_TESTING:
$CWD = "/";
done_testing();

sub test_complete {
    my (%args) = @_;

    my $name = $args{name} // $args{word};
    my $res = complete_file(
        word=>$args{word}, array=>$args{array}, ci=>$args{ci},
        @{ $args{other_args} // [] });
    is_deeply($res, $args{result}, "$name (result)") or diag explain($res);
}
