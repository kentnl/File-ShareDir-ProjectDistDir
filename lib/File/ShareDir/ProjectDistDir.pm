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

use Path::Class::File;
use Sub::Exporter qw(build_exporter);

use File::ShareDir qw( dist_dir dist_file );

my ($exporter) = build_exporter(
  {
    exports    => [ dist_dir => \&build_dist_dir, dist_file => \&build_dist_file ],
    groups     => { all      => [qw( dist_dir dist_file )] },
    collectors => ['filename'],
  }
);

sub import {
  my ( $class, @args ) = @_;
  my $has_filename = undef;

  my ( $xclass, $xfilename, $xline ) = caller();

  for ( 0 .. $#args - 1 ) {
    if ( $args[$_] and $args[ $_ + 1 ] and $args[$_] eq 'filename' and not ref $args[ $_ + 1 ] ) {
      $has_filename = 1;
      last;
    }
  }
  if ( not $has_filename ) {
    push @_, 'filename' => $xfilename;
  }
  goto $exporter;
}

sub _devel_root {
  my ($filename) = @_;
  my $file       = Path::Class::File->new($filename);
  my $dir        = $file->dir->absolute;
  while ( $dir->dir_list() and $dir->dir_list(-1) ne 'lib' ) {
    $dir = $dir->parent;
  }
  if ( -d $dir->subdir('share') ) {
    return $dir;
  }
  return;
}

sub build_dist_dir {
  my ( $class, $name, $arg, $col ) = @_;
  my $root = _devel_root( $col->{filename} );
  if ( not $root ) {
    return \&dist_dir;
  }
  return sub {

    # if the caller is devel, then we return the project root,
    # regardless of what package you asked for.
    # Might be bad, but we haven't imagined the scenario where yet.
    return $root->stringify;
  };
}

sub build_dist_file {
  my ( $class, $name, $arg, $col ) = @_;
  my $root = _devel_root( $col->{filename} );
  if ( not $root ) {
    return \&dist_file;
  }
  return sub {

    # if the caller is devel, then we return the project root,
    # regardless of what package you asked for.
    # Might be bad, but we haven't imagined the scenario where yet.
    my $path = $root->file( $_[1] )->absolute->stringify;
    return undef unless -e $path;
    if ( not -f $path ) {
      require Carp;
      Carp::croak("Found dist_file '$path', but not a file");
    }
    if ( not -r $path ) {
      require Carp;
      Carp::croak("File '$path', no read permissions");
    }
    return $path;
  };
}

1;
