use Test::More tests => 6;
use strict;
use warnings;

use lib 't/lib';    # Needed for 'make test' from project dir
use TestData;
use PDFAPI2Mock;

BEGIN {
    use_ok('PDF::Table');
}
require_ok('PDF::Table');

my ( $pdf, $page, $tab, @data, %opts );

$pdf  = PDF::API2->new();
$page = $pdf->page();
$tab  = PDF::Table->new($pdf,$page);

@data = ( [ 'c1r1', 'c1r2', 'c1r3' ], ['c2r1','c2r2'] );
$tab->table( $pdf, $page, \@data, %TestData::required,
    column_props => [
            { background_color => 'red' },
      ],
    cell_props => [
        [],
        [{colspan=>2}]
    ]
 );

#Check default font size
ok( $pdf->match( [ [qw(font 1 12)], [qw(font 1 12)], [qw(font 1 12)] ] ),
    'default font_size' )
  || note explain $pdf;

#Check default text placement
ok(
    $pdf->match(
        [ [qw(translate 10 688)],  [qw(text c1r1)] ],
        [ [qw(translate 110 688)], [qw(text c1r2)] ],
        [ [qw(translate 210 688)], [qw(text c1r3)] ],
    ),
    'default text placement in first row'
) or note explain $pdf;

ok(
    $pdf->match(
        [ [qw(translate 10 676)],  [qw(text c2r1)] ],
    ),
    'r2c1'
) or note explain $pdf;

ok( # a bug!
    $pdf->match(
        [ [qw(translate 210 676)],  [qw(text c2r2)] ],
    ),
    'r2c2'
) or note explain $pdf;



