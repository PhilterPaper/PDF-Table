use Test::More tests => 2;
use strict;
use warnings;

use lib 't/lib'; # Needed for 'make test' from project dirs
use TestData qw(:BASICS);
use PDFAPI2Mock;

BEGIN {
    use_ok('PDF::Table');
}
require_ok('PDF::Table');

my ( $pdf, $page, $tab, @data, @required );

$tab  = PDF::Table->new();
$pdf  = PDF::API2->new();
@data = ( [ 'foo', 'bar', 'baz' ], );

#note explain $pdf;
