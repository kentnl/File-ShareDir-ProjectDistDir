use strict;
use warnings;

package Example_02;

use File::ShareDir::ProjectDistDir;

use Path::Class::File;

sub test {
  return scalar Path::Class::File->new( dist_file('Example_02', 'file') )->slurp();
}


1;
