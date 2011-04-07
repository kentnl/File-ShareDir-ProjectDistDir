use strict;
use warnings;
package File::ShareDir::ProjectDistDir;

# ABSTRACT: Simple set-and-forget using of a '/share' directory in your projects root

=head1 SYNOPSIS

  package An::Example::Package;

  use File::ShareDir::ProjectDistDir qw( dist_dir );

  # during development, $dir will be $projectroot/share
  # but once installed, it will be wherever File::Sharedir thinks it is.
  my $dir = dist_dir('An-Example')

Project layout requirements:

  $project/
  $project/lib/An/Example/Package.pm
  $project/share/   # files for package 'An-Example' go here.

=cut

1;
