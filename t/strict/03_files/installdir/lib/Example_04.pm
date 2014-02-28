use strict;
use warnings;

package Example_04;

use File::ShareDir::ProjectDistDir ':all', strict => 1;

use Path::Tiny qw(path);

sub test {
  return scalar path( dist_file( 'Example_04', 'file' ) )->slurp();
}

1;
