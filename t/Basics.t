use Test::More tests => 3;
use strict;
use warnings;

use lib 't/lib'; # Needed for 'make test' from project dirs
use TestData qw(:BASICS);
use PDFAPI2Mock;

BEGIN {
    use_ok('PDF::Table');
}
require_ok('PDF::Table');

my ( $pdf, $page, $tab, @data );

$pdf  = PDF::API2->new();
$page = $pdf->page();
$tab  = PDF::Table->new();

@data = ( [ 'foo', 'bar', 'baz' ], );

$tab->table($pdf, $page, \@data, @TestData::required,);
#Just a simple check for beginning (duplicate)
ok($pdf->match(
      [[qw(translate 10 738)],[qw(text foo)]],
      [[qw(translate 110 738)],[qw(text bar)]],
      [[qw(translate 210 738)],[qw(text baz)]],
), 'default text position in first row');
