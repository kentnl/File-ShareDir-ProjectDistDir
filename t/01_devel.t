
use strict;
use warnings;

use Test::More 0.96;
use FindBin;
use lib "$FindBin::Bin/01_files/lib";

use Example_01;

is( Example_01->test() , '01' , 'Example 01 returns the right shared value');

done_testing;



