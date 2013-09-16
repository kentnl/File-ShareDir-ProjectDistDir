use strict;
use warnings;

package Example_05;

use File::ShareDir::ProjectDistDir qw( :all ), defaults => { distname => 'Example_05' };

use Path::Class::File;

sub test {
  return scalar Path::Class::File->new( dist_file('file') )->slurp();
}

1;
