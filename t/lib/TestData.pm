package TestData;
use strict;
use warnings;

our @ISA = qw(Exporter);
our @EXPORT_OK = qw(%test @required);
our %EXPORT_TAGS = (
    TEST => [qw(%test)],
    BASICS => [qw(@required)],
);

our %test = ( a => 1);
our @required = (
      x => 10,
      w => 300,
      start_y => 750,
      next_y => 700,
      start_h => 40,
      next_h => 500,
); 

return 1;
