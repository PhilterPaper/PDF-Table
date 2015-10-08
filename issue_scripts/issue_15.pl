#!/usr/bin/env perl
use warnings;
use strict;
use diagnostics;

use lib('../lib/');
use PDF::API2;
use PDF::Table;

#Please use TABSTOP=4 for best view
my $pdftable = new PDF::Table;
my $pdf      = new PDF::API2( -file => "issue_15.pdf" );
my $page     = $pdf->page();
$pdf->mediabox('A4');

# A4 as defined by PDF::API2 is h=842 w=545 for portrait

# some data to layout
my $some_data = [
    [ 'Header',              'Row',   'Test' ],
    [ '1 Lorem ipsum dolor', 'Donec', 'German umlaut like this: äöüßÖÄÜ. quis, tincidunt vel, felis.' ],
    [ '2 Lorem ipsum dolor', 'Donec super long text goes here to provoke a text block', 'consequat quis, tincidunt vel, felis.' ],
    [ '3 Lorem ipsum dolor', 'Donec', 'consequat quis, tincidunt vel, felis.' ],

];

# build the table layout
$pdftable->table(

    # required params
    $pdf,
    $page,
    $some_data,
    x       => 10,
    w       => 400,
    start_y => 780,
    next_y  => 780,
    start_h => 500,
    next_h  => 500,
    padding => 10,

    # some optional params
    font_size          => 10,
    padding_right      => 10,
    horizontal_borders => 1,
    font               => $pdf->corefont( "Helvetica", -encoding => "utf8" ),
    header_props       => {
        font       => $pdf->corefont( "Helvetica", -encoding => "utf8" ),
    },
);

$pdf->saveas();

