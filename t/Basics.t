use Test::More tests => 5;
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
$tab  = PDF::Table->new();

@data = ( [ 'foo', 'bar', 'baz' ], );
$tab->table( $pdf, $page, \@data, %TestData::required, );

#Check default font size
ok( $pdf->match( [ [qw(font 1 12)], [qw(font 1 12)], [qw(font 1 12)] ] ),
    'default font_size' )
  || note explain $pdf;

#Check default text placement
ok(
    $pdf->match(
        [ [qw(translate 10 688)],  [qw(text foo)] ],
        [ [qw(translate 110 688)], [qw(text bar)] ],
        [ [qw(translate 210 688)], [qw(text baz)] ],
    ),
    'default text placement in one row'
) or note explain $pdf;

#Check default splitting of long words
@data = ( ['123456789012345678901234567890123456789012345678901234567890'], );
%opts = (
    %TestData::required,
    w => 400,    #override w so table() will not use text_block()
);
$tab->table( $pdf, $page, \@data, %opts );
ok(
    $pdf->match(
        [
            [
                'text',
                '12345678901234567890 12345678901234567890 12345678901234567890'
            ]
        ],
    ),
    'default break long words on every 20th character'
) or note explain $pdf;


