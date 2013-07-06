
use strict;
use warnings;

package File::ShareDir::ProjectDistDir::Core;

# ABSTRACT: Internal guts for C<PDD>
sub _croak { require Carp; goto &Carp::croak }
sub _path { require Path::Tiny;        goto &Path::Tiny::path }
sub _find_dev { require Path::FindDev; goto &Path::FindDev::find_dev }

sub new {
    my ($class, $args ) = @_;
    $args ||= {};
    return bless { args => $args }, $class;
}

our $ENV_DEBUG_KEY = 'FILE_SHAREDIR_PROJECTDISTDIR_CORE_DEBUG';

sub debug {
    my ($self, $message ) = @_;
    if ( not exists $self->{debug} ) {
        if ( exists $self->{args}->{debug} ) {
            $self->{debug} =  !!$self->{args}->{debug};
        }
        elsif ( exists $ENV{$ENV_DEBUG_KEY} ) {
            $self->{debug} =  !!$ENV{$ENV_DEBUG_KEY};
        } else {
            $self->{debug} = undef;
        }
    }
    return unless $self->{debug};
    *STDERR->printf(qq{[ProjectDistDir] %s\n}, $message );
}

sub error {
    my ( $self, $message ) = @_;
    return _croak(qq{[ProjectDistDir::Core] $message});
}

sub for_file {
    my ($self) = @_;
    if ( not exists $self->{for_file} ) {
        if ( not exists $self->{args}->{for_file} ){
            $self->error('for_file not specified');
        }
        $self->{for_file} = _path($self->{args}->{for_file} );
        $self->debug('for_file => ' . $self->{for_file});
    }
    return $self->{for_file};
}
sub share_root {
    my ($self) = @_;
    if ( not exists $self->{share_root} ) {
        if ( not exists $self->{args}->{share_root} ) {
            $self->{share_root} = 'share'
        } else {
            $self->{share_root} = $self->{args}->{share_root};
        }
        $self->debug('share_root => ' . ($self->{share_root} || 'undef' ));
    }
    return $self->{share_root};
}

sub dev_dir {
    my ($self) = @_;
    if ( not exists $self->{dev_dir} ) {
        $self->{dev_dir} = _find_dev( $self->for_file->parent );
        $self->debug('dev_dir => ' . ($self->{dev_dir} || 'undef'));
    }
    return $self->{dev_dir};
}

sub share_dir {
    my ($self) = @_;
    if ( not exists $self->{share_dir} ) {
        my $dev = $self->dev_dir;
        if ( not defined $dev ){
            $self->debug('ISPROD: No devroot');
            $self->{share_dir} = undef;
            return;
        }
        my $sharedir = $dev->child($self->share_root);
        if ( -d $sharedir ) {
            $self->debug('ISDEV : exists : <devroot>/' . $self->share_root . ' > ' . $sharedir );
            $self->{share_dir} = $sharedir;
            return $sharedir;
        }
        $self->debug('ISPROD : does not exist <devroot>/' . $self->share_root . ' > ' . $sharedir );
        $self->{share_dir} = undef;
    }
    return $self->{share_dir} if defined $self->{share_dir};
    return;
}

sub share_dir_file {
    my ($self, $file ) = @_;

    if (not $self->share_dir) {
        return _croak('Can\'t find developer-time share dir so cannot resolve files within');
    }
    my $fo = $self->share_dir->child($file);
    return undef unless -e $fo;
    if ( not -f $fo ) {
        return _croak("Found path '$fo' but it is not a file");
    }
    if ( not -r $fo ){
        return _croak("File '$fo' exists, but it is not readable");
    }
    return $fo;
}

sub installed_share_dir {
    my ( $self, $dist ) = @_ ;
    require File::ShareDir;
    return File::ShareDir::dist_dir( $dist );
}

sub installed_share_dir_file {
    my ( $self, $dist, $file ) = @_;
    require File::ShareDir;
    return File::ShareDir::dist_file($dist,$file);
}

1;
