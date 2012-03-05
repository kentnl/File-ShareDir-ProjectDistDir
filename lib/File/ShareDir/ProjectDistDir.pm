use strict;
use warnings;

package File::ShareDir::ProjectDistDir;

# ABSTRACT: Simple set-and-forget using of a '/share' directory in your projects root

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

You can use a directory name other than 'share' ( Assuming you make sure when
you install that, you specify the different directory there also ) as follows:

  use File::ShareDir::ProjectDistDir ':all', defaults => {
    projectdir => 'templates',
  };

=cut

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
    collectors => ['defaults','dist_name'],
  }
);

## no critic (RequireArgUnpacking)

=method import

    use File::ShareDir::ProjectDistDir (@args);

This uses L<Sub::Exporter> to do the heavy lifting, so most usage of this module can be maximised by understanding that first.

=over 4

=item * B<C<:all>>

    ->import( ':all' , .... )

Import both C<dist_dir> and C<dist_file>

=item * B<C<dist_dir>>

    ->import('dist_dir' , .... )

Import the dist_dir method

=item * B<C<dist_dir>>

    ->import('dist_file' , .... )

Import the dist_file method

=item * B<C<projectdir>>

    ->import( .... , projectdir => 'share' )

Specify what the "project dir" is as a path relative to the base of your distributions source, 
and this directory will be used as a ShareDir simulation path for the exported methods I<During development>.

If not specified, the default value 'share' is used.

=item * B<C<filename>>

    ->import( .... , filename => 'some/path/to/foo.pm' );

Generally you don't want to set this, as its worked out by caller() to work out the name of 
the file its being called from. This file's path is walked up to find the 'lib' element with a sibling
of the name of your 'projectdir'.

=item * B<C<distname>>

    ->import( .... , distname => 'somedistname' );

Specifying this argument changes the way the functions are emitted at I<installed runtime>, so that instead of
taking the standard arguments File::ShareDir does, the specification of the distname in those functions is eliminated. 

ie:

    # without this flag
    use File::ShareDir::ProjectDistDir qw( :all );

    my $dir = dist_dir('example');
    my $file = dist_file('example', 'path/to/file.pm' );

    # with this flag
    use File::ShareDir::ProjectDistDir ( qw( :all ), distname => 'example' );

    my $dir = dist_dir();
    my $file = dist_file('path/to/file.pm' );

=item * B<C<defaults>>

    ->import( ... , defaults => {
        filename => ....,
        projectdir => ....,
    });

This is mostly an alternative syntax for specifying C<filename> and C<projectdir>, 
which is mostly used internally, and their corresponding other values are packed into this one.

=back

=head3 Sub::Exporter tricks of note.

=head4 Make your own sharedir util

    package Foo::Util;

    sub import {
        my ($caller_class, $caller_file, $caller_line )  = caller();
        if ( grep { /share/ } @_ ) { 
            require File::ShareDir::ProjectDistDir;
            File::ShareDir::ProjectDistDir->import(
                filename => $caller_file,
                dist_dir => { distname => 'myproject' , -as => 'share' },
                dist_dir => { distname => 'otherproject' , -as => 'other_share' , projectdir => 'share2' },
                -into => $caller_class,
            );
        }
    }

    ....

    package Foo;
    use Foo::Util qw( share );

    my $dir = share();
    my $other_dir => other_share();


=cut


sub import {
  my ( $class, @args ) = @_;
  my $has_defaults = undef;

  my ( $xclass, $xfilename, $xline ) = caller;

  my $defaults = {
    filename   => $xfilename,
    projectdir => 'share',
  };

  if ( not @args ) {
    @_ = ( $class, ':all', defaults => $defaults );
    goto $exporter;
  }

  for ( 0 .. $#args - 1 ) {
    my ( $key, $value );
    next unless $key = $args[$_] and $value = $args[ $_ + 1 ];

    if ( $key eq 'defaults' ) {
      $defaults = $value;
      undef $args[$_];
      undef $args[ $_ + 1 ];
      next;
    }
    if ( $key eq 'projectdir' ) {
      $defaults->{projectdir} = $value;
      undef $args[$_];
      undef $args[ $_ + 1 ];
    }
    if ( $key eq 'filename' and not ref $value ) {
      $defaults->{filename} = $value;
      undef $args[$_];
      undef $args[ $_ + 1 ];
    }
  }

  $defaults->{filename}   = $xfilename if not defined $defaults->{filename};
  $defaults->{projectdir} = 'share'    if not defined $defaults->{projectdir};

  @_ = ( $class, ( grep { defined } @args ), 'defaults' => $defaults );

  goto $exporter;
}

sub _devel_sharedir {
  my ( $filename, $subdir ) = @_;
  my $file = Path::Class::File->new($filename);
  my $dir  = $file->dir->absolute;
  ## no critic ( ProhibitMagicNumbers )
  while ( $dir->dir_list() and $dir->dir_list(-1) ne 'lib' ) {
    $dir = $dir->parent;
  }
  if ( -d $dir->parent()->subdir($subdir) ) {
    return $dir->parent()->subdir($subdir);
  }

  #warn "Not a devel $dir";
  return;
}

=method build_dist_dir

    use File::ShareDir::ProjectDirDir ( : all );

    #  this calls
    my $coderef = File::ShareDir::ProjectDistDir->build_dist_dir(
      'dist_dir' => {},
      { defaults => { filename => 'path/to/yourcallingfile.pm', projectdir => 'share' } }
    );

    use File::ShareDir::ProjectDirDir ( qw( :all ), distname => 'example-dist' );

    #  this calls
    my $coderef = File::ShareDir::ProjectDistDir->build_dist_dir(
      'dist_dir' => {},
      { distname => 'example-dist', defaults => { filename => 'path/to/yourcallingfile.pm', projectdir => 'share' } }
    );

    use File::ShareDir::ProjectDirDir
      dist_dir => { dist_name => 'example-dist', -as => 'mydistdir' },
      dist_dir => { dist_name => 'other-dist',   -as => 'otherdistdir' };

    # This calls
    my $coderef = File::ShareDir::ProjectDistDir->build_dist_dir(
      'dist_dir',
      { distname => 'example-dist' },
      { defaults => { filename => 'path/to/yourcallingfile.pm', projectdir => 'share' } },
    );
    my $othercoderef = File::ShareDir::ProjectDistDir->build_dist_dir(
      'dist_dir',
      { distname => 'other-dist' },
      { defaults => { filename => 'path/to/yourcallingfile.pm', projectdir => 'share' } },
    );

    # And leverages Sub::Exporter to create 2 subs in your package.


Generates the exported 'dist_dir' method. In development environments, the generated method will return
a path to the development directories 'share' directory. In non-development environments, this simply returns
C<File::ShareDir::dist_dir>.

As a result of this, specifying the Distribution name is not required during development, however, it will
start to matter once it is installed. This is a potential avenues for bugs if you happen to name it wrong.

=cut

sub build_dist_dir {
  my ( $class, $name, $arg, $col ) = @_;

  my $projectdir;
  $projectdir = $col->{defaults}->{projectdir} if $col->{defaults}->{projectdir};
  $projectdir = $arg->{projectdir} if $arg->{projectdir};

  my $root = _devel_sharedir( $col->{defaults}->{filename}, $projectdir );
  if ( not $root ) {
      my $distname;
      $distname = $col->{distname} if $col->{distname};
      $distname = $arg->{distname} if $arg->{distname};
      if ( not $distname ){
        return \&File::ShareDir::dist_dir;
      }
      return sub (){
          @_ = ( $distname );
          goto \&File::ShareDir::dist_dir;
      };
  }
  return sub {

    # if the caller is devel, then we return the project root,
    # regardless of what package you asked for.
    # Might be bad, but we haven't imagined the scenario where yet.
    return $root->absolute->stringify;
  };
}

=method build_dist_file

    use File::ShareDir::ProjectDirDir ( : all );

    #  this calls
    my $coderef = File::ShareDir::ProjectDistDir->build_dist_file(
      'dist_file' => {},
      { defaults => { filename => 'path/to/yourcallingfile.pm', projectdir => 'share' } }
    );

    use File::ShareDir::ProjectDirDir ( qw( :all ), distname => 'example-dist' );

    #  this calls
    my $coderef = File::ShareDir::ProjectDistDir->build_dist_file(
      'dist_file' => {},
      { distname => 'example-dist', defaults => { filename => 'path/to/yourcallingfile.pm', projectdir => 'share' } }
    );

    use File::ShareDir::ProjectDirDir
      dist_file => { dist_name => 'example-dist', -as => 'mydistfile' },
      dist_file => { dist_name => 'other-dist',   -as => 'otherdistfile' };

    # This calls
    my $coderef = File::ShareDir::ProjectDistDir->build_dist_file(
      'dist_file',
      { distname => 'example-dist' },
      { defaults => { filename => 'path/to/yourcallingfile.pm', projectdir => 'share' } },
    );
    my $othercoderef = File::ShareDir::ProjectDistDir->build_dist_file(
      'dist_file',
      { distname => 'other-dist' },
      { defaults => { filename => 'path/to/yourcallingfile.pm', projectdir => 'share' } },
    );

    # And leverages Sub::Exporter to create 2 subs in your package.


Generates the 'dist_file' method.

In development environments, the generated method will return
a path to the development directories 'share' directory. In non-development environments, this simply returns
C<File::ShareDir::dist_file>.

Caveats as a result of package-name as stated in L</build_dist_dir> also apply to this method.

=cut

sub build_dist_file {
  my ( $class, $name, $arg, $col ) = @_;

  my $projectdir;
  $projectdir = $col->{defaults}->{projectdir} if $col->{defaults}->{projectdir};
  $projectdir = $arg->{projectdir} if $arg->{projectdir};

  my $root = _devel_sharedir( $col->{defaults}->{filename}, $projectdir );

  if ( not $root ) {
      my $distname;
      $distname = $col->{distname} if $col->{distname};
      $distname = $arg->{distname} if $arg->{distname};
      if ( not $distname ){
        return \&File::ShareDir::dist_file;
      }
      return sub ($){
          unshift @_, $distname;
          goto \%File::ShareDir::dist_file;
      };
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
