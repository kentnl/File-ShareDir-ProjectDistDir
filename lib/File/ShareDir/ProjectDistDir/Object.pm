
use strict;
use warnings;

package File::ShareDir::ProjectDistDir::Object;

# ABSTRACT: Object Oriented guts of C<F:SD:PDD>

our $ENV_KEY_DEBUG = 'FILE_SHAREDIR_PROJECTDISTDIR_DEBUG';
our $DEBUG = ( exists $ENV{$ENV_KEY_DEBUG} ? $ENV{$ENV_KEY_DEBUG} : undef );

use Moo;

has 'calling_file' => (
  is       => ro =>,
  required => 1,
  isa      => sub {
    if ( not $_[0]->isa('Path::Tiny') ) {
      require Carp;
      Carp::croak("Must be a Path::Tiny");
    }
  },
  coerce => sub {
    return $_[0] if ref $_[0];
    require Path::Tiny;
    return Path::Tiny::path( $_[0] );
  },
);

has 'share_root' => (
  is      => ro =>,
  lazy    => 1,
  builder => sub {
    'share';
  }
);

has 'finddev_set' => (
  is        => ro                =>,
  predicate => 'has_finddev_set' =>,
);

has 'finddev_uplevel_max' => (
  is        => ro =>,
  predicate => 'has_finddev_uplevel_max',
);

has 'finddev_nest_retry' => (
  is        => ro =>,
  predicate => 'has_finddev_nest_retry',
);

has 'fixed_distname' => (
  is        => ro                   =>,
  predicate => 'has_fixed_distname' =>,
);

has 'finddev' => (
  is      => ro =>,
  lazy    => 1,
  builder => sub {
    my ($self) = @_;
    require Path::FindDev::Object;
    my %args;
    for my $fn (qw( set uplevel_max nest_retry )) {
      my $predicate = 'has_finddev_' . $fn;
      my $method    = 'finddev_' . $fn;
      if ( $self->$predicate() ) {
        $args{$fn} = $self->method();
      }
    }
    return Path::FindDev::Object->new(%args);
  },
);

has 'devdir' => (
  is      => ro =>,
  lazy    => 1,
  builder => sub {
    my ( $self, ) = @_;
    return $self->finddev->find_dev( $self->calling_file->parent );
  },
);

has 'expected_share_dir' => (
    is => ro =>,
    lazy => 1 , 
    builder => sub {
        my ($self,) = @_;
        my $dev = $self->devdir;
        return undef unless defined $dev;
        return $dev->child($self->share_root);
    },
);

has 'share_dir' => (
    is => ro =>,
    lazy => 1, 
    builder => sub {
        my ($self, )=@_;
        my $es = $self->expected_share_dir;
        return unless defined $es;
        return unless -d $es;
        return $es;
    },
);


sub _debug_assoc {
    my ( $self, $name, $value ) = @_;
    $value = 'undef' if not defined $value;
    $self->_debug(sprintf q{ %-20s => %s}, $name, $value );
}

sub _debug_prop {
    my ($self, $name) = @_;
    my $has_form = "has_$name";
    if( $self->can($has_form) and not $self->$has_form ){
        return;
    }
    $self->_debug_assoc( $name, $self->$name );
}


sub BUILD {
    my ( $self ) = @_;
    return $self unless $DEBUG;
    $self->_debug('{');
    $self->_debug_prop('calling_file');
    $self->_debug_prop('share_root');
    $self->_debug_prop('finddev_set');
    $self->_debug_prop('finddev_uplevel_max');
    $self->_debug_prop('finddev_nest_retry');
    $self->_debug_prop('fixed_distname');
    $self->_debug_prop('finddev');
    $self->_debug_prop('devdir');
    $self->_debug_prop('expected_share_dir');
    $self->_debug_prop('share_dir');
    $self->_debug_assoc('', ( defined $self->share_dir ? 'DEV' : 'PROD' ));
    $self->_debug('}');
}

my $instances   = {};
my $instance_id = 0;
 
 
sub _instance_id {
  my ($self) = @_;
  require Scalar::Util;
  my $addr = Scalar::Util::refaddr($self);
  return $instances->{$addr} if exists $instances->{$addr};
  $instances->{$addr} = sprintf '%x', $instance_id++;
  return $instances->{$addr};
}

sub _debug {
  my ( $self, $message ) = @_;
  return unless $DEBUG;
  my $id = $self->_instance_id;
  return *STDERR->printf( qq{[ProjectDistDir=%s] %s\n}, $id, $message );
}
sub _error {
  my ( $self, $message ) = @_;
  my $id = $self->_instance_id;
  my $f_message = sprintf qq{[ProjectDistDir=%s] %s\n}, $id, $message;
  require Carp;
  Carp::croak($f_message);
}

my $aliases = {
    'share_root' => [qw( projectdir )],
    'calling_file' => [qw( filename for_file )],
};
my $props = [
    qw( calling_file share_root finddev_set ),
    qw( finddev_uplevel_max finddev_nest_retry ),
    qw( fixed_distname finddev devdir expected_share_dir ),
    qw( share_dir ),
];

sub new_from_builder {
    my ( $class, $name, $arg, $col ) = @_;
    my $properties = {};

    $properties->{calling_file} = $col->{caller}->{filename}
        if exists $col->{caller} and exists $col->{caller}->{filename};

    for my $param (@{$props}) {
        for my $alias ($param, @{ $aliases->{$param} || [] }){
            if ( exists $col->{defaults}->{$alias} ) {
                $properties->{$param}  = $col->{defaults}->{$alias};
            }
            if ( exists $arg->{$alias} ){
                $properties->{$param} = $arg->{$alias};
            }
        }
    }
    return $class->new(%{$properties});
}
sub share_dir_file {
    my ( $self, $file ) = @_;

    if ( not $self->share_dir ) {
        require Carp;
        Carp::croak('Can\'t find developer-time share dir so cannot resolve files within');

    }

    my $fo = $self->share_dir->child($file);
    return undef unless -e $fo;
    if ( not -f $fo ){ 
        require Carp;
        Carp::croak("Found path '$fo' but it is not a file");
    }
    if ( not -r $fo ){ 
        require Carp;
        Carp::croak("File '$fo' exists, but it is not readable");
    }
    return $fo;
}
1;
