use strict;
use warnings;

package Example_04;

use File::ShareDir::ProjectDistDir qw( :all ), distname => "Example_04";

use Path::Tiny qw(path);

sub test {
  return scalar path( dist_file('file') )->slurp();
}

1;
