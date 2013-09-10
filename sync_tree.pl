#!/usr/bin/env perl 
use strict;
use warnings;
use utf8;

use Path::FindDev qw( find_dev );
my $root = find_dev('./');

chdir "$root";

if ( not -d -e $root->child("maint") ) {
    system(
        'git', 'subtree', 'add', 
            '--prefix=maint', 
            'https://github.com/kentfredric/travis-scripts.git', 'master'
    );
} else {
    system(
        'git', 'subtree', 'pull', 
            '--prefix=maint', 
            'https://github.com/kentfredric/travis-scripts.git', 'master'
    );
}

