
use strict;
use warnings;

use Test::More 0.96;
use FindBin;
use lib "$FindBin::Bin/03_files/installdir/lib";
use lib "$FindBin::Bin/03_files/develdir/lib"; # simulate testing in a child project.

use Example_04;
use Example_05;

is( Example_04->test() , '04' , 'Example 04 returns the right shared value');
is( Example_05->test() , '05' , 'Example 05 returns the right shared value');

done_testing;



