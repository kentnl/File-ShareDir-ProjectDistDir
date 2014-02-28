
use strict;
use warnings;

use Test::More 0.96;
use FindBin;
use lib "$FindBin::Bin/04_files/installdir/lib";
use lib "$FindBin::Bin/04_files/develdir/lib";    # simulate testing in a child project.

use Example_06;

is( Example_06->test(), '06', 'Example 06 returns the right shared value' );

done_testing;

