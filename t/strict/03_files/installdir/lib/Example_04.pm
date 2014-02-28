use strict;
use warnings;

package Example_04;

use File::ShareDir::ProjectDistDir ':all', strict => 1;

use Path::Class::File;

sub test {
  return scalar Path::Class::File->new( dist_file( 'Example_04', 'file' ) )->slurp();
}

1;
