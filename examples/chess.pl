#!/usr/bin/env perl
use warnings;
use strict;
use diagnostics;
use PDF::Table;

# Demonstrate a chessboard using even and odd row bg and fg color definitions
#  on a per-column ($column_props) basis.
# Gray bg shows move of White Knight to catpure Black King's Bishop (both red),
#  with $cell_props.
# Once images are supported, will change to pictures of pieces (or maybe both).

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
    $pdf      = PDF::Builder->new( -file => $outfile );
}
# -------------
my $page     = $pdf->page();
$pdf->mediabox('A4');

# A4 as defined by PDF::API2 is h=842 w=545 for portrait

# some data to lay out. notice that there are 8 rows of 8 columns
my $chessboard = [
	# rows TTB, LTR value=piece name, or blank for empty
	# unfortunately, none of the corefonts include chess pieces
	[ 'WKB', ' ',  ' ',   ' ', ' ',  ' ',  'WK', 'WKR' ],
	[ ' ',   ' ',  ' ',   ' ', ' ',  ' ',  ' ',  'BR'  ],
	[ ' ',   ' ',  'WR',  ' ', ' ',  ' ',  ' ',  ' '   ],
	[ ' ',   ' ',  'BKB', ' ', 'Bp', ' ',  'Bp', ' '   ],
	[ 'WN',  ' ',  'Wp',  ' ', 'BK', ' ',  'Wp', ' '   ],
	[ ' ',   'Bp', ' ',   ' ', 'Wp', ' ',  ' ',  'Bp'  ],
	[ ' ',   'Wp', ' ',   ' ', 'Wp', ' ',  ' ',  'Wp'  ],
	[ ' ',   ' ',  ' ',   ' ', ' ',  'WN', ' ',  ' '   ],
];

# what's the longest string (widest text) we'll use?
my $font_size = 15;
my $font = $pdf->corefont('Helvetica');
my $text = $page->text();
$text->font($font, $font_size);
my $min_width = $text->advancewidth('WKR');
   $min_width += 2 * 2;  # L + R padding

# build the table layout
$pdftable->table(

	# required params
	$pdf,
	$page,
	$chessboard,
	x  => 10,
	w  => 8 * $min_width + 1,
	y  => 700, 
	h  => 8 * $min_width + 1,

	# some optional params
	padding    => 2,
	padding_top => 10.4,  # center vertically in cell
	justify    => "center",
	font       => $font,
	font_size  => $font_size,
	min_w      => $min_width,
	max_w      => $min_width,
	min_rh     => $min_width,

	column_props => [
		{bg_color_odd => 'black', fg_color_odd => 'white',    # col 0
		bg_color_even => 'white', fg_color_even => 'black' },
		{bg_color_odd => 'white', fg_color_odd => 'black',    # col 1
		bg_color_even => 'black', fg_color_even => 'white' },
		{bg_color_odd => 'black', fg_color_odd => 'white',    # col 2
		bg_color_even => 'white', fg_color_even => 'black' },
		{bg_color_odd => 'white', fg_color_odd => 'black',    # col 3
		bg_color_even => 'black', fg_color_even => 'white' },
		{bg_color_odd => 'black', fg_color_odd => 'white',    # col 4
		bg_color_even => 'white', fg_color_even => 'black' },
		{bg_color_odd => 'white', fg_color_odd => 'black',    # col 5
		bg_color_even => 'black', fg_color_even => 'white' },
		{bg_color_odd => 'black', fg_color_odd => 'white',    # col 6
		bg_color_even => 'white', fg_color_even => 'black' },
		{bg_color_odd => 'white', fg_color_odd => 'black',    # col 7
		bg_color_even => 'black', fg_color_even => 'white' },
        ],
	cell_props => [
		[],[],[],  # rows 1-3, no cell overrides
		[    # row 4 col 3 gray bg, red fg
			{}, {}, 
			{ bg_color => '#888888', fg_color => 'red' } 
		],
		[    # row 5 cols 1-3 gray bg, red fg for col 1
		        { bg_color => '#888888', fg_color => 'red' },
		        { bg_color => '#888888'                    },
		        { bg_color => '#888888'                    },
		],
	],
);

$pdf->save();
