use strict;
use warnings;

package Example_01;

use File::ShareDir::ProjectDistDir;

use Path::Class::File;

sub test {
  return scalar Path::Class::File->new( dist_file('Example_01', 'file') )->slurp();
}


1;
