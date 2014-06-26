#!perl

# TODO

use 5.010;
use strict;
use warnings;

use File::Slurp::Tiny qw(write_file);
use File::Temp qw(tempdir);
use Filesys::Cap qw(fs_is_cs);
use Test::More 0.98;
use Complete::Util qw(complete_program);

sub mkexe { write_file($_[0], ""); chmod 0755, $_[0] }

my $dir = tempdir(CLEANUP=>1);
mkdir("$dir/dir1");
mkdir("$dir/dir2");
mkexe("$dir/dir1/prog1");
mkexe("$dir/dir1/prog2");
mkexe("$dir/dir2/prog3");

{
    local $^O = 'linux';
    local $ENV{PATH} = "$dir/dir1:$dir/dir2";
    is_deeply(complete_program(word=>"prog"), ["prog1","prog2","prog3"]);
    is_deeply(complete_program(word=>"prog3"), ["prog3"]);
    is_deeply(complete_program(word=>"prog9"), []);
}

subtest "win support" => sub {
    local $^O = 'MSWin32';
    local $ENV{PATH} = "$dir/dir1;$dir/dir2";
    is_deeply(complete_program(word=>"prog"), ["prog1","prog2","prog3"]);
    is_deeply(complete_program(word=>"prog3"), ["prog3"]);
    is_deeply(complete_program(word=>"prog9"), []);
};

subtest "ci" => sub {
    plan skip_all => "Filesystem is not case-sensitive"
        unless fs_is_cs($dir);

    mkexe("$dir/dir1/Prog3");
    mkexe("$dir/dir1/Prog4");

    local $^O = 'linux';
    local $ENV{PATH} = "$dir/dir1:$dir/dir2";

    is_deeply(complete_program(word=>"prog", ci=>1),
              [sort("prog1","prog2","prog3","Prog3","Prog4")]);
};

done_testing;
