use strict;
use warnings;

package File::ShareDir::ProjectDistDir;

# ABSTRACT: Simple set-and-forget using of a '/share' directory in your projects root

=begin MetaPOD::JSON v1.0.0

{
    "namespace":"File::ShareDir::ProjectDistDir"
}

=end MetaPOD::JSON

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
    collectors => [ 'defaults', ],
  }
);
my $env_key = 'FILE_SHAREDIR_PROJECTDISTDIR_DEBUG';
if ( $ENV{$env_key} ) {
  ## no critic (ProtectPrivateVars)
  *File::ShareDir::ProjectDistDir::_debug = sub ($) {
    *STDERR->printf( qq{[ProjectDistDir] %s\n}, $_[0] );
  };
}
else {
  ## no critic (ProtectPrivateVars)
  *File::ShareDir::ProjectDistDir::_debug = sub ($) { }
}

## no critic (RequireArgUnpacking)

=method import

    use File::ShareDir::ProjectDistDir (@args);

This uses L<< C<Sub::Exporter>|Sub::Exporter >> to do the heavy lifting, so most usage of this module can be maximised by understanding that first.

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

Specify what the project directory is as a path relative to the base of your distributions source,
and this directory will be used as a C<ShareDir> simulation path for the exported methods I<During development>.

If not specified, the default value 'share' is used.

=item * B<C<filename>>

    ->import( .... , filename => 'some/path/to/foo.pm' );

Generally you don't want to set this, as its worked out by caller() to work out the name of
the file its being called from. This file's path is walked up to find the 'lib' element with a sibling
of the name of your C<projectdir>.

=item * B<C<distname>>

    ->import( .... , distname => 'somedistname' );

Specifying this argument changes the way the functions are emitted at I<installed C<runtime>>, so that instead of
taking the standard arguments File::ShareDir does, the specification of the C<distname> in those functions is eliminated.

i.e:

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
    pathclass  => undef,
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
    for my $setting (qw( projectdir filename distname pathclass )) {
      if ( $key eq $setting and not ref $value ) {
        $defaults->{$setting} = $value;
        undef $args[$_];
        undef $args[ $_ + 1 ];
        last;
      }
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
  my $root = File::Spec->rootdir();

  _debug( 'Working on: ' . $filename );
  _debug('Trying to find parent \'lib\'');
  ## no critic ( ProhibitMagicNumbers )
  while (1) {
    if ( $dir->dir_list(-1) eq 'lib' ) {
      _debug( 'Found lib : ' . $dir );
      last;
    }
    if ( File::Spec->catdir( $dir->absolute->dir_list ) eq $root ) {

      #warn "Not a devel $dir, / hit";
      _debug('ISPROD: Hit OS Root');
      return;
    }
    if ( $dir->dir_list(-1) ne 'lib' ) {
      $dir = $dir->parent;
    }
  }
  my $devel_share_dir = $dir->parent()->subdir($subdir);
  if ( -d $devel_share_dir ) {
    if ( -d $devel_share_dir->subdir('ImageMagic-6') ) {

      # There's a quirk where a DuckDuckGo installed
      # ImageMagic in such a way that it created the
      # lib/../share
      # structure that we use as a marker of a "devel" dir,
      # which results in File::ShareDir::ProjectDistDir
      # completely failing for *all* modules installed in the lib/ path.
      _debug( 'ISPROD: exists : lib/../' . $subdir . '/ImageMagic-6' );
      return;
    }
    _debug( 'ISDEV : exists : lib/../' . $subdir . ' > ' . $devel_share_dir );
    return $dir->parent()->subdir($subdir);
  }
  _debug( 'ISPROD: does not exist : lib/../' . $subdir . ' > ' . $devel_share_dir );

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
      dist_dir => { distname => 'example-dist', -as => 'mydistdir' },
      dist_dir => { distname => 'other-dist',   -as => 'otherdistdir' };

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
  $projectdir = $arg->{projectdir}             if $arg->{projectdir};

  my $pathclass;
  $pathclass = $col->{defaults}->{pathclass} if exists $col->{defaults}->{pathclass};
  $pathclass = $arg->{pathclass}             if exists $arg->{pathclass};

  my $root = _devel_sharedir( $col->{defaults}->{filename}, $projectdir );

  my $distname;
  $distname = $col->{defaults}->{distname} if $col->{defaults}->{distname};
  $distname = $arg->{distname}             if $arg->{distname};

  # In dev
  if ($root) {
    my $pathclass_method = sub { return $root->absolute };
    return $pathclass_method if $pathclass;
    return sub { return $pathclass_method->(@_)->stringify };
  }

  # Non-Dev, no hardcoded distname
  if ( not $distname ) {
    my $string_method = \&File::ShareDir::dist_dir;
    return $string_method if not $pathclass;
    return sub { return Path::Class::Dir->new( $string_method->(@_) ); }
  }

  # Non-Dev, hardcoded distname
  my $string_method = sub() {
    @_ = ($distname);
    goto &File::ShareDir::dist_dir;
  };
  return $string_method if not $pathclass;
  return sub { return { Path::Class::Dir->new($string_method) } }

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
      dist_file => { distname => 'example-dist', -as => 'mydistfile' },
      dist_file => { distname => 'other-dist',   -as => 'otherdistfile' };

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
  $projectdir = $arg->{projectdir}             if $arg->{projectdir};

  my $root = _devel_sharedir( $col->{defaults}->{filename}, $projectdir );
  my $distname;
  $distname = $col->{defaults}->{distname} if $col->{defaults}->{distname};
  $distname = $arg->{distname}             if $arg->{distname};

  my $pathclass;
  $pathclass = $col->{defaults}->{pathclass} if exists $col->{defaults}->{pathclass};
  $pathclass = $arg->{pathclass}             if exists $arg->{pathclass};

  if ($root) {
    my $pathclass_method = sub {
      my $file = ( $distname ? $_[0] : $_[1] );

      # if the caller is devel, then we return the project root,
      # regardless of what package you asked for.
      # Might be bad, but we haven't imagined the scenario where yet.
      my $path_o = $root->file($file)->absolute;
      my $path_s = $path_o->stringify;
      ## no critic ( ProhibitExplicitReturnUndef )
      return undef unless -e $path_s;
      if ( not -f $path_s ) {
        require Carp;
        Carp::croak("Found dist_file '$path_s', but not a file");
      }
      if ( not -r $path_s ) {
        require Carp;
        Carp::croak("File '$path_s', no read permissions");
      }
      return $path_o;
    };
    return $pathclass_method if $pathclass;
    return sub { return $pathclass_method->(@_)->stringify };
  }
  if ( not $distname ) {
    my $string_method = \&File::ShareDir::dist_file;
    return $string_method if not $pathclass;
    return sub { Path::Class::File->new( $string_method->(@_) ) };
  }
  my $string_method = sub($) {
    if ( @_ != 1 or not defined $_[0] ) {
      require Carp;
      Carp::croak('dist_file takes only one argument,a filename, due to distname being specified during import');
    }
    unshift @_, $distname;
    goto &File::ShareDir::dist_file;
  };
  return $string_method if not $pathclass;
  return sub { Path::Class::File->new( $string_method->(@_) ) }
}

1;
