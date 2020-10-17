#!/usr/bin/env perl
use warnings;
use strict;
use diagnostics;
use PDF::Table;

=pod 

This example file gives an overview of the functionalities provided by 
PDF::Table. Also it can be used to bootstrap your code.

=cut

# Please use TABSTOP=4 for best view
# -------------
my ($PDFpref, $rcA, $rcB); # which is available?
my $prefFile = "./PDFpref";
my $prefDefault = "B"; # PDF::Builder default if no prefFile, or both installed
if (-f $prefFile && -r $prefFile) {
    open my $FH, '<', $prefFile or die "error opening $prefFile: $!\n";
    $PDFpref = <$FH>;
    if      ($PDFpref =~ m/^A/i) {
	# something starting with A, assume want PDF::API2
	$PDFpref = 'A';
    } elsif ($PDFpref =~ m/^B/i) {
	# something starting with B, assume want PDF::Builder
	$PDFpref = 'B';
    } elsif ($PDFpref =~ m/^PDF:{1,2}A/i) {
	# something starting with PDF:A or PDF::A, assume want PDF::API2
	$PDFpref = 'A';
    } elsif ($PDFpref =~ m/^PDF:{1,2}B/i) {
	# something starting with PDF:B or PDF::B, assume want PDF::Builder
	$PDFpref = 'B';
    } else {
	print STDERR "Don't see A... or B..., default to $prefDefault\n";
	$PDFpref = $prefDefault;
    }
    close $FH;
} else {
    # no preference expressed, default to PDF::Builder
    print STDERR "No preference file found, so default to $prefDefault\n";
    $PDFpref = $prefDefault;
}
foreach (1 .. 2) {
    if ($PDFpref eq 'A') { # A(PI2) preferred
        $rcA = eval {
            require PDF::API2;
            1;
        };
        if (!defined $rcA) { $rcA = 0; } # else is 1;
        if ($rcA) { $rcB = 0; last; }
	$PDFpref = 'B';
    } 
    if ($PDFpref eq 'B') { # B(uilder) preferred
        $rcB = eval {
            require PDF::Builder;
            1;
        };
        if (!defined $rcB) { $rcB = 0; } # else is 1;
	if ($rcB) { $rcA = 0; last; }
	$PDFpref = 'A';
    }
}
if (!$rcA && !$rcB) {
    die "Neither PDF::API2 nor PDF::Builder is installed!\n";
}
# -------------

# VERSION
my $LAST_UPDATE = '1.000'; # manually update whenever code is changed

my $outfile = $0;
if ($outfile =~ m#[\\/]([^\\/]+)$#) { $outfile = $1; }
$outfile =~ s/\.pl$/.pdf/;

my $pdftable = PDF::Table->new();
# -------------
my $pdf;
if ($rcA) {
    print STDERR "Using PDF::API2 library\n";
    $pdf      = PDF::API2->new( -file => $outfile );
} else {
    print STDERR "Using PDF::Builder library\n";
    $pdf      = PDF::Builder->new( -file => $outfile, -compress => 'none' );
}
# -------------
my $page     = $pdf->page();
$pdf->mediabox('A4');

# A4 as defined by PDF::API2 is h=842 w=545 for portrait

# some data to lay out
my $some_data = [
	[ 'Header', 'Row', 'Test' ],
	[
		'1 Lorem ipsum dolor',
		'Donec odio neque, faucibus vel',
		'1 consequat quis, tincidunt vel, felis.'
	],
	[ 'Nulla euismod sem eget neque.', 'Donec odio neque', 'Sed eu velit.' ],
	[
		'Az sym bulgarin',
		# column 2 has explicit \n's for 3 physical lines
		"i ne razbiram DESI\ngorniq \nezik",
		# column 3 has implied \n's for 4 physical lines
		"zatova reshih
		da dobavq
		edin ili dva
		novi reda"
	],
	[
		'da dobavq edin dva reda',
		'v tozi primer',
		'na bulgarski ezik s latinica'
	],
	[
		'5 Lorem ipsum dolor',
		'Donec odio neque, faucibus vel',
		'5 consequat quis, tincidunt vel, felis.'
	],
	[ 'Nulla euismod sem eget neque.', 'Donec odio neque', 'Sed eu velit.' ],
	[ 'Az sym bulgarin', 'i ne razbiram gorniq ezik', 'zatova reshih' ],
	[
		'da dobavq edin dva reda',
		'v tozi primer',
		'na bulgarski ezik s latinica'
	],
];

# build the table layout. like the data (text), the various properties and
# settings could be pulled out of line.
$pdftable->table(

	# required params
	$pdf,
	$page,
	$some_data,

	# Geometry of the document
	x  => 50,
	-w => 495,  # width: most of an A4 page
       	# dashed params supported for backward compatibility. 
	# dash/non-dash params can be mixed
	start_y  => 792, # or y
	next_y   => 700,
	-start_h => 400, # or h. reduce to force overflow to new page
	next_h   => 500,

	# some optional params for fancy results
	-padding              => 3,
	padding_right         => 10,
	background_color_odd  => 'lightblue', # bg_color_odd
	background_color_even => "#EEEEAA",   # bg_color_even
	# using default font (Times-Roman 12pt)
	
	header_props          => {
		bg_color   => "#F0AAAA",
		font       => $pdf->corefont( "Helvetica", -encoding => "latin1" ),
		font_size  => 14,
		font_color => "#006600",  # fg_color
		repeat     => 1  # default
		# note that col 2 inherits RJ from column_props setting
	},
	column_props => [
		{},                    # no properties for the first column
		{                      # column 2 overrides: force wider,
			               # larger font, right-justified, own bg.
			min_w      => 250,
			justify    => "right",
			font       => $pdf->corefont( "Times", -encoding => "latin1" ),
			font_size  => 14, 
			font_color => 'white',  # fg_color
			background_color => '#8CA6C5',  # bg_color
		},
		                       # column 3 no overrides
	],
	cell_props => [
		[ # This is the first(header) row of the table and here 
		  # %header_prop has priority, so no effect with these settings
			{
				background_color => '#000000', # bg_color
				font_color       => 'blue',    # fg_color
			},

			# etc.
		],
		[ # Row 2 (first data row)
			{ # Row 2 col 1
				background_color => '#000000',
				font_color       => 'white',
			},
			{ # Row 2 col 2
				background_color => '#AAAA00',
				font_color       => 'red',
			},
			{ # Row 2 col 3
				background_color => '#FFFFFF',
				font_color       => 'green',
			},

			# etc.
		],
		[ # Row 3 (second data row)
			{ # Row 3 cell 1
				background_color => '#AAAAAA',
				font_color       => 'blue',
			},

			# etc. rest of columns are normal
		],

		# etc. rest of rows are normal
	],
	row_props => [
		{}, {}, {}, {},
		{ # Row 5 (4th data row)
			'row_height' => 50, # extra height on this row
		},
	],
);  # end of table() call

$pdf->save();
