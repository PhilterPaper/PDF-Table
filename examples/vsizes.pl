#!/usr/bin/env perl
use warnings;
use strict;
use diagnostics;
use PDF::Table;

# Demonstrate vertical sizes on a number of tables.

# Please use TABSTOP=4 for best view
# -------------
# -A or -B on command line to select preferred library (if available)
# then look for PDFpref file and read A or B forms
my ($PDFpref, $rcA, $rcB); # which is available?
my $prefFile = "./PDFpref";
my $prefix = 0;  # by default, do not add a prefix to the output name
my $prefDefault = "B"; # PDF::Builder default if no prefFile, or both installed
if (@ARGV) {
    # A or -A argument: set PDFpref to A else B
    if ($ARGV[0] =~ m/^-?([AB])/i) {
	$PDFpref = uc($1);
	$prefix = 1;
    } else {
	print STDERR "Unknown command line flag $ARGV[0] ignored.\n";
    }
}
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
my $LAST_UPDATE = '1.004'; # manually update whenever code is changed

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
    $pdf      = PDF::API2->new( 'file' => $outfile );
} else {
    print STDERR "Using PDF::Builder library\n";
#   $pdf      = PDF::Builder->new( 'file' => $outfile );
    $pdf      = PDF::Builder->new( 'file' => $outfile, 'compress'=>'none' );
}
# -------------
my $page     = $pdf->page();
my $text     = $page->text();
my @vsizes;
my $table;

my $font_size = 15;
my $font  = $pdf->corefont('Helvetica');
my $fontb = $pdf->corefont('Helvetica-Bold');
$text->font($font, 15);
my $grfx = $page->gfx();

# draw scale
$grfx->move(500, 660);
$grfx->hline(572);
$grfx->vline(732);
$grfx->move(500, 660+72*1.54/2.54);
$grfx->hline(500+72*1/2.54);
$grfx->vline(660+72);
$grfx->stroke();
$text->translate(485, 665);
$text->text("1 in = 72 Pt");
$text->translate(485, 665+72*1.54/2.54);
$text->text("1 cm");

############################################################################
# illustrate thick border with thin rules
# -------------------- table 1
foreach my $ink (0..1) {
    $table = [
	# rows TTB, LTR 
	[ 'Thick', 'border', ],
	[ 'Thin', 'rules', ],
    ];

    # build the table layout
    @vsizes =
    $pdftable->table(

	# required params
	$pdf,
	$page,
	$table,
	'x'  => 10,
	'w'  => 100,
	'y'  => 700, 
	'h'  => 100,
        'ink' => $ink, 

	# some optional params
	'justify'    => "center",
	'font'       => $font,
	'font_size'  => $font_size,
	# borders both black, 8 wide
	'border_w'   => 8,
	# rules blue, 1 wide
	'rule_w'     => 1,
	'rule_c'     => 'blue',

	'cell_props' => [
		[],
		[
			{ 'font' => $fontb, },
		],
	],
    );

    if ($ink) {
	$page = $vsizes[0]; # may be new page if spillover
       #print "page count $vsizes[1], current y $vsizes[2]\n";
    } else {
	$text->translate(10, 720);
        $text->text("Table 1 sizes: @vsizes");
    }
}

# -------------------- table 2
# illustrate colspans
foreach my $ink (0..1) {
    $table = [

    # Row 1, with 3 cols
    [   "(r1c1) Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.",
        "(r1c2) Ut",
        "(r1c3) enim ad minim veniam, [3 cols in row 1]"
    ],

    # Row 2, one col with colspan=3
    [   "(r2c1++) quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. [spans 3 columns]"
    ],

    # Row 3, one regular col, one with colspan=2
    [   "(r3c1) Excepteur sint occaecat cupidatat",
        "(r3c2+) non proident, sunt in culpa qui officia deserunt mollit anim id est laborum. [spans cols 2 and 3]"
    ],

    ];

    # build the table layout
    @vsizes =
    $pdftable->table(
        $pdf, $page, $table,
        'w'            => 265,    # width of table
        'x'            => 10,     # position from left
        'start_y'      => 580,    # or y. position from bottom
        'start_h'      => 400,    # or h. max height of table
        'ink'          => $ink, 
        'padding'      => 5,      # padding on all 4 sides of a cell
        'column_props' => [
            { 'min_w' => 150, background_color => 'grey' },    # col 1
            { 'background_color' => 'red' },                   # col 2, including
	                        # colspanned col 3 on row 3
            {}                                               # col 3 (nothing)
        ],
        'cell_props' => [  # no header, so data row 0 is actually row 1
            [   {},    # row 1 cell 2 & 3 overrides
                { 'background_color' => 'pink' },   # or bg_color
                { 'background_color' => 'blue', colspan => 1 }
            ],
            [ { 'colspan' => 3 } ],        # row 2 cell 1 override
            [ {}, { 'colspan' => 2 } ],    # row 3 cell 2 override
        ],
    );

    if ($ink) {
	$page = $vsizes[0]; # may be new page if spillover
       #print "page count $vsizes[1], current y $vsizes[2]\n";
    } else {
	$text->translate(10, 600);
        $text->text("Table 2 sizes: @vsizes");
    }
}

# -------------------- table 3
# illustrate a very long table that splits over multiple pages

# Lorem Ipsum text, borrowed from PDF::Builder::examples/022_truefonts 
foreach my $ink (0..1) {
    $table = [
    [ # 0,0
"Sed ut perspiciatis, unde omnis iste natus error sit ".
"voluptatem accusantium doloremque laudantium, totam rem aperiam eaque ipsa, ".
"quae ab illo inventore veritatis et quasi architecto beatae vitae dicta ".
"sunt, explicabo.",
      # 0,1
"Nemo enim ipsam voluptatem, quia voluptas sit, aspernatur ".
"aut odit aut fugit, sed quia consequuntur magni dolores eos, qui ratione ".
"dolor sit, voluptatem sequi nesciunt, neque porro quisquam est, qui dolorem ".
"ipsum, quia amet, consectetur, adipisci velit, sed quia non numquam eius ".
"modi tempora incidunt, ut labore et dolore magnam aliquam quaerat ".
"voluptatem."
    ],
    [ # 1,0
"Ut enim ad minima veniam, quis nostrum exercitationem ullam ".
"corporis suscipit laboriosam, nisi ut aliquid ex ea commodi consequatur?",
      # 1,1
"Quis autem vel eum iure reprehenderit, qui in ea voluptate velit esse, quam ".
"nihil molestiae consequatur, vel illum, qui dolorem eum fugiat, quo voluptas ".
"nulla pariatur?"
    ],
    [ # 2,0
"At vero eos et accusamus et iusto odio dignissimos ducimus, ".
"qui blanditiis praesentium voluptatum deleniti atque corrupti, quos dolores ".
"et quas molestias excepturi sint, obcaecati cupiditate non provident, ".
"similique sunt in culpa, qui officia deserunt mollitia animi, id est laborum ".
"et dolorum fuga.",
      # 2,1
"Et harum quidem rerum facilis est et expedita distinctio."
    ],
    [ # 3,0
"Nam libero tempore, cum soluta nobis est eligendi optio, cumque nihil ".
"impedit, quo minus id, quod maxime placeat, facere possimus, omnis voluptas ".
"assumenda est, omnis dolor repellendus.",
      # 3,1
"Temporibus autem quibusdam et aut ".
"officiis debitis aut rerum necessitatibus saepe eveniet, ut et voluptates ".
"repudiandae sint et molestiae non recusandae. Itaque earum rerum hic tenetur ".
"a sapiente delectus, ut aut reiciendis voluptatibus maiores alias ".
"consequatur aut perferendis doloribus asperiores repellat."
    ]
    ];

    # build the table layout
    @vsizes =
    $pdftable->table(

	# required params
	$pdf,
	$page,
	$table,
	'x'  => 10,
	'w'  => 240,
	'y'  => 200,      # start near bottom
	'h'  => 150,      # adjust to split in middle of row
        'ink' => $ink,

	'next_y' => 700,
	'next_h' => 500,  # adjust to split at least once at row boundary
	                # 530 is also a good split

	# some optional params
	'default_text' => ' ',
	'justify'    => "left",
	'font'       => $font,
	'font_size'  => $font_size,
	'padding'    => 10,
	# thick borders 
	'border_w'   => 6,
	'border_c'   => '#222222',
	# thin rules
	'rule_w'     => 2,  # to distinguish from split-row solid/dashed
	# rule_c inherits from border_c (dark gray)

    );
    if ($ink) {
	$page = $vsizes[0]; # may be new page if spillover
       #print "page count $vsizes[1], current y $vsizes[2]\n";
    } else {
	$text->translate(10, 220);
        $text->text("Table 3 sizes: @vsizes");
    }
}

# -------------------- table 4
# illustrate a table with repeated headers

# starts on page 5, so need to update $text and font to be on current $page
$text = $page->text();
$text->font($font, 15);

foreach my $ink (0..1) {
    $table = [
	[ 'Header',              'Row',   'Test' ],
	[ '1 Lorem ipsum dolor', 'Donec', 'consequat quis, tincidunt vel, felis.' ],
	[ '2 Lorem ipsum dolor', 'Donec super long text goes here to provoke a text block', 'consequat quis, tincidunt vel, felis.' ],
	[ '3 Lorem ipsum dolor', 'Donec', 'consequat quis, tincidunt vel, felis.' ],
	[ '4 Lorem ipsum dolor', 'Donec super long text goes here to provoke a text block', 'consequat quis, tincidunt vel, felis.' ],
	[ '5 Lorem ipsum dolor', 'Donec', 'consequat quis, tincidunt vel, felis.' ],
	[ '6 Lorem ipsum dolor', 'Donec', 'consequat quis, tincidunt vel, felis.' ],
	[ '7 Lorem ipsum dolor', 'Donec', 'consequat quis, tincidunt vel, felis.' ],
	[ '8 Lorem ipsum dolor', 'Donec', 'consequat quis, tincidunt vel, felis.' ],
	[ '9 Lorem ipsum dolor', 'Donec', 'consequat quis, tincidunt vel, felis.' ],

    ];

    # build the table layout
    my $cell_props = [];
    $cell_props->[2][1] = {
	'background_color' => '#000000',  # or bg_color
	'font_color'       => 'blue',     # or fg_color
	'justify'          => 'left'
    };
    $cell_props->[4][1] = {
	'background_color' => '#000000',
	'font_color'       => 'red',
	'justify'          => 'center'
    };
    $cell_props->[6][1] = {
	'background_color' => '#000000',
	'font_color'       => 'yellow',
	'justify'          => 'right'
    };

    # note that cell properties taken out-of-line
    @vsizes =
    $pdftable->table(

	# required params
	$pdf,
	$page,
	$table,
	'x'       => 10,
	'w'       => 350,
	'start_y' => 300,  # or y
	'next_y'  => 780,
	'start_h' => 210,  # or h
	'next_h'  => 210,
	'ink'     => $ink,

	# some optional params
	'font_size'          => 10,
	'padding'            => 10,
       #padding_right      => 10,
	'horizontal_borders' => 1,
	'header_props'       => {
		'bg_color'   => "silver",
		'font'       => $pdf->corefont( "Helvetica", -encoding => "utf8" ),
		'font_size'  => 20,
		'font_color' => "#006600",  # or fg_color
		#'justify' => 'left',
		'repeat'  => 1,  # default
	},
	'cell_props' => $cell_props
    );

    if ($ink) {
	$page = $vsizes[0]; # may be new page if spillover
       #print "page count $vsizes[1], current y $vsizes[2]\n";
    } else {
	$text->translate(10, 320);
        $text->text("Table 4 sizes: @vsizes");
    }
}

$pdf->save();
