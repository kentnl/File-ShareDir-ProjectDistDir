
use strict;
use warnings;

use Test::More 0.96;
use FindBin;
use lib "$FindBin::Bin/02_files/installdir/lib";
use lib "$FindBin::Bin/02_files/develdir/lib";    # simulate testing in a child project.

use Example_02;

is( Example_02->test(), '02', 'Example 02 returns the right shared value' );

done_testing;

