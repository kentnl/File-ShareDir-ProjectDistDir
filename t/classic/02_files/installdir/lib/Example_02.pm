use strict;
use warnings;

package Example_02;

use File::ShareDir::ProjectDistDir;

use Path::Tiny qw(path);

sub test {
  return scalar path( dist_file( 'Example_02', 'file' ) )->slurp();
}

1;
