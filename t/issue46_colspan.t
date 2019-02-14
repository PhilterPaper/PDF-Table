use Test::More tests => 11;
use strict;
use warnings;

use lib 't/lib'; # Needed for 'make test' from project dirs
#use PDFAPI2Mock;

BEGIN {
   use_ok('PDF::Table')
}

my $data =[
    ["1 Lorem ipsum dolor1 Lorem ipsum dolor1 Lorem ipsum dolor 1 Lorem ipsum dolor1 Lorem ipsum dolor","a","bbbbbbb dfgdfg dfgdfgdfg dfgdfg"],
    ["1 Lorem ipsum dolor Donec odio neque, faucibus vel consequat quis, tincidunt vel, felis."],
    ["Nulla euismod sem eget neque.",
    "Donec odio neque sed eu velit."],
];

my @required = (
      x => 10,
      w => 260,
      start_y => 750,
      start_h => 400,
      padding => 5,

      #next_h => 500,
);

{
    use PDF::API2;
    my $pdftable = new PDF::Table;
    my $pdf      = new PDF::API2( -file => "colspan.pdf" );
    my $page     = $pdf->page();
    $pdf->mediabox('A4');

    $pdftable->table($pdf, $page, $data, @required,
        column_props=>[{min_w=>150, background_color => 'grey'}, { background_color => 'red',}],
        cell_props => [
                [ {}, {background_color => 'pink'}, { background_color => 'blue', colspan=>1 } ],
                [ { colspan=>3 }],
                [ {}, { colspan=>2 }],
        ],
    );
    $pdf->saveas();
}

__END__

my $pdf = PDF::API2->new;
my $page = $pdf->page;
my $tab = PDF::Table->new($pdf, $page);

$tab->table($pdf, $page, $data, @required,
      cell_props => [
            [ {}, {}, { background_color => 'blue' } ],
      ],
);

ok($pdf->match(
      [[qw(translate 10 738)],[qw(text foo)]],
      [[qw(translate 110 738)],[qw(text bar)]],
      [[qw(translate 210 738)],[qw(text baz)]],
), 'text position');

ok($pdf->match(
      [[qw(rect 10 738 100 12)],[qw(fillcolor gray)]],
      [[qw(rect 110 738 100 12)],[qw(fillcolor red)]],
      [[qw(rect 210 738 100 12)],[qw(fillcolor blue)]],
), 'default header fillcolor');

ok($pdf->match(
      [[qw(gfx)],[qw(strokecolor black)],[qw(linewidth 1)]],
      [[qw(stroke)]],
), "draw borders");



