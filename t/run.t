use 5.6.0;

use strict;
use warnings;

use lib 't/lib';

use DBM::Deep;

use Test1;
use Test2;

my $test1 = Test1->new(
    data => {
        key1 => 'value1',
        key2 => undef,
        key3 => 1.23,
    },
);

my %test2;
$test2{"key $_"} = "value $_" for 1 .. 4000;

my $test2 = Test1->new(
    data => \%test2,
);

my $test3 = Test2->new(
    data => [
        1 .. 5,
    ],
);

Test::Class->runtests(
    $test1,
    $test3,
);
