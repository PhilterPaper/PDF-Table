#!/usr/bin/env perl
use warnings;
use strict;
use diagnostics;
use PDF::Table;
########################################################
# NOTE: latest version of PDF::API2 (2.043) seems to
# have some incompatible font changes, resulting in
# $min_width being twice what it is in PDF::Builder, and
# resulting in the chessboard being far too big. This 
# is being investigated.
########################################################

#my $mode = 'text';     # use letters from Helvetica
my $mode = 'graphics';  # use Unicode chess glyphs from DejaVu-Sans
#my $mode = 'images';   # TBD use of images

# Demonstrate a chessboard using even and odd row bg and fg color definitions
#  on a per-column ($column_props) basis.
# Gray bg shows move of White Knight to capture Black King's Bishop (both red),
#  with $cell_props.
# Once images are supported, will change to pictures of pieces (or maybe both).

# Please use TABSTOP=4 for best view
# -------------
# -A or -B on command line to select preferred library (if available)
# then look for PDFpref file and read A or B forms
my ($PDFpref, $rcA, $rcB); # which is available?
my $prefFile = "examples/PDFpref";
my $prefix = 0;  # by default, do not add a prefix to the output name
my $prefDefault = "B"; # PDF::Builder default if no prefFile, or both installed

# command line selection of preferred library? A..., -A..., B..., or -B...
if (@ARGV) {
    # A or -A argument: set PDFpref to A else B
    if ($ARGV[0] =~ m/^-?([AB])/i) {
	$PDFpref = uc($1);
	$prefix = 1;
    } else {
	print STDERR "Unknown command line flag $ARGV[0] ignored.\n";
    }
}
# environment variable selection of preferred library?
# A..., B..., PDF:[:]A..., or PDF:[:]B...
if (!defined $PDFpref) {
    if (defined $ENV{'PDF_prefLib'}) {
        $PDFpref = $ENV{'PDF_prefLib'};
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
        }
    }
}
# PDF preference file selecting preferred library?
# A..., B..., PDF:[:]A..., or PDF:[:]B...
if (!defined $PDFpref) {
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
        }
        close $FH;
    }
}
# still no preferred library indicated? use the default
if (!defined $PDFpref) {
        # no preference expressed, default to PDF::Builder
        print STDERR "No library preference given, so default to ".
	  (($prefDefault eq 'A')? 'PDF::API2': 'PDF::Builder')." as preferred.\n";
        $PDFpref = $prefDefault;
}

# try to use the preferred library, if available
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

# appears to work as of 2.044
#if ($PDFpref eq 'A') {
#    print STDERR "chess example fails due to PDF::API2 bug, and is not run.\n";
#    exit(0);
#}
# -------------

# VERSION
our $LAST_UPDATE = '1.006'; # manually update whenever code is changed

my $outfile = $0;
if ($outfile =~ m#[\\/]([^\\/]+)$#) { $outfile = $1; }
$outfile =~ s/\.pl$/.pdf/;
# command line -A or -B adds A_ or B_ to outfile
if ($prefix) { $outfile = $PDFpref . "_" . $outfile; }

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
my $chessboard;
if ($mode eq 'text') {
    $chessboard = [
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
} else {
    $chessboard = [
	# rows TTB, LTR value=piece name, or blank for empty
	[ "\x{2657}", ' ', ' ', ' ', ' ', ' ', "\x{2654}", "\x{2656}" ],
	[ ' ', ' ', ' ', ' ', ' ', ' ', ' ', "\x{265C}" ],
	[ ' ', ' ', "\x{2656}", ' ', ' ', ' ', ' ', ' '   ],
	[ ' ', ' ', "\x{265D}", ' ', "\x{265F}", ' ', "\x{265F}", ' ' ],
	[ "\x{2658}", ' ', "\x{2659}", ' ', "\x{265A}", ' ', "\x{2659}", ' ' ],
	[ ' ', "\x{265F}", ' ', ' ', "\x{2659}", ' ', ' ', "\x{265F}" ],
	[ ' ', "\x{2659}", ' ', ' ', "\x{2659}", ' ', ' ', "\x{2659}" ],
	[ ' ', ' ', ' ', ' ', ' ', "\x{2658}", ' ', ' ' ],
];
}

# what's the longest string (widest text) we'll use?
my ($font, $font_size, $min_width);
if ($mode eq 'text') {
    $font = $pdf->corefont('Helvetica');
    $font_size = 15;
} else {
    $font = $pdf->ttfont('/Windows/Fonts/dejavusans.ttf');
    $font_size = 30;
    # $font_size /= 2.11 if $PDFpref eq 'A';  # work around one of the bugs
}
my $text = $page->text();
$text->font($font, $font_size);
if ($mode eq 'text') {
   $min_width = $text->advancewidth('WKR');
} else {
    $min_width = 1.7*$text->advancewidth($chessboard->[0][0]);   
}
$min_width += 2 * 2;  # L + R padding

# build the table layout
$pdftable->table(

	# required params
	$pdf,
	$page,
	$chessboard,
	x  => 20,
	w  => 8 * $min_width,
	y  => 700, 
	h  => 8 * $min_width + 1, # if +0, last row to next page!

	# some optional params
	padding    => 2,
	padding_top =>        # center vertically in cell, trial & error
	   ($mode eq 'text')? 10.4: 6.4,
	justify    => "center",
	font       => $font,
	font_size  => $font_size,
	min_w      => $min_width,
	max_w      => $min_width,
	min_rh     => $min_width,

	# unfortunately, the chess pieces (graphics) are designed for
	# black on white, and black fg disappears against black bg.
	# however BonW and WonB make it hard to tell B and W pieces!
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
		[],[],[],  # rows 0-2, no cell overrides
		# red fg looks good for text, but bad for symbols
		# anyone who knows chess will figure out it's NxB
		[    # row 3 col 2 gray bg, red fg
			{}, {}, 
			{ bg_color => '#888888' } 
		],
		[    # row 4 cols 0-2 gray bg, red fg for col 0
		        { bg_color => '#888888' },
		        { bg_color => '#888888' },
		        { bg_color => '#888888' },
		],
	],
);

$pdf->save();
