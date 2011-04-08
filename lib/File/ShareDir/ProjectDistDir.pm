use strict;
use warnings;

package File::ShareDir::ProjectDistDir;
BEGIN {
  $File::ShareDir::ProjectDistDir::VERSION = '0.1.0'; # TRIAL
}

# ABSTRACT: Simple set-and-forget using of a '/share' directory in your projects root


use Path::Class::File;
use Sub::Exporter qw(build_exporter);

use File::ShareDir qw();

my ($exporter) = build_exporter(
  {
    exports => [ dist_dir => \&build_dist_dir, dist_file => \&build_dist_file ],
    groups  => {
      all       => [qw( dist_dir dist_file )],
      'default' => [qw( dist_dir dist_file )]
    },
    collectors => ['defaults'],
  }
);

## no critic (RequireArgUnpacking)
sub import {
  my ( $class, @args ) = @_;
  my $has_defaults = undef;

  my ( $xclass, $xfilename, $xline ) = caller;

  if ( not @args ) {
    @_ = ( $class, ':all', defaults => { filename => $xfilename } );
    goto $exporter;
  }

  for ( 0 .. $#args - 1 ) {
    if ( $args[$_] and $args[ $_ + 1 ] and $args[$_] eq 'defaults' and ref $args[ $_ + 1 ] ) {
      if ( not exists $args[ $_ + 1 ]->{filename} ) {
        $args[ $_ + 1 ]->{filename} = $xfilename;
      }
      $has_defaults = 1;
      last;
    }
  }
  if ( not $has_defaults ) {
    push @_, 'defaults' => { filename => $xfilename };
  }
  goto $exporter;
}

sub _devel_sharedir {
  my ($filename) = @_;
  my $file       = Path::Class::File->new($filename);
  my $dir        = $file->dir->absolute;
  ## no critic ( ProhibitMagicNumbers )
  while ( $dir->dir_list() and $dir->dir_list(-1) ne 'lib' ) {
    $dir = $dir->parent;
  }
  if ( -d $dir->parent()->subdir('share') ) {
    return $dir->parent()->subdir('share');
  }

  #warn "Not a devel $dir";
  return;
}


sub build_dist_dir {
  my ( $class, $name, $arg, $col ) = @_;
  my $root = _devel_sharedir( $col->{defaults}->{filename} );
  if ( not $root ) {
    return \&File::ShareDir::dist_dir;
  }
  return sub {

    # if the caller is devel, then we return the project root,
    # regardless of what package you asked for.
    # Might be bad, but we haven't imagined the scenario where yet.
    return $root->absolute->stringify;
  };
}


sub build_dist_file {
  my ( $class, $name, $arg, $col ) = @_;
  my $root = _devel_sharedir( $col->{defaults}->{filename} );
  if ( not $root ) {
    return \&File::ShareDir::dist_file;
  }
  return sub {

    # if the caller is devel, then we return the project root,
    # regardless of what package you asked for.
    # Might be bad, but we haven't imagined the scenario where yet.
    my $path = $root->file( $_[1] )->absolute->stringify;
    ## no critic ( ProhibitExplicitReturnUndef )
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

__END__
=pod

=head1 NAME

File::ShareDir::ProjectDistDir - Simple set-and-forget using of a '/share' directory in your projects root

=head1 VERSION

version 0.1.0

=head1 SYNOPSIS

  package An::Example::Package;

  use File::ShareDir::ProjectDistDir;

  # during development, $dir will be $projectroot/share
  # but once installed, it will be wherever File::Sharedir thinks it is.
  my $dir = dist_dir('An-Example')

Project layout requirements:

  $project/
  $project/lib/An/Example/Package.pm
  $project/share/   # files for package 'An-Example' go here.

=head1 METHODS

=head2 build_dist_dir

Generates the exported 'dist_dir' method. In development environments, the generated method will return
a path to the development directories 'share' directory. In non-development environments, this simply returns
C<File::ShareDir::dist_dir>.

As a result of this, specifying the Distribution name is not required during development, however, it will
start to matter once it is installed. This is a potential avenues for bugs if you happen to name it wrong.

=head2 build_dist_file

Generates the 'dist_file' method.

In development environments, the generated method will return
a path to the development directories 'share' directory. In non-development environments, this simply returns
C<File::ShareDir::dist_file>.

Caveats as a result of package-name as stated in L</build_dist_dir> also apply to this method.

=head1 AUTHOR

Kent Fredric <kentnl@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2011 by Kent Fredric <kentnl@cpan.org>.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

