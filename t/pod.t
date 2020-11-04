#!/usr/bin/perl
use strict;
use warnings;
use Test::More;

my $min_ver = 1.52; # was 1.00
eval "use Test::Pod $min_ver";
plan skip_all => "Test::Pod $min_ver required for testing POD" if $@;
all_pod_files_ok();

1;
