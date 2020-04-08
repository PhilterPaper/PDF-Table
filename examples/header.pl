#!/usr/bin/env perl
use warnings;
use strict;
use diagnostics;

#Please use TABSTOP=4 for best view
use PDF::API2;  # two places change API2 to Builder to use PDF::Builder
use PDF::Table;

# VERSION
my $LAST_UPDATE = '0.12'; # manually update whenever code is changed

my $pdftable = PDF::Table->new();
my $pdf      = PDF::API2->new( -file => "headers.pdf" );
my $page     = $pdf->page();
$pdf->mediabox('A4');

# A4 as defined by PDF::API2 is h=842 w=545 for portrait

# some data to layout
my $some_data = [
	[ 'HeaderA', 'HeaderB' ],
	[ 'foo',     'bar' ],
	[ 'one',     'two' ],
	[ 'thr',     'four score and seven years ago our fathers brought forth' ],
	[ 'fiv',     'six' ],
	[ 'sev',     'abcdefghijklmnopqrstuvwxyz' ],
];

# build the table layout
$pdftable->table(

	# required params
	$pdf,
	$page,
	$some_data,
	x       => 10,
	w       => 220,
	start_y => 700,
	next_y  => 700,
	start_h => 62,
	next_h  => 62,

	# some optional params
	border          => 0,
	font_size       => 20,
	font_underline  => [3 ,2],
	max_word_length => 13,
	header_props    => {
		background_color => 'yellow',
		repeat           => 1
	},
	cell_props => [
		[], [ { background_color => 'red' }, { background_color => 'blue' } ],
	],
);

$pdf->saveas();
