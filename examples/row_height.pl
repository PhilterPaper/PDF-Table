#!/usr/bin/env perl
use warnings;
use strict;
use diagnostics;

use PDF::API2; # two places change API2 to Builder to use PDF::Builder
use PDF::Table;

# VERSION
my $LAST_UPDATE = '0.12'; # manually update whenever code is changed

my $pdftable = PDF::Table->new();
my $pdf      = PDF::API2->new( -file => "row_height.pdf" );
my $page     = $pdf->page();
$pdf->mediabox('A4');

# A4 as defined by PDF::API2 is h=842 w=545 for portrait

my $data = [];

# some data to layout

foreach my $num ( 1 .. 25 ) {
	push( @$data, [ 'foo' . $num, 'bar' . $num ] );
}

# build the table layout
$pdftable->table(

	# required params
	$pdf,
	$page,
	$data,
	x       => 10,
	w       => 150,
	start_y => 750,
	next_y  => 700,
	start_h => 200,
	next_h  => 500,

	# some optional params
	border          => 1,
	font_size       => 10,
	max_word_length => 15,
	padding         => 5,
	row_height      => 30,
);
$pdf->saveas();
