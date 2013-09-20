#!/usr/bin/env perl
use strict;
use warnings;
use utf8;

if ( not exists $ENV{TRAVIS} ) {
    die "Is not travis!";
}
for my $i (@INC) {
    next if $i !~ /site/;
    next if $i eq '.';

    #    printf "%s\n", $i;
    system( 'find', $i, '-type', 'f', '-delete' );
    system( 'find', $i, '-depth', '-type', 'd', '-delete' );
}

