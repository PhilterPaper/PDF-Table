#!/usr/bin/env perl
# vim: softtabstop=4 tabstop=4 shiftwidth=4 ft=perl expandtab smarttab

use 5.010;
use strict;
use warnings;

package PDF::Table;

use Carp;
use List::Util qw[min max];  # core

our $VERSION = '1.000'; # fixed, read by Makefile.PL
my $LAST_UPDATE = '1.000'; # manually update whenever code is changed

my $compat_mode = 0; # 0 = new behaviors, 1 = compatible with old

# ================ COMPATIBILITY WITH OLDER VERSIONS ===============
my $repeat_default   = 1;  # header repeat: old = change to 0
my $oddeven_default  = 1;  # odd/even lines, use old method = change to 0
my $padding_default  = 2;  # 2 points of padding. old = 0 (no padding)
my $borders_as_rules = 0;  # if 1, use borders settings as rules
# ==================================================================
if ($compat_mode) {
    ($repeat_default, $oddeven_default, $padding_default, $borders_as_rules) =
    (0, 0, 0, 1);
} else {
    ($repeat_default, $oddeven_default, $padding_default, $borders_as_rules) =
    (1, 1, 2, 0);
}

# ================ OTHER GLOBAL DEFAULTS =========================== per #7
my $fg_color_default   = 'black';   # foreground text color
# no bg_color_default (defaults to transparent background)
my $h_fg_color_default = '#000066'; # fg text color for header
my $h_bg_color_default = '#FFFFAA'; # bg color for header
my $font_size_default  = 12; # base font size
my $leading_ratio      = 1.25;  # leading/font_size ratio (if 'lead' not given)
my $border_w_default   = 1;  # line width for borders
my $max_wordlen_default = 20; # split any run of 20 non-space chars
my $empty_cell_text    = '-'; # something to put in an empty cell
# ==================================================================

print __PACKAGE__.' is version: '.$VERSION.$/ if ($ENV{'PDF_TABLE_DEBUG'});

############################################################
#
# new - Constructor
#
# Parameters are meta information about the PDF. They may be
# omitted, so long as the information is passed instead to
# the table() method.
#
# $pdf = PDF::Table->new();
# $page = $pdf->page();
# $data
# %options
#
############################################################

sub new {
    my $type = shift(@_);
    my $class = ref($type) || $type;
    my $self  = {};
    bless ($self, $class);

    # Pass all the rest to init for validation and initialization
    $self->_init(@_);

    return $self;
}

sub _init {
    my ($self, $pdf, $page, $data, %options ) = @_;

    # Check and set default values
    $self->set_defaults();

    # Check and set mandatory parameters
    $self->set_pdf($pdf);
    $self->set_page($page);
    $self->set_data($data);
    $self->set_options(\%options);

    return;
}

sub set_defaults {
    my $self = shift;

    $self->{'font_size'} = $font_size_default;
    return;
}

sub set_pdf {
    my ($self, $pdf) = @_;
    $self->{'pdf'} = $pdf;
    return;
}

sub set_page {
    my ($self, $page) = @_;
    if ( defined($page) && ref($page) ne 'PDF::API2::Page'
                        && ref($page) ne 'PDF::Builder::Page' ) {

        if (ref($self->{'pdf'}) eq 'PDF::API2' ||
            ref($self->{'pdf'}) eq 'PDF::Builder') {
            $self->{'page'} = $self->{'pdf'}->page();
        } else {
            carp 'Warning: Page must be a PDF::API2::Page or PDF::Builder::Page object but it seems to be: '.ref($page).$/;
            carp 'Error: Cannot set page from passed PDF object either, as it is invalid!'.$/;
        }
        return;
    }
    $self->{'page'} = $page;
    return;
}

sub set_data {
    my ($self, $data) = @_;
    # TODO: implement
    return;
}

sub set_options {
    my ($self, $options) = @_;
    # TODO: implement
    return;
}

################################################################
# table - utility method to build multi-row, multicolumn tables
################################################################

sub table {
#use Storable qw( dclone );
# can't use Storable::dclone because can't handle CODE. would like to deep
# clone %arg so that modifications (remove leading '-' and/or substitute for
# deprecated names) won't modify original %arg hash on the outside.
    my $self    = shift;
    my $pdf     = shift;
    my $page    = shift;
    my $data    = shift;
    my %arg     = @_;

    #=====================================
    # Mandatory Arguments Section
    #=====================================
    unless ($pdf and $page and $data) {
        carp "Error: Mandatory parameter is missing PDF/page/data object!\n";
        return;
    }

    # Validate mandatory argument data type
    croak "Error: Invalid PDF object received."  
        unless (ref($pdf) eq 'PDF::API2' ||
                ref($pdf) eq 'PDF::Builder');
    croak "Error: Invalid page object received." 
        unless (ref($page) eq 'PDF::API2::Page' || 
                ref($page) eq 'PDF::Builder::Page');
    croak "Error: Invalid data received." 
        unless ((ref($data) eq 'ARRAY') && scalar(@$data));
    croak "Error: Missing required settings." 
        unless (scalar(keys %arg));

    # ==================================================================
    # did client code ask to redefine?
    ($repeat_default, $oddeven_default, $padding_default, $borders_as_rules) =
      @{$arg{'compatibility'}} if defined $arg{'compatibility'};

    # set some defaults  !!!!
    $arg{'cell_render_hook' } ||= undef; 

    # Validate settings key
    my %valid_settings_key = (
        'x'                     => 1,  # global, mandatory
        'w'                     => 1,  # global, mandatory
        'y'                     => 1,  # global, mandatory
          'start_y'             => 1,  #  deprecated
        'h'                     => 1,  # global, mandatory
          'start_h'             => 1,  #  deprecated
        'next_y'                => 1,  # global
        'next_h'                => 1,  # global
        'leading'               => 1,  #         text_block
          'lead'                => 1,  #  deprecated
        'padding'               => 1,  # global
        'padding_right'         => 1,  # global
        'padding_left'          => 1,  # global
        'padding_top'           => 1,  # global
        'padding_bottom'        => 1,  # global
        'bg_color'              => 1,  # global, header, row, column, cell
          'background_color'    => 1,  #  deprecated
        'bg_color_odd'          => 1,  # global
          'background_color_odd'=> 1,  #  deprecated
        'bg_color_even'         => 1,  # global
          'background_color_even'=> 1,  # deprecated
        'fg_color'              => 1,  # global, header, row, column, cell
          'font_color'          => 1,  #  deprecated
        'fg_color_odd'          => 1,  # global
          'font_color_odd'      => 1,  #  deprecated
        'fg_color_even'         => 1,  # global
          'font_color_even'     => 1,  #  deprecated
        'border'                => 1,  # global
        'border_color'          => 1,  # global
    #   'h_borders'             => 1,  # global
          'horizontal_borders'  => 1,  #  deprecated
    #   'v_borders'             => 1,  # global
          'vertical_borders'    => 1,  #  deprecated
        'font'                  => 1,  # global, header, row, column, cell
        'font_size'             => 1,  # global, header, row, column, cell
        'underline'             => 1,  # global, header, row, column, cell
          'font_underline'      => 1,  #  deprecated
        'min_w'                 => 1,  # global, header, row, column, cell
        'max_w'                 => 1,  # global, header, row, column, cell
        'row_height'            => 1,  # global, header, row, column, cell
        'new_page_func'         => 1,  # global
        'header_props'          => 1,   # includes sub-settings like repeat
        'row_props'             => 1,   # includes sub-settings like fg_color
        'column_props'          => 1,   # includes sub-settings like fg_color
        'cell_props'            => 1,   # includes sub-settings like fg_color
        'max_word_length'       => 1,  # global, text_block
        'cell_render_hook'      => 1,  # global
        'default_text'          => 1,  # global
        'justify'               => 1,  # global
      # 'repeat'                       #         header
      # 'align'                        #         text_block
      # 'parspace'                     #         text_block
      # 'hang'                         #         text_block
      # 'flindent'                     #         text_block
      # 'fpindent'                     #         text_block
      # 'indent'                       #         text_block
    );
    foreach my $key (keys %arg) {
        # Provide backward compatibility
        $arg{$key} = delete $arg{"-$key"} if $key =~ s/^-//;

        croak "Error: Invalid setting key '$key' received."
            unless exists $valid_settings_key{$key};
    }


    my ( $xbase, $ybase, $width, $height ) = ( undef, undef, undef, undef );
    # TBD eventually deprecated start_y and start_h go away
    # special treatment here because haven't yet copied deprecated names
    $xbase  = $arg{'x'} || -1;
    $ybase  = $arg{'y'} || $arg{'start_y'} || -1;
    $width  = $arg{'w'} || -1;
    $height = $arg{'h'} || $arg{'start_h'} || -1;

    # Global geometry parameters are also mandatory.
    unless ( $xbase  > 0 ) {
        carp "Error: Left Edge of Table is NOT defined!\n";
        return;
    }
    unless ( $ybase  > 0 ) {
        carp "Error: Base Line of Table is NOT defined!\n";
        return;
    }
    unless ( $width  > 0 ) {
        carp "Error: Width of Table is NOT defined!\n";
        return;
    }
    unless ( $height > 0 ) {
        carp "Error: Height of Table is NOT defined!\n";
        return;
    }

    my $pg_cnt      = 1;
    my $cur_y       = $ybase;
    my $cell_props  = $arg{'cell_props'} || [];   # per cell properties

    # If there is no valid data array reference, warn and return!
    if (ref $data ne 'ARRAY') {
        carp "Passed table data is not an ARRAY reference. It's actually a ref to ".ref($data);
        return ($page, 0, $cur_y);
    }

    # Ensure default values for next_y and next_h 
    my $next_y  = $arg{'next_y'} || undef;
    my $next_h  = $arg{'next_h'} || undef;

    # Create Text Object
    my $txt     = $page->text();

    #=====================================
    # Table Header Section
    #
    # order of precedence: header_props, column_props, globals, defaults
    # here, header settings are initialized to globals/defaults
    #=====================================
    # Disable header row into the table
    my $header_props = undef;
    my $do_headers = 0;  # not doing headers

    # Check if the user enabled it ?
    if (defined $arg{'header_props'} and ref( $arg{'header_props'}) eq 'HASH') {
        # Transfer the reference to local variable
        $header_props = $arg{'header_props'};

        # Check other parameters and put defaults if needed
        $header_props->{'repeat'   } ||= $repeat_default;

        $do_headers = 1;  # do headers, no repeat
        $do_headers = 2 if $header_props->{'repeat'};  # do headers w/ repeat
    }

    my $header_row  = undef;
    # Copy the header row (text) if header is enabled
    @$header_row = $$data[0] if $do_headers;
    # Determine column widths based on content

    # an arrayref whose values are a hashref holding
    # the minimum and maximum width of that column
    my $col_props = $arg{'column_props'} || [];

    # an arrayref whose values are a hashref holding
    # various row settings for a specific row
    my $row_props = $arg{'row_props'} || [];

    # deprecated setting (globals) names, copy to new names
    deprecated_settings($data, $row_props, $col_props, $cell_props, $header_props, \%arg);
    # check settings values as much as possible
    check_settings(%arg);

    #=====================================
    # Set Global Default Properties
    #=====================================
    # geometry-related global settings checked, last value for find_value()
    my $fnt_obj        = $arg{'font'            } ||
                         $pdf->corefont('Times',-encode => 'latin1');
    my $fnt_size       = $arg{'font_size'       } || $font_size_default;
    my $min_leading    = $fnt_size * $leading_ratio;
    my $leading        = $arg{'leading'} || $min_leading;
    if ($leading < $fnt_size) {
        carp "Warning: Global leading value $leading is less than font size $fnt_size, increased to $min_leading\n";
        $arg{'leading'} = $leading = $min_leading;
    }

    # TBD line_w becomes rule_w, all 'border' become 'rule'
    # can't condense $line_w to || because border=>0 gets default of 1!
    my $line_w        = defined $arg{'border'}? $arg{'border'}: 1;
    my $horiz_borders = $arg{'horizontal_borders'} || $line_w;
    my $vert_borders  = $arg{'vertical_borders'}   || $line_w;

    # non-geometry global settings
    my $underline       = $arg{'underline'       } || 
                          undef; # merely stating undef is the intended default
    my $max_word_len    = $arg{'max_word_length' } || $max_wordlen_default;
    my $default_text    = $arg{'default_text'  } // $empty_cell_text;

    # odd and even row colors (bg/fg) can be overridden
    # FIX doc to reflect this
    my $bg_color_even   = $arg{'bg_color_even' } || undef;
    my $bg_color_odd    = $arg{'bg_color_odd'  } || undef;
    my $fg_color_even   = $arg{'fg_color_even' } || undef;
    my $fg_color_odd    = $arg{'fg_color_odd'  } || undef;
    my $border_color    = $arg{'border_color'  } || $fg_color_default;

    # An array ref of arrayrefs whose values are
    # the actual widths of the column/row intersection
    my $row_col_widths = [];
    # An array ref with the widths of the header row
    my $h_row_widths = [];

    # Scalars that hold sum of the maximum and minimum widths of all columns
    my ( $max_col_w  , $min_col_w ) = ( 0,0 );
    my ( $row, $col_name, $col_fnt_size, $space_w );

    my $word_widths   = {};
    my $rows_height   = [];
    my $first_row     = 1;
    my $is_header_row = 0;

    # per-cell values
    my ($cell_font, $cell_font_size, $cell_underline, $cell_justify, 
        $cell_height, $cell_pad_top, $cell_pad_right, $cell_pad_bot, 
        $cell_pad_left, $cell_leading, $cell_max_word_len, $cell_bg_color,
        $cell_fg_color, $cell_min_w, $cell_max_w);

    # for use by find_value()
    my $GLOBALS = [$cell_props, $col_props, $row_props, -1, -1, \%arg];
    # ----------------------------------------------------------------------
    # GEOMETRY
    # figure row heights and column widths, 
    # update overall table width if necessary
    # here we're only interested in things that affect the table geometry
    #
    # $rows_height->[$row_idx] array overall height of each row
    # $calc_column_widths overall width of each column
    # $row_col_widths->[$row_idx] array of widths per row
    #   at this point, could have different widths within a column, or
    #   different heights within a row!
    for ( my $row_idx = 0; $row_idx < scalar(@$data) ; $row_idx++ ) {
        $GLOBALS->[3] = $row_idx;
        my $column_widths = []; # holds the width of each column
        # initialize the height for this row
        $rows_height->[$row_idx] = 0;

        for ( my $col_idx = 0; 
              $col_idx < scalar(@{$data->[$row_idx]}); 
              $col_idx++ ) {
            $GLOBALS->[4] = $col_idx;

            if ( !$row_idx && $do_headers ) {
                # header row
                $is_header_row     = 1;
                $GLOBALS->[3] = 0;
                $cell_font         = $header_props->{'font'};
                $cell_font_size    = $header_props->{'font_size'};
                $cell_leading      = $header_props->{'leading'};
                $cell_height       = $header_props->{'row_height'};
                $cell_pad_top      = $header_props->{'padding_top'};
                $cell_pad_right    = $header_props->{'padding_right'};
                $cell_pad_bot      = $header_props->{'padding_bottom'};
                $cell_pad_left     = $header_props->{'padding_left'};
                $cell_max_word_len = $header_props->{'max_word_length'};
                $cell_min_w        = $header_props->{'min_w'};
                $cell_max_w        = $header_props->{'max_w'};
               #$cell_underline    = $header_props->{'underline'};
               #$cell_def_text     = $header_props->{'default_text'};
               #$cell_justify      = $header_props->{'justify'};
               #$cell_bg_color     = $header_props->{'bg_color'};
               #$cell_fg_color     = $header_props->{'fg_color'};
                if (!defined $cell_font_size) { 
                    $cell_font_size = $fnt_size + 2;
                }
            } else {
                # not a header row, so uninitialized
                $is_header_row     = 0;
                $cell_font         = undef;
                $cell_font_size    = undef;
                $cell_leading      = undef;
                $cell_height       = undef;
                $cell_pad_top      = undef;
                $cell_pad_right    = undef;
                $cell_pad_bot      = undef;
                $cell_pad_left     = undef;
                $cell_max_word_len = undef;
                $cell_min_w        = undef;
                $cell_max_w        = undef;
               #$cell_underline    = undef;
               #$cell_def_text     = undef;
               #$cell_justify      = undef;
               #$cell_bg_color     = undef;
               #$cell_fg_color     = undef;
            }

            # Get the most specific value if none was already set from header_props
            # TBD should header_props be treated like a row_props (taking
            # precedence over row_props), but otherwise like a row_props? or
            # should anything in header_props take absolute precedence as now?

            $cell_font         = find_value($cell_font, 
                                            'font', '', $fnt_obj, $GLOBALS);
            $cell_font_size    = find_value($cell_font_size, 
                                           'font_size', '', 0, $GLOBALS);
            if ($cell_font_size == 0) { $cell_font_size = $fnt_size; }
            $cell_leading      = find_value($cell_leading, 'leading', 
                                            '', -1, $GLOBALS);
            $cell_height       = find_value($cell_height, 
                                            'row_height', '', 0, $GLOBALS);
            $cell_pad_top      = find_value($cell_pad_top, 'padding_top', 
                                            'padding', $padding_default, 
                                            $GLOBALS);
            $cell_pad_right    = find_value($cell_pad_right, 'padding_right', 
                                            'padding', $padding_default, 
                                            $GLOBALS);
            $cell_pad_bot      = find_value($cell_pad_bot, 'padding_bottom', 
                                            'padding', $padding_default, 
                                            $GLOBALS);
            $cell_pad_left     = find_value($cell_pad_left, 'padding_left', 
                                            'padding', $padding_default, 
                                            $GLOBALS);
            $cell_max_word_len = find_value($cell_max_word_len, 'max_word_len', 
                                            '', $max_word_len, $GLOBALS);
            $cell_min_w        = find_value($cell_min_w, 'min_w', 
                                            '', undef, $GLOBALS);
            $cell_max_w        = find_value($cell_max_w, 'max_w', 
                                            '', undef, $GLOBALS);
           #$cell_underline = find_value($cell_underline, 
           #                             'underline', '', $underline, $GLOBALS);
           #$cell_def_text  = find_value($cell_def_text, 'default_text', '', 
           #                             $default_text, $GLOBALS);
           #$cell_justify   = find_value($cell_justify, 
           #                             'justify', '', 'left', $GLOBALS);
           #$cell_bg_color  = find_value($cell_bg_color, 'bg_color',
           #                             '', undef, $GLOBALS);
           #$cell_fg_color  = find_value($cell_fg_color, 'fg_color',
           #                             '', $fg_color_default, $GLOBALS);

            my $min_leading    = $cell_font_size * $leading_ratio;
            if ($cell_leading <= 0) {
                # leading left at default, silently set to minimum
                $cell_leading = $min_leading;
            } else {
                # leading specified, but is too small?
                if ($cell_leading < $cell_font_size) {
                    carp "Warning: Cell[$row_idx][$col_idx] leading value $cell_leading is less than font size $cell_font_size, increased to $min_leading\n";
                    $cell_leading = $min_leading;
                }
            }

            # Set Font
            $txt->font( $cell_font, $cell_font_size );

            # Set row height to biggest font size from row's cells
            # Note that this assumes just one line of text per cell
            $rows_height->[$row_idx] = max($rows_height->[$row_idx], 
                $cell_leading + $cell_pad_top + $cell_pad_bot, $cell_height);

            # This should fix a bug with very long words like serial numbers,
            # etc. TBD: consider splitting ONLY on end of line, and adding a
            # hyphen (dash) at split. would have to track split words (by
            # index numbers?) and glue them back together when there's space
            # to do so (including hyphen).
            if ( $cell_max_word_len > 0 && $data->[$row_idx][$col_idx]) {
                $data->[$row_idx][$col_idx] =~ s#(\S{$cell_max_word_len})(?=\S)#$1 #g;
            }

            # Init cell size limits
            $space_w                   = $txt->advancewidth( "\x20" );
            $column_widths->[$col_idx] = 0;
            $max_col_w                 = 0;
            $min_col_w                 = 0;

            my @words;
            @words = split( /\s+/, $data->[$row_idx][$col_idx] )
                if $data->[$row_idx][$col_idx];

            # for cell, minimum width is longest word, maximum is entire text
            # treat header row like any data row for this
            foreach ( @words ) {
                unless ( exists $word_widths->{$_} ) {
                    # Calculate the width of every word and add the space width to it
                    $word_widths->{$_} = $txt->advancewidth( $_ ) + $space_w;
                }

                $min_col_w                     = $word_widths->{$_} if $word_widths->{$_} > $min_col_w;
                if ($max_col_w) {
                    # already have text, so add a space first
                    $max_col_w                 += $word_widths->{$_} + $space_w;
                    $column_widths->[$col_idx] += $word_widths->{$_} + $space_w;
                } else {
                    # first word, so no space [before]
                    $max_col_w                 += $word_widths->{$_};
                    $column_widths->[$col_idx] += $word_widths->{$_};
                }
            }

            $min_col_w                 += $cell_pad_left + $cell_pad_right;
            $max_col_w                 += $cell_pad_left + $cell_pad_right;
            $column_widths->[$col_idx] += $cell_pad_left + $cell_pad_right;

            # Keep a running total of the overall min and max widths
            $col_props->[$col_idx]->{'min_w'} ||= 0;
            $col_props->[$col_idx]->{'max_w'} ||= 0;

            # Calculated Minimum Column Width is more than user-defined?
            $col_props->[$col_idx]->{'min_w'} = max($min_col_w, $cell_min_w||0);

            # not sure what point of "maximum width" is, as a long line will
            # usually be folded into several lines
            # TBD what we need is how many lines of text will be produced, to
            # get the cell height
            # Calculated Maximum Column Width is more than user-defined?
            $col_props->[$col_idx]->{'max_w'} = max($max_col_w, $cell_max_w||0);
        } # End of for (my $col_idx....

        $row_col_widths->[$row_idx] = $column_widths;

        # Copy the calculated row properties of header row.
        @$h_row_widths = @$column_widths if !$row_idx && $do_headers;
    } # End of for ( my $row_idx   row heights and column widths

    # Calc real column widths and expand table width if needed.
    my $calc_column_widths;
    ($calc_column_widths, $width) = CalcColumnWidths( $col_props, $width );

    # ----------------------------------------------------------------------

    # Let's draw what we have!
    my $row_idx      = 0;  # first row (might be header)
    my $row_is_odd   = 1;  # first data row output is "odd"
    # Store header row height for later use if headers have to be repeated
    my $header_row_height = $rows_height->[0];

    my ( $gfx, $gfx_bg, $bg_color, $fg_color, 
         $bot_margin, $table_top_y, $text_start_y);

    # Each iteration adds a new page as necessary
    while (scalar(@{$data})) {
        my ($page_header);
        my $columns_number = 0;

        if ($pg_cnt == 1) {
            # on first page output
            $table_top_y = $ybase;
            $bot_margin = $table_top_y - $height;

            # Check for safety reasons
            if ( $bot_margin < 0 ) {
                carp "!!! Warning: !!! Incorrect Table Geometry! h ($height) greater than remaining page space y ($table_top_y). Reducing height to fit on page.\n";
                $bot_margin = 0;
                $height = $table_top_y;
            }

        } else {
            # on subsequent (overflow) pages output
            if (ref $arg{'new_page_func'}) {
                $page = &{ $arg{'new_page_func'} };
            } else {
                $page = $pdf->page();
            }

            # we NEED next_y and next_h! if undef, complain and use 
            # 90% and 80% respectively of page height
            if (!defined $next_y) {
                my @page_dim = $page->mediabox();
                $next_y = ($page_dim[3] - $page_dim[1]) * 0.9;
                carp "!!! Error: !!! Table spills to next page, but no next_y was given! Using $next_y.\n";
            }
            if (!defined $next_h) {
                my @page_dim = $page->mediabox();
                $next_h = ($page_dim[3] - $page_dim[1]) * 0.8;
                carp "!!! Error: !!! Table spills to next page, but no next_h was given! Using $next_h.\n";
            }

            $table_top_y = $next_y;
            $bot_margin = $table_top_y - $next_h;

            # Check for safety reasons
            if ( $bot_margin < 0 ) {
                carp "!!! Warning: !!! Incorrect Table Geometry! next_h ($next_h) greater than remaining page space next_y ($next_y), must be reduced to fit on page.\n";
                $bot_margin = 0;
                $next_h = $table_top_y;
            }

            # push copy of header onto remaining table data, if repeated hdr
            if ( $do_headers == 2 ) {
                # Copy Header Data
                @$page_header = @$header_row;
                my $hrw ;
                @$hrw = @$h_row_widths ;
                # Then prepend it to master data array
                unshift @$data, @$page_header;
                unshift @$row_col_widths, $hrw;
                unshift @$rows_height, $header_row_height;

                $first_row = 1; # Means YES
                # Roll back the row_idx because a new header row added
                $row_idx--; 
            }
             
        }
        # ----------------------------------------------------------------
        # should be at top of table for current page
        # either start of table, or continuation

        # check if enough vertical space for first data row, AND for header
        # if doing a header row! increase height, decrease bot_margin.
        # possible that bot_margin goes < 0 (warning message).
        # TBD if first page (pg_cnt==1), and sufficient space on next page,
        # just skip first page and go on to second
        my $min_height = $rows_height->[0]; 
        $min_height += $rows_height->[1] if $do_headers && $pg_cnt==1 ||
                                             $do_headers==2 && $pg_cnt>1;
        if ($min_height >= $table_top_y - $bot_margin) {
            # Houston, we have a problem. height isn't enough
            my $delta = $min_height - ($table_top_y - $bot_margin) + 1;
            if ($delta > $bot_margin) {
                carp "!! Error !! Insufficient space (by $delta) to get minimum number of row(s) on page. Some content may be lost off page bottom";
            } else {
                carp "!! Warning !! Need to expand allotted vertical height by $delta to fit minimum number of row(s) on page";
            }
            $bot_margin -= $delta;
            if ($pg_cnt == 1) {
                $height += $delta;
            } else {
                $next_h += $delta;
            }
        }

        # order is important -- cell background layer must be rendered
        # before text layer and then other graphics (rules, borders)
        $gfx_bg = $page->gfx();
        $txt = $page->text();

        $cur_y = $table_top_y;

        if ($line_w) {
            $gfx = $page->gfx();  # for borders, rules, etc.
            $gfx->strokecolor($border_color);
            $gfx->linewidth($line_w);

            # Draw the top line
            if ($horiz_borders) {
                $gfx->move( $xbase , $cur_y );
                $gfx->hline($xbase + $width );
            }
        } else {
            $gfx = undef;
        }

        my @actual_column_widths;
        my %colspanned;

        # Each iteration adds a row to the current page until the page is full
        #  or there are no more rows to add
        # Row_Loop
        while (scalar(@{$data}) and $cur_y-$rows_height->[0] > $bot_margin) {
            # Remove the next item from $data
            my $data_row = shift @{$data};

            # Get max columns number to know later how many vertical lines to draw
            $columns_number = max(scalar(@$data_row), $columns_number);

            # Get the next set of row related settings
            # Row Height
            my $current_row_height = shift @$rows_height;

            # Row cell widths
            my $data_row_widths = shift @$row_col_widths;

            # Choose colors for this row. may still be 'undef' after this!
            if ($oddeven_default) {  # new method with consistent odd/even
                $bg_color = $row_is_odd ? $bg_color_odd : $bg_color_even;
                $fg_color = $row_is_odd ? $fg_color_odd : $fg_color_even;
                if ( !($first_row and $do_headers) ) {
                    # only toggle if not a header
                    $row_is_odd = ! $row_is_odd;
                }
            } else {  # old method with inconsistent odd/even
                $bg_color = $row_idx % 2 ? $bg_color_even : $bg_color_odd;
                $fg_color = $row_idx % 2 ? $fg_color_even : $fg_color_odd;
            }

            # remember, don't have cell_ stuff yet, just row items ($row_idx)!
            my $cur_x        = $xbase;
            my $leftovers    = undef;   # Reference to text that is returned from text_block()
            my $do_leftovers = 0;

            # Process every cell(column) from current row
            my @save_bg_color; # clear out for each row
            for ( my $col_idx = 0; $col_idx < scalar(@$data_row); $col_idx++ ) {
                $GLOBALS->[3] = $row_idx;
                $GLOBALS->[4] = $col_idx;
                # now have each cell[$row_idx][$col_idx]
                # FIX both max AND min need to be defined? what is this for?
               #next unless defined $col_props->[$col_idx]->{'max_w'} ||
               #            defined $col_props->[$col_idx]->{'min_w'};
                next if $colspanned{$row_idx.'_'.$col_idx};
                $leftovers->[$col_idx] = undef;

                # look for font information for this cell
                my ($cell_font, $cell_font_size, $cell_leading, $cell_underline,
                    $cell_pad_top, $cell_pad_right, $cell_pad_bot, 
                    $cell_pad_left, $cell_justify, $cell_fg_color, 
                    $cell_bg_color, $cell_def_text, $cell_min_w, $cell_max_w);
                # FIX Note that cell_def_text bypasses max_word_len split!

                if ($first_row and $do_headers) {
                    $is_header_row     = 1;
                    $GLOBALS->[3] = 0;
                    $cell_font         = $header_props->{'font'};
                    $cell_font_size    = $header_props->{'font_size'};
                    $cell_leading      = $header_props->{'leading'};
                    $cell_height       = $header_props->{'row_height'};
                    $cell_pad_top      = $header_props->{'padding_top'};
                    $cell_pad_right    = $header_props->{'padding_right'};
                    $cell_pad_bot      = $header_props->{'padding_bottom'};
                    $cell_pad_left     = $header_props->{'padding_left'};
                    $cell_max_word_len = $header_props->{'max_word_length'};
                    $cell_min_w        = $header_props->{'min_w'};
                    $cell_max_w        = $header_props->{'max_w'};
                    $cell_underline    = $header_props->{'underline'};
                    $cell_def_text     = $header_props->{'default_text'};
                    $cell_justify      = $header_props->{'justify'};
                    $cell_bg_color     = $header_props->{'bg_color'};
                    $cell_fg_color     = $header_props->{'fg_color'};
                    if (!defined $cell_font_size) { 
                        $cell_font_size = $fnt_size + 2;
                    }
                } else {
                    # not header row, so initialize to any row_props
                    $is_header_row     = 0;
                    $cell_font         = undef;
                    $cell_font_size    = undef;
                    $cell_leading      = undef;
                    $cell_height       = undef;
                    $cell_pad_top      = undef;
                    $cell_pad_right    = undef;
                    $cell_pad_bot      = undef;
                    $cell_pad_left     = undef;
                    $cell_max_word_len = undef;
                    $cell_min_w        = undef;
                    $cell_max_w        = undef;
                    $cell_underline    = undef;
                    $cell_def_text     = undef;
                    $cell_justify      = undef;
                    $cell_bg_color     = undef;
                    $cell_fg_color     = undef;
                }

                # Get the most specific value if none was already set from header_props
                $cell_font       = find_value($cell_font, 
                                              'font', '', $fnt_obj, $GLOBALS);
                # FIX need to set text size after this
                $cell_font_size  = find_value($cell_font_size, 
                                              'font_size', '', 0, $GLOBALS);
                if ($cell_font_size == 0) {
                    $cell_font_size  = $fnt_size;
                }
                $cell_leading    = find_value($cell_leading, 'leading', 
                                              'leading', -1, $GLOBALS);
                if ($cell_leading <= 0) {
                    $cell_leading = $cell_font_size * $leading_ratio;
                }
                $cell_height     = find_value($cell_height, 
                                              'row_height', '', 0, $GLOBALS);
                $cell_pad_top    = find_value($cell_pad_top, 'padding_top', 
                                              'padding', $padding_default, 
                                              $GLOBALS);
                $cell_pad_right  = find_value($cell_pad_right, 'padding_right', 
                                              'padding', $padding_default, 
                                              $GLOBALS);
                $cell_pad_bot    = find_value($cell_pad_bot, 'padding_bottom', 
                                              'padding', $padding_default, 
                                              $GLOBALS);
                $cell_pad_left   = find_value($cell_pad_left, 'padding_left', 
                                              'padding', $padding_default, 
                                              $GLOBALS);
                $cell_max_word_len = find_value($cell_max_word_len, 
                                                'max_word_len', '', 
                                                $max_word_len, $GLOBALS);
                $cell_min_w        = find_value($cell_min_w, 'min_w', 
                                                '', undef, $GLOBALS);
                $cell_max_w        = find_value($cell_max_w, 'max_w', 
                                                '', undef, $GLOBALS);
                $cell_underline  = find_value($cell_underline, 
                                              'underline', '', $underline, 
                                              $GLOBALS);
                $cell_def_text   = find_value($cell_def_text, 'default_text', 
                                              '', $default_text, $GLOBALS);
                $cell_justify    = find_value($cell_justify, 'justify', 
                                              'justify', 'left', $GLOBALS);
                # cell bg may still be undef after this, fg must be defined
                if ($is_header_row) {
                    $cell_bg_color   = find_value($cell_bg_color, 'bg_color', 
                                            '', $h_bg_color_default, 
                                            $GLOBALS);
                    $cell_fg_color   = find_value($cell_fg_color, 'fg_color',
                                            '', $h_fg_color_default, 
                                            $GLOBALS);
                } else {
                    # if odd/even defined, will be using that as default 
                    $cell_bg_color   = find_value($cell_bg_color, 'bg_color', 
                                            '', $bg_color, $GLOBALS);
                    $cell_fg_color   = find_value($cell_fg_color, 'fg_color',
                                            '', $fg_color || $fg_color_default, 
                                            $GLOBALS);
                }

               ## check if so much padding that baseline forced below cell 
               ## bottom, possibly resulting in infinite loop!
               #if ($cell_pad_top + $cell_pad_bot + $cell_leading > $cell_height) {
               #    my $reduce = $cell_pad_top + $cell_pad_bot - 
               #                  ($cell_height - $cell_leading);
               #    carp "Warning! Vertical padding reduced by $reduce to fit cell[$row_idx][$col_idx]";
               #    $cell_pad_top -= $reduce/2;
               #    $cell_pad_bot -= $reduce/2;
               #}

                # Define the font y base position for this line.
                $text_start_y = $cur_y - $cell_pad_top - $cell_font_size;

                # Initialize cell font object
                $txt->font( $cell_font, $cell_font_size );
                $txt->fillcolor($cell_fg_color);

                # make sure cell's text is never undef
                $data_row->[$col_idx] //= $cell_def_text;

                my $c_cell_props = $cell_props->[$row_idx][$col_idx];
                my $this_cell_width = $calc_column_widths->[$col_idx];

                # Handle colspan (issue #46)
                if ($c_cell_props && $c_cell_props->{'colspan'} && $c_cell_props->{'colspan'} > 1) {
                    my $colspan = $c_cell_props->{'colspan'};
                    for my $offset (1 .. $colspan - 1) {
                        $this_cell_width += $calc_column_widths->[$col_idx + $offset] 
                            if $calc_column_widths->[$col_idx + $offset];
                        $colspanned{$row_idx.'_'.($col_idx + $offset)} = 1;
                    }
                }
                $actual_column_widths[$row_idx][$col_idx] = $this_cell_width;

                my %text_options;
                if ($cell_underline) {
                    $text_options{'-underline'} = $cell_underline;
                    $text_options{'-strokecolor'} = $cell_fg_color;
                }
                # If the content is wider than the specified width, 
                # we need to add the text as a text block
                # Otherwise just use the $page->text() method
                if ( $data_row->[$col_idx] !~ m/(.\n.)/ and
                     $data_row_widths->[$col_idx] and
                     $data_row_widths->[$col_idx] <= $this_cell_width ) {
                    my $space = $cell_pad_left;
                    if      ($cell_justify eq 'right') {
                        $space = $this_cell_width - ($txt->advancewidth($data_row->[$col_idx]) + $cell_pad_right);
                    } elsif ($cell_justify eq 'center') {
                        $space = ($this_cell_width - $txt->advancewidth($data_row->[$col_idx])) / 2;
                    }
                    $txt->translate( $cur_x + $space, $text_start_y );
                    $txt->text( $data_row->[$col_idx], %text_options );
                } else {
                    my ($width_of_last_line, $ypos_of_last_line, 
                        $left_over_text) 
                      = $self->text_block(
                        $txt,
                        $data_row->[$col_idx],
                        'x'        => $cur_x + $cell_pad_left,
                        'y'        => $text_start_y,
                        'w'        => $this_cell_width - 
                                        $cell_pad_left - $cell_pad_right,
                        'h'        => $cur_y - $bot_margin - 
                                        $cell_pad_top - $cell_pad_bot,
                        'align'    => $cell_justify,
                        'leading'  => $cell_leading,
                        'text_opt' => \%text_options,
                    );
                    # Desi - Removed $leading because of 
                    #        fixed incorrect ypos bug in text_block
                    $current_row_height = max($current_row_height,
                               $cur_y - $ypos_of_last_line + $cell_pad_bot +
                               ($cell_leading - $cell_font_size)*2.5);
                    # 2.5 multiplier is a good-looking fudge factor to add a 
                    # little space between bottom of text and bottom of cell

                    if ( $left_over_text ) {
                        $leftovers->[$col_idx] = $left_over_text;
                        $do_leftovers = 1;
                    }
                }

                # Hook to pass coordinates back - http://www.perlmonks.org/?node_id=754777
                if (ref $arg{'cell_render_hook'} eq 'CODE') {
                   $arg{'cell_render_hook'}->(
                                            $page,
                                            $first_row,
                                            $row_idx,
                                            $col_idx,
                                            $cur_x,
                                            $cur_y-$current_row_height,
                                            $this_cell_width,
                                            $current_row_height
                                           );
                }

                $cur_x += $this_cell_width;
                $save_bg_color[$col_idx] = $cell_bg_color;
            } # done looping through columns for this row
            if ( $do_leftovers ) {
                # leftover text to output later as new-ish row?
                unshift @$data, $leftovers;
                unshift @$row_col_widths, $data_row_widths;
                unshift @$rows_height, $current_row_height;
            }

            # Draw cell bgcolor
            # This has to be done separately from the text loop
            #  because we do not know the final height of the cell until 
            #  all text has been drawn. Nevertheless, it ($gfx_bg) will
            #  still be rendered before text ($txt).
            $cur_x = $xbase;
            for (my $col_idx = 0; 
                 $col_idx < scalar(@$data_row); 
                 $col_idx++) {
                # restore cell_bg_color
                $cell_bg_color = $save_bg_color[$col_idx];

        # TBD rowspan!
                if (defined $cell_bg_color && 
                    !$colspanned{$row_idx.'_'.$col_idx}) {
                    $gfx_bg->rect( $cur_x, $cur_y-$current_row_height,  
                                   $actual_column_widths[$row_idx][$col_idx], $current_row_height);
                    $gfx_bg->fillcolor($cell_bg_color);
                    $gfx_bg->fill();
                }

                # draw left vertical border of this cell
                if ($gfx && $vert_borders && 
                    !$colspanned{$row_idx.'_'.$col_idx}) {
                    $gfx->move($cur_x, $cur_y-$current_row_height);
                    $gfx->vline( $cur_y );
                }

                $cur_x += $calc_column_widths->[$col_idx];
            } # End of for (my $col_idx....

# FIX does current row height cover multiple lines of text?
            $cur_y -= $current_row_height;
            if ($gfx && $horiz_borders) {
                $gfx->move(  $xbase , $cur_y );
                $gfx->hline( $xbase + $width );
            }

            $row_idx++ unless ( $do_leftovers );
            if ($do_leftovers) {
                # a row has been split across pages. undo bg toggle
                $row_is_odd = !$row_is_odd;
            }
            $first_row = 0;
        } # End of Row_Loop

        if ($gfx) {
            if ($vert_borders) {
                # Draw right table border
                $gfx->move(  $xbase + $width, $table_top_y);
                $gfx->vline( $cur_y );
            }

            # ACTUALLY draw all the lines
            $gfx->stroke();
        }
        $pg_cnt++;  # on a spillover page
    } # End of while (scalar(@{$data}))   next row, adding new page if necessary

    return ($page, --$pg_cnt, $cur_y);
} # end of table()

###################################################################
# calculate the column widths
#   min_w was longest word in column, max_w was total text width in col
#   apply per-column min_w and max_w to update widths
#   TBD: rules and borders? currently overlay cells
#   expand to fill to desired width
###################################################################

sub CalcColumnWidths {
    my $col_props   = shift;
    my $avail_width = shift; # specified table width
    my $min_width   = 0;     # calculate minimum width needed

    my $calc_widths ;        # each column's calculated width
    my $temp;

    # total requested minimum width (column properties)
    for (my $j = 0; $j < scalar( @$col_props); $j++) {
        $calc_widths->[$j] = $col_props->[$j]->{'min_w'} || 0;
        $min_width += $calc_widths->[$j];
    }

    # I think this is the optimal variant when a good view can be guaranteed
    if ($avail_width < $min_width) {
        carp "!!! Warning !!!\n Table width expanded from $avail_width to ",int($min_width)+1,".\n",
        $avail_width = int($min_width) + 1;
    }

    # Calculate how much can be added to every column to fit the available width

    # Allow columns to expand to max_w before applying extra space equally.
    my $is_last_iter;
    for (;;) {
        my $span = ($avail_width - $min_width) / scalar( @$col_props);
        last if $span <= 0;

        $min_width = 0;
        my $next_will_be_last_iter = 1;
        for (my $j = 0; $j < scalar(@$col_props); $j++) {
            my $new_w = $calc_widths->[$j] + $span;

            if (!$is_last_iter) { 
                $new_w = min($new_w, $col_props->[$j]->{'max_w'});
            }
            if ($calc_widths->[$j] != $new_w) {
                $calc_widths->[$j] = $new_w;
                $next_will_be_last_iter = 0;
            }
            $min_width += $new_w;
        }
        last if $is_last_iter;
        $is_last_iter = $next_will_be_last_iter;
    }

    return ($calc_widths,$avail_width);
} # End of CalcColumnWidths()

############################################################
# move deprecated settings names to current names, and delete old
# assume any leading '-' already removed
# warning if both deprecated and new name given (use new)
# release at T-6 months, consider issuing warning to remind update needed
# release at T-0 months, give warning on use of deprecated items
# release at T+12 months, remove deprecated names
############################################################

sub deprecated_settings {
    my ($data, $row_props, $col_props, $cell_props, $header_props, $argref) = @_;

    my %cur_names = (
        # old deprecated name        new current name
        #  (old_key)
        'start_y'               => 'y',
        'start_h'               => 'h',
        'background_color'      => 'bg_color',
        'background_color_odd'  => 'bg_color_odd',
        'background_color_even' => 'bg_color_even',
        'font_color'            => 'fg_color',
        'font_color_odd'        => 'fg_color_odd',
        'font_color_even'       => 'fg_color_even',
        'font_underline'        => 'underline',
       #'justify'               => 'align',  # different set of values allowed
        'lead'                  => 'leading',
# 'horizontal_borders' => 'h_rules',
# 'vertical_borders'   => 'v_rules',
    );

    # global arg
    foreach my $old_key (keys %cur_names) {
        if (defined $argref->{$old_key}) {
            # set deprecated name setting (need to transfer to new name).
            # did we also set new name setting?
            if (defined $argref->{$cur_names{$old_key}}) {
                carp "!! Warning !! both deprecated global name '$old_key' and current name '$cur_names{$old_key}' given, current name's value used.";
            } else {
                $argref->{$cur_names{$old_key}} = $argref->{$old_key};
                delete $argref->{$old_key};
                # eventually given warning to stop using $old_key
            }
        }
    }

    # row properties
    foreach my $old_key (keys %cur_names) {
        for (my $row = 0; $row < scalar(@$data); $row++) {
            if (defined $row_props->[$row]->{$old_key}) {
                # set deprecated name setting (need to transfer to new name).
                if (defined $row_props->[$row]->{$cur_names{$old_key}}) {
                    # did we also set new name setting?
                    carp "!! Warning !! both deprecated name '$old_key' and current name '$cur_names{$old_key}' given in row_props[$row], current name's value used.";
                } else {
                    # transfer deprecated setting to new
                    $row_props->[$row]->{$cur_names{$old_key}} = $row_props->[$row]->{$old_key};
                    delete $row_props->[$row]->{$old_key};
                    # eventually given warning to stop using $old_key
                }
            }
        }
    }

    # column properties
    foreach my $old_key (keys %cur_names) {
        for (my $col = 0; $col < scalar(@{$col_props}); $col++) {
            if (defined $col_props->[$col]->{$old_key}) {
                # set deprecated name setting (need to transfer to new name).
                if (defined $col_props->[$col]->{$cur_names{$old_key}}) {
                    # did we also set new name setting?
                    carp "!! Warning !! both deprecated name '$old_key' and current name '$cur_names{$old_key}' given in column_props[$col], current name's value used.";
                } else {
                    # transfer deprecated setting to new
                    $col_props->[$col]->{$cur_names{$old_key}} = $col_props->[$col]->{$old_key};
                    delete $col_props->[$col]->{$old_key};
                    # eventually given warning to stop using $old_key
                }
            }
        }
    }

    # cell properties
    foreach my $old_key (keys %cur_names) {
        for (my $row = 0; $row < scalar(@$data); $row++) {
            for ( my $col = 0; 
              $col < scalar(@{$data->[$row]}); 
              $col++ ) {
                if (defined $cell_props->[$row][$col]->{$old_key}) {
                    # set deprecated name setting (need to transfer to new name).
                    if (defined $cell_props->[$row][$col]->{$cur_names{$old_key}}) {
                        # did we also set new name setting?
                        carp "!! Warning !! both deprecated name '$old_key' and current name '$cur_names{$old_key}' given in cell_props[$row][$col], current name's value used.";
                    } else {
                        # transfer deprecated setting to new
                        $cell_props->[$row][$col]->{$cur_names{$old_key}} = $cell_props->[$row][$col]->{$old_key};
                        delete $cell_props->[$row][$col]->{$old_key};
                        # eventually given warning to stop using $old_key
                    }
                }
            }
        }
    }

    # header properties
    if ($header_props) {
        foreach my $old_key (keys %cur_names) {
            if (defined $header_props->{$old_key}) {
                # set deprecated name setting (need to transfer to new name).
                # did we also set new name setting?
                if (defined $header_props->{$cur_names{$old_key}}) {
                    carp "!! Warning !! both deprecated header name '$old_key' and current name '$cur_names{$old_key}' given, current name's value used.";
                } else {
                    $header_props->{$cur_names{$old_key}} = $header_props->{$old_key};
                    delete $header_props->{$old_key};
                    # eventually given warning to stop using $old_key
                }
            }
        }
    }

    return;
}

############################################################
# validate/fix up settings and parameters as much as possible     TBD per #12
############################################################

sub check_settings {
    my (%arg) = @_;

    # TBD $arg{} values, some col, row, cell, header?
    # x, y >= 0; w, h >= 0; x+w < page width; y+h < page height
    # next_h (if def) > 0, next_y (if def) >= 0; next_y+next_h < page height
    # line widths >= 0, row_height > 0
    return;
}

############################################################
# find a value that might be set in a default or in a global
# or column/row/cell specific parameter. fixed order of search
# is cell/header properties, column properties, row properties,
# fallback sequences (e.g., padding_left inherits from padding),
# global default
############################################################

sub find_value {
    my ($cell_val, $name, $arg_name, $default, $GLOBALS) = @_;
    # $arg_name can be '' (will be skipped)

    my ($cell_props, $col_props, $row_props, $row_idx, $col_idx, $argref) = 
        @$GLOBALS;
    # $row_idx should be 0 for a header entry
    my %arg = %$argref;
    # $default should never be undefined, except for specific cases!
    if (!defined $default &&
        ($name ne 'underline' && $name ne 'bg_color' &&
         $name ne 'min_w' && $name ne 'max_w') ) {
        carp "Error! find_value() default value undefined for '$name'\n";
    }

    # upon entry, $cell_val is usually either undefined (data row) or 
    # header property setting (in which case, already set and we're done here)
    if (!defined $cell_val) {
        $cell_val ||= $cell_props->[$row_idx][$col_idx]->{$name}
                  ||  $col_props->[$col_idx]->{$name}
                  ||  $row_props->[$row_idx]->{$name};

        $cell_val ||= $arg{$name};
    }

    # fallbacks such as padding_left inherit from padding
    if (!defined $cell_val && $arg_name ne '') {
        $cell_val ||= $cell_props->[$row_idx][$col_idx]->{$arg_name}
                  ||  $col_props->[$col_idx]->{$arg_name}
                  ||  $row_props->[$row_idx]->{$arg_name};

        $cell_val ||= $arg{$arg_name};
    }

    # final court of appeal is the global default
    if (!defined $cell_val) {
        $cell_val ||= $default;
    }

    return $cell_val;
}

############################################################
# text_block - utility method to build multi-paragraph blocks of text
#
# Parameters:
#   $text_object  the TEXT object used to output to the PDF
#   $text         the text to be formatted
#   %arg          settings to control the formatting and
#                  output.
#       mandatory: x, y, w, h (block position and dimensions)
############################################################

sub text_block {
    my $self        = shift;
    my $text_object = shift;
    my $text        = shift;    # The text to be displayed
    my %arg         = @_;       # Additional Arguments

    my  ( $align, $xpos, $ypos, $xbase, $ybase, $line_width, $wordspace, $endw , $width, $height) =
        ( undef , undef, undef, undef , undef , undef      , undef     , undef , undef , undef  );
    my @line        = ();       # Temp data array with words on one line
    my %width       = ();       # The width of every unique word in the given text
    my %text_options = %{ $arg{'text_opt'} };

    # Try to provide backward compatibility. "-" starting key name is optional
    foreach my $key (keys %arg) {
        my $newkey = $key;
        if ($newkey =~ s#^-##) {
            $arg{$newkey} = $arg{$key};
            delete $arg{$key};
        }
    }
    #####

    #---
    # Let's check mandatory parameters with no default values
    #---
    $xbase  = $arg{'x'} || -1;
    $ybase  = $arg{'y'} || -1;
    $width  = $arg{'w'} || -1;
    $height = $arg{'h'} || -1;
    unless ( $xbase  > 0 ) {
        carp "Error: Left Edge of Block is NOT defined!\n";
        return;
    }
    unless ( $ybase  > 0 ) {
        carp "Error: Base Line of Block is NOT defined!\n";
        return;
    }
    unless ( $width  > 0 ) {
        carp "Error: Width of Block is NOT defined!\n";
        return;
    }
    unless ( $height > 0 ) {
        carp "Error: Height of Block is NOT defined!\n";
        return;
    }

    # set some defaults !!!!
    $arg{'leading' } ||= -1;                # leading TBD
   #$arg{'cell_render_hook' } ||= undef; 
   #$arg{'fg_color'} ||= $fg_color_default;      # default global text color

    # Check if any text to display
    unless ( defined( $text) and length($text) > 0 ) {
        carp "Warning: No input text found. Trying to add dummy '-' and not to break everything.\n";
        $text = $empty_cell_text;
    }

    # Strip any <CR> and Split the text into paragraphs
    $text =~ s/\r//g;
    my @paragraphs  = split(/\n/, $text);

    # Width between lines (leading) in points
    my $font_size = $arg{'font_size'} || $font_size_default;
    my $line_space = defined $arg{'leading'} && $arg{'leading'} > 0 ? $arg{'leading'} : undef;
    $line_space ||= $font_size * $leading_ratio;
    # leading must be at least font size
    $line_space = $font_size * $leading_ratio if $font_size > $line_space;

    # Calculate width of all words
    my $space_width = $text_object->advancewidth("\x20");
    my @words = split(/\s+/, $text);
    foreach (@words) {
        next if exists $width{$_};
        $width{$_} = $text_object->advancewidth($_);
    }

    my @paragraph = split(' ', shift(@paragraphs));
    my $first_line = 1;
    my $first_paragraph = 1;

    # Little Init
    $xpos = $xbase;
    $ypos = $ybase;
    $ypos = $ybase + $line_space;
    my $bottom_border = $ypos - $height;

    # While we can add another line
    while ( $ypos >= $bottom_border + $line_space ) {
        # Is there any text to render ?
        unless (@paragraph) {
            # Finish if nothing left
            last unless scalar @paragraphs;
            # Else take one line from the text
            @paragraph = split(' ', shift( @paragraphs ) );

            # extra space between paragraphs? TBD s/b only if a prev para
            $ypos -= $arg{'parspace'} if $arg{'parspace'};
            last unless $ypos >= $bottom_border;
        }
        $ypos -= $line_space;
        $xpos = $xbase;

        # While there's room on the line, add another word
        @line = ();
        $line_width = 0;
        # FIX what exactly is hang supposed to do, interaction with
        # indent, flindent, fpindent
        if      ( $first_line && exists $arg{'hang'} ) {
            my $hang_width = $text_object->advancewidth($arg{'hang'});

            $text_object->translate( $xpos, $ypos );
            $text_object->text( $arg{'hang'} );

            $xpos         += $hang_width;
            $line_width   += $hang_width;
            $arg{'indent'} += $hang_width if $first_paragraph;
        } elsif ( $first_line &&
                  exists $arg{'flindent'} &&
                  $arg{'flindent'} > 0 ) {
            $xpos += $arg{'flindent'};
            $line_width += $arg{'flindent'};
        } elsif ( $first_paragraph &&
                  exists $arg{'fpindent'} &&
                  $arg{'fpindent'} > 0 ) {
            $xpos += $arg{'fpindent'};
            $line_width += $arg{'fpindent'};
        } elsif ( exists $arg{'indent'} &&
                  $arg{'indent'} > 0 ) {
            $xpos += $arg{'indent'};
            $line_width += $arg{'indent'};
        }

        # Let's take from paragraph as many words as we can put
        # into $width - $indent
        while ( @paragraph and 
                $text_object->advancewidth( join("\x20", @line)."\x20" . $paragraph[0]) +
                    $line_width < $width ) {
            push(@line, shift(@paragraph));
        }
        $line_width += $text_object->advancewidth(join('', @line));

        # calculate the space width
        $align = $arg{'align'} || 'left';
        if ( $align eq 'fulljustify' or
            ($align eq 'justify' and @paragraph)) {
            @line = split(//,$line[0]) if scalar(@line) == 1;
            if (scalar(@line) > 1) {
                $wordspace = ($width - $line_width) / (scalar(@line) - 1);
            } else {
                $wordspace = 0; # effective left-aligned for single word
            }
            $align = 'justify';
        } else {
            $align = 'left' if $align eq 'justify';
            $wordspace = $space_width;
        }

        $line_width += $wordspace * (scalar(@line) - 1);

        if ( $align eq 'justify') {
            foreach my $word (@line) {
                $text_object->translate( $xpos, $ypos );
                $text_object->text( $word );
                $xpos += ($width{$word} + $wordspace) if (@line);
            }
            $endw = $width;
        } else {
            # calculate the left hand position of the line
            if      ( $align eq 'right' ) {
                $xpos += $width - $line_width;
            } elsif ( $align eq 'center' ) {
                $xpos += ( $width - $line_width ) / 2;
            }

            # render the line
            $text_object->translate( $xpos, $ypos );
            # FIX %text_options in text() call
            $endw = $text_object->text( join("\x20", @line), %text_options);
        }
        $first_line = 0;
    } # End of while
    unshift(@paragraphs, join(' ',@paragraph)) if scalar(@paragraph);

    return ($endw, $ypos, join("\n", @paragraphs))
}  # End of text_block()

1;

__END__

=pod

=head1 NAME

PDF::Table - A utility class for building table layouts in a PDF::Builder 
(or PDF::API2) object.

=head1 SYNOPSIS

Rather than cluttering up the following documentation with B<(or PDF::API2)>
additions, wherever it refers to C<PDF::Builder>, understand that you can 
substitute C<PDF::API2> to use that product instead.

 use PDF::Builder;
 use PDF::Table;

 my $pdftable = new PDF::Table;
 my $pdf = new PDF::Builder(-file => "table_of_lorem.pdf");
 my $page = $pdf->page();

 # some data to lay out
 my $some_data =[
    ["1 Lorem ipsum dolor",
    "Donec odio neque, faucibus vel",
    "consequat quis, tincidunt vel, felis."],
    ["Nulla euismod sem eget neque.",
    "Donec odio neque",
    "Sed eu velit."],
    # ... and so on
 ];

 $left_edge_of_table = 50;
 # build the table layout
 $pdftable->table(
     # required parameters
     $pdf,
     $page,
     $some_data,
     'x' => $left_edge_of_table,
     'w' => 495,
     'y' => 500,
     'h' => 300,
     # some optional parameters
     'next_y'          => 750,
     'next_h'          => 500,
     'padding'         => 5,
     'padding_right'   => 10,
     'bg_color_odd'    => "gray",
     'bg_color_even'   => "lightblue", # cell bg color for even rows
     'max_word_length' => 50, # 50 between forced splits
  );

 # do other stuff with $pdf
 $pdf->save();
...

=head2 EXAMPLE

For a complete working example or initial script look into distribution's 
'examples' folder.

=head1 DESCRIPTION

This class is a utility for use with the PDF::Builder (or PDF::API2) module 
from CPAN.
It can be used to display text data in a table layout within a PDF.
The text data must be in a 2D array (such as returned by a DBI statement 
handle C<fetchall_arrayref()> call).
PDF::Table will automatically add as many new pages as necessary to display 
all of the data.
Various layout properties, such as font, font size, cell padding, and 
background color can be specified for each column and/or for even/odd rows.
Also a (non)repeated header row with different layout properties can be 
specified.

See the L</METHODS> section for complete documentation of every parameter.

=head1 COMPATIBILITY

Starting with version 1.000, several behaviors have changed (for the better, I
believe). Nevertheless, there may be some users who prefer the old behaviors.
To keep everybody happy, it is possible to easily revert to the old behaviors.
Near the top of Table.pm, look for a section labeled C<COMPATIBILITY WITH OLDER 
VERSIONS>. You can change settings here to match old behaviors:

=over

=item repeating headers

The old default for the C<repeat> setting for a header was '0' (do not repeat
after a table has been split across a page). I believe that most users will
want to automatically repeat a header row at the start of each table fragment, 
but you can change this behavior if you wish. Change C<$repeat_default> from 1
to 0 to get the old behavior.

=item which rows are 'odd' (and which are 'even')

PDF::Table decided which rows were odd/even (background and foreground colors,
etc) in an inconsistent manner, especially if a header was used (whether 
repeated or not). Now, the first data row (excluding headers) is "odd", and
all rows after that alternate "even", "odd", etc., even across page breaks. If 
you want the old behavior, it can be requested. Change C<$oddeven_default> from
1 to 0 to get the old behavior.

=item default cell padding

The old default for padding around the contents of a cell was 0. It is now
2pt. Change C<$padding_default> from 2 to 0 to get the old behavior.

=item behavior of borders

The old behavior was calling both the frame around the table I<and> the
cell-divider rules as "borders", and using the same settings for both. This has
been changed to separate the two classes, with "border" referring to the outside
framework, and "rules" referring to the dividers. Change C<$borders_as_rules> 
from 0 to 1 to get the old behavior. Note that explicit definition of "rules"
will still override the "border" setting for interior dividers.

=back

=head2 Maintaining compatibility

Near the top of file Table.pm, look for C<my $compat_mode = 1;>. For now,
PDF::Table is shipped with a flag of C<1> to ensure maximum compatibility with
older uses of the library. I<Eventually> this mode will be changed to C<0>,
making use of new capabilities, but breaking some old code. If you are using 
this library for B<new> code, you may wish to change the mode to C<0> in order
to use the new capabilities.

=head2 Run-time changes

If you do not wish to change the PDF::Table code section to permanently change
old-versus-new behavior, you can use the I<compatibility> flag in the settings
to temporarily change the variables listed above.

    compatibility => [ 0, 0, 0, 1 ]

will restore all behaviors to the old style, while 

    compatibility => [ 1, 0, 2, 0 ]

will change only the designation of "odd/even" rows to the old behavior.

=head1 METHODS

=head2 new()

    my $pdf_table = new PDF::Table;
       or
    my $pdf_table = PDF::Table->new();

=over

=item Description

Creates a new instance of the class.

=item Parameters

There are no required parameters. You may pass $pdf, $page, $data, and
%options; or can defer this until the table() method invocation (the usual
technique).

=item Returns

Reference to the new instance

=back

=head2 table()

    my ($final_page, $number_of_pages, $final_y) = table($pdf, $page, $data, %settings)

=over

=item Description

Generates a multi-row, multi-column table into an existing PDF document, based 
on provided data set and settings.

=item Parameters

    $pdf      - a PDF::Builder instance representing the document being created
    $page     - a PDF::Builder::Page instance representing the current page of 
                the document
    $data     - an ARRAY reference to a 2D data structure that will be used 
                to build the table
    %settings - HASH with geometry and formatting parameters

For full C<%settings> description see section L</Table settings> below.

This method will add more pages to the PDF instance as required, based on the 
formatting options and the amount of data.

=item Returns

The return value is a 3 item list where

    $final_page - A PDF::Builder::Page instance that the table ends on
    $number_of_pages - The count of pages that the table spans
    $final_y - The Y coordinate of the table bottom, so that additional 
               content can be added on the same page ($final_page)

=item Example

    my $pdf  = new PDF::Builder;
    my $page = $pdf->page();
    my $data = [
        ['foo1','bar1','baz1'],
        ['foo2','bar2','baz2']
    ];
    my %settings = (
        'x' => 10,
        'w' => 570,
        'y' => 220,
        'h' => 180,
    );

    my ($final_page, $number_of_pages, $final_y) = 
        $pdftable->table( $pdf, $page, $data, %options );

=back

=head3 Table settings

Unless otherwise specified, all dimensional and geometry units used are 
measured in I<points>. Line counts are not used anywhere.

"Odd" rows start with the first data (non-header) row. Think of this first
row as number one (an I<odd> number). Even rows alternate with odd rows.
The odd/even flag is B<not> reset when a table is split across pages. If a
table fragment ends on an odd row, the next fragment (on the next page) will
start with an even row. If a I<row> is split across pages, it will resume with
the same odd/even setting as on the previous page. If you desire to have the
old (previous) odd/even behavior, see L</COMPATIBILITY>.

The name (key) of any table setting hash element may be given with or
without a leading dash (hyphen). A leading dash is allowed for compatibility
with older versions of PDF::Table, but it is recommended that the dash be
omitted in new code.

B<Note:> if you use a deprecated setting name, or a setting beginning with a 
hyphen '-', PDF::Table will update the settings list with the preferred name.
It does this by inserting the item using the preferred, non-hyphen name, and 
then deletes the deprecated one. Due to peculiarities in the way Perl copies
arrays, hashes, and references; it is possible that your input settings hash
may end up being modified! This normally will not be a cause for concern, but
you should be aware of this behavior in case you wish to reuse all or part of
a PDF::Table settings list (hash) for other purposes -- it may have been 
slightly modified.

Note that any "Color specifier" is not limited to a name (e.g., 'black') or
a 6-digit hex specification (e.g., '#3366CC'). See the PDF::Builder 
writeup on specifying colors for CMYK, L*a*b, HSV, and other methods.

=head4 Mandatory

There are some mandatory parameters for setting table geometry and position 
on the first (initial) or only page of the table. It is up to you to tell
PDF::Table where to start (upper left corner) the table, and its width and
maximum height on this page.

=over

=item B<x> - X coordinate of upper left corner of the table. 

The left edge of the sheet (media) is 0. 
B<Note> that this C<X> will be used for any spillover of the table to 
additional page(s), so you cannot have spillover (continuation) rows 
starting at a different C<X>.

B<Value:> can be any whole number satisfying C<0 =< X < PageWidth>

B<Default:> No default value

    'x' => 10,

=item B<y> - Y coordinate of upper left corner of the table on the 
initial page.

B<Value:> can be any whole number satisfying C<0 < y < PageHeight> 
(depending on space availability when embedding a table)

B<Default:> No default value

    'y' => 327,

B<Deprecated name:> I<start_y> (will go away in the future!)

=item B<w> - width of the table starting from C<x>.

B<Note> that this C<width> will be used for any spillover of the table to 
additional page(s), so you cannot have spillover (continuation) rows with a 
different C<width>.

B<Value:> can be any whole number satisfying C<0 < w < PageWidth - x>

B<Default:> No default value

    'w'  => 570,

B<NOTE:> If PDF::Table finds that the table width needs to be increased to
accommodate the requested text and formatting, it will output a warning. This
could lead to undesired results. Possible solutions to keep the table from
being widened include:

    1) Increase table width (w)
    2) Decrease font size
    3) Choose a narrower font
    4) Decrease "max_word_length" parameter, so long words are split into
        shorter chunks
    5) Rotate media to landscape (if it is portrait)
    6) Use a larger (wider) media size

=item B<h> - Height of the table on the initial (current) page.

Think of this as the I<maximum height> (Y dimension) of the start of the
table on this page. This would be the current C<Y> location less any bottom
margin. Normally you would let as much as possible fit on the page,
but it's possible that you might want to split the table at an earlier point,
to put more on the next (spill) page.

B<Value:> can be any whole number satisfying C<0 < h < PageHeight - 
Current Y position>

B<Default:> No default value

    'h' => 250,

B<Deprecated name:> I<start_h> (will go away in the future!)

=back

=head4 Optional

These are settings which are not absolutely necessary, although their use may
result in a much more pleasing appearance for the table. They all have a
"reasonable" default (or inheritance from another setting).

=over

=item B<next_h> - Height of the table on any additional page.

Think of this as the I<maximum height> (Y dimension) of any overflow 
(spill) table portions on following pages.
I<It is highly recommended that you
explicitly specify this setting as the full (body content) height of a page,
rather than having PDF::Table try to figure out a good value.>

B<Value:> can be any whole number satisfying C<0 < next_h < PageHeight>

B<Default:> Value of parameter B<'h'>

    'next_h'  => 700,

=item B<next_y> - Y coordinate of upper left corner of the table at any 
additional page.

Think of this as the starting C<Y> position of any overflow 
(spill) table portions on following pages.
I<It is highly recommended that you
explicitly specify this setting to be at the top of the body content of a page,
rather than having PDF::Table try to figure out a good value.>

B<Value:> can be any whole number satisfying C<0 < next_y < PageHeight>

B<Default:> Value of parameter B<'y'>

    'next_y'  => 750,

=item B<default_text> - A string to use if no content (text) is defined for
a cell.

B<Value:> any string (can be empty)

B<Default:> '-'

=item B<max_word_length> - Breaks long words (like serial numbers, hashes, 
etc.) by adding a space after every Nth symbol, unless a space (x20) is found 
already in the text. 
B<Note> that this does I<not> add a hyphen (dash)!
It merely ensures that there will be no runs of non-space characters longer
than I<N> characters, reducing the chance of overflowing a cell.

B<Value:> can be any whole positive number

B<Default:> C<20>

    'max_word_length' => 25,    # Will add a space after every 25 symbols
                                # unless there is a natural break (space)

=item B<padding> - Padding applied to every cell

=item B<padding_top>    - top cell padding, overrides 'padding'

=item B<padding_right>  - right cell padding, overrides 'padding'

=item B<padding_left>   - left cell padding, overrides 'padding'

=item B<padding_bottom> - bottom padding, overrides 'padding'

B<Value:> can be any non-negative number (E<ge> 0)

B<Default padding:> C<2>.  ($padding_default)

See L</COMPATIBILITY> for returning to the old value of C<0>.

B<Default padding_*> C<$padding>

    'padding'        => 5,     # all sides cell padding
    'padding_top'    => 8,     # top cell padding, overrides 'padding'
    'padding_right'  => 6,     # right cell padding, overrides 'padding'
    'padding_left'   => 2,     # left cell padding, overrides 'padding'
    'padding_bottom' => undef, # bottom padding will be 5, as it will fall
                               # back to 'padding' value

=item B<border> - Width of table border lines.

=item B<horizontal_borders> - Width of horizontal border lines. Overrides 
'border' value.

=item B<vertical_borders> -  Width of vertical border lines. Overrides 
'border' value.

B<Value:> can be any whole positive number. When set to 0, it will disable 
border lines.

B<Default:> C<1>  ($border_w_default)

    'border'             => 3,     # border width is 3
    'horizontal_borders' => 1,     # horizontal borders will be 1 overriding 3
    'vertical_borders'   => undef, # vertical borders will be 3, as it will 
                                   # fall back to 'border'

=item B<border_color> -  Border color for all borders.

B<Value:> Color specifier as 'name' or '#rrggbb'

B<Default:> C<'black'>

    'border_color' => 'red',

=item B<font> - instance of PDF::Builder::Resource::Font defining the font to 
be used in the table.

B<Value:> can be any PDF::Builder::Resource::* type of font

B<Default:> C<'Times'> with I<latin1> encoding

    'font' => $pdf->corefont("Helvetica", -encoding => "latin1"),

B<CAUTION:> Only TrueType and OpenType fonts (ttfont call) can make use of
multibyte encodings such as 'utf8'. Errors will result if you attempt to use
'utf8', etc. with corefont, psfont, etc. font types! For these, you I<must>
only specify a single-byte encoding.

=item B<font_size> - Size of the font that will be used throughout
the table, unless overridden.

B<Value:> can be any positive number

B<Default:> C<12>  ($font_size_default)

    'font_size' => 16,

=item B<fg_color> - Font color for all rows.

=item B<fg_color_odd> - Font color for odd rows (override C<fg_color>).

=item B<fg_color_even> - Font color for even rows (override C<fg_color>).

=item B<bg_color> - Background color for all rows.

=item B<bg_color_odd> - Background color for odd rows (override C<bg_color>).

=item B<bg_color_even> - Background color for even rows (override C<bg_color>).

B<Value:> Color specifier as 'name' or '#rrggbb' (or other suitable color 
specification format)

B<Default:> C<'black'> text on C<'white'> background

    'fg_color'      => '#333333',
    'fg_color_odd'  => 'purple',
    'fg_color_even' => '#00FF00',
    'bg_color_odd'  => 'gray',
    'bg_color_even' => 'lightblue',

B<Deprecated names:> I<font_color, font_color_odd, font_color_even, 
background_color, background_color_odd, 
background_color_even> (all will go away in the future!)

=item B<underline> - Underline specifications for text in the table.

B<Value:> 'auto', integer of distance (below baseline), or arrayref of 
distance & thickness (more than one pair will provide multiple underlines). 
Negative distance gives strike-through. C<[]> ('none' also works for 
PDF::Builder) gives no underline.

Note that it is unwise to underline all content in the table! It should be
used selectively to I<emphasize> important text, such as header content.

B<Default:> none

B<Deprecated name:> I<font_underline> (will go away in the future!)

=item B<row_height> - Desired row height.

This setting will be honored only if 
C<row_height E<gt> font_size + padding_top + padding_bottom> (i.e., it is
taller than the calculated minimum value).

B<Value:> can be any whole positive number

B<Default:> C<font_size + padding_top + padding_bottom>

    'row_height' => 24,

=item B<new_page_func> - CODE reference to a function that returns a 
PDF::Builder::Page instance.

If used, the parameter 'C<new_page_func>' must be a function reference which, 
when executed, will create a new page and will return the object to the module.
For example, you can use it to put Page Title, Page Frame, Page Numbers and 
other content that you need.
Also if you need a different paper size and orientation than the default 
US-Letter, e.g., B2-Landscape, you can use this function ref to set it up for 
you. For more info about creating pages, refer to PDF::Builder PAGE METHODS 
Section.
Don't forget that your function must return a page object created with the
PDF::Builder page() method. C<$code_ref> can be something like C<\&new_page>.

    'new_page_func'  => $code_ref,

The `$code_ref` may be an inline sub definition (as show below), or a regular
named `sub` (e.g., 'new_page()') referenced as `\&new_page`. The latter may be
cleaner than inlining if the routine is quite long.

An example of reusing a saved PDF page as a I<template>:

    my $pdf      = PDF::API2->new();
    my $template = PDF::API2->open('pdf/template.pdf');
    my $new_page_func = sub { return $pdf->import_page($template, 1); }

    table(
        ...
        new_page_func => $new_page_func,
        ...

This will call a function to grab a copy of a template PDF's page 1 and
insert it as the new last page of the PDF, as the starting point for the next
I<overflow> (continuation) page of the table, if needed. Note that the
`$template->openpage(1)` call is B<unsuitable> for this purpose, as it does
not insert the page into the current PDF.

You can also create a blank page and prefill it with desired content:

    my $pdf      = PDF::API2->new();
    my $new_page_func = sub { 
        my $page = $pdf->page(); # so far, no difference from default behavior
        $page->mediaBox(...);  # set page size/orientation, etc.
        my $text = $page->text();
        # set font, placement, etc.
        $text->text(...);  # write header, footer, etc.
        ...
        return $page;
    }

    table(
        ...
        new_page_func => $new_page_func,
        ...

If `new_page_func` is not defined, PDF::Table will simply call `$pdf->page()`
to generate a new, blank, next page.

Note that this function is B<not> called for the first page of a table. That 
one uses the current C<$page> parameter passed to the C<table()> call. It is
only called when needed for overflow (C<next_y> and C<next_h>) pages, where
it replaces the C<$page> parameter with a new page framework. You may 
want to consider using the same function to create your other (non-table) 
pages, assuming you want the same format (PDF content) across all pages of the
table.

=item B<header_props> - HASH reference to specific settings for the Header row 
of the table. See section L</Header Row Properties> below.

    'header_props' => $hdr_props,

=item B<column_props> - HASH reference to specific settings for each column of 
the table. See section L</Column Properties> below.

    'column_props' => $col_props,

=item B<cell_props> - HASH reference to specific settings for each column of 
the table. See section L</Cell Properties> below.

    'cell_props' => $cel_props,

=item B<cell_render_hook> - CODE reference to a function called with the 
current cell coordinates. If used, the parameter C<cell_render_hook> must be a 
function reference. It is most useful for creating a URL link inside of a cell. 
The following example adds a link in the first column of each non-header row:

    'cell_render_hook'  => sub {
        my ($page, $first_row, $row, $col, $x, $y, $w, $h) = @_;

        # Do nothing except for first column (and not a header row)
        return unless ($col == 0);
        return if ($first_row);

        # Create link
        my $value = $list_of_vals[$row-1];
        my $url = "https://${hostname}/app/${value}";

        my $annot = $page->annotation();
        $annot->url( $url, -rect => [$x, $y, $x+$w, $y+$h] );
    },

=back

=head4 Header Row Properties

If the 'header_props' parameter is used, it should be a hashref. Passing an 
empty HASH will trigger a header row initialized with Default values.
There is no 'data' variable for the content, because the module asumes that the
first table row will become the header row. It will copy this row and put it on 
every new page if the 'repeat' parameter is set.

=over

=item B<font> - instance of PDF::Builder::Resource::Font defining the font to be
used in the header row.

B<Value:> can be any PDF::Builder::Resource::* type of font

B<Default:> C<'font'> of the table. See table parameter 'font' for more details.

B<CAUTION:> Only TrueType and OpenType fonts (ttfont call) can make use of
multibyte encodings such as 'utf8'. Errors will result if you attempt to use
'utf8', etc. with corefont, psfont, etc. font types! For these, you I<must>
only specify a single-byte encoding.

=item B<font_size> - Font size of the header row.

B<Value:> can be any positive number

B<Default:> C<'font_size'> of the table + 2 points

=item B<fg_color> - Font color of the header row.

B<Value:> Color specifier as 'name' or '#rrggbb'

B<Default:> C<#000066> ($h_fg_color_default)

B<Deprecated name:> I<font_color> (will go away in the future!)

=item B<bg_color> - Background color of the header row.

B<Value:> Color specifier as 'name' or '#rrggbb'

B<Default:> C<#FFFFAA> ($h_bg_color_default)

B<Deprecated name:> I<background_color> (will go away in the future!)

=item B<underline> - Underline specifications of the header row text.

B<Value:> 'auto', integer of distance, or arrayref of distance & thickness 
(more than one pair will provide multiple underlines). Negative distance gives 
strike-through. C<[]> or 'none' gives no underline.

B<Default:> none

B<Deprecated name:> I<font_underline> (will go away in the future!)

=item B<repeat> - Flag showing if header row should be repeated on every new 
page.

B<Value:> 0,1   1-Yes/True, 0-No/False

B<Default:> C<1> ($repeat_default)

See L</COMPATIBILITY> if you wish to change it back to the old behavior 
of C<0>.

=item B<justify> - Alignment of text in the header row.

B<Value:> One of 'left', 'right', 'center'

B<Default:> Same as column alignment (or C<'left'> if undefined)

    my $hdr_props = {
        'font'       => $pdf->corefont("Helvetica", -encoding => "latin1"),
        'font_size'  => 18,
        'fg_color'   => '#004444',
        'bg_color'   => 'yellow',
        'repeat'     => 1,
        'justify'    => 'center',
    };

=back

=head4 Column Properties

If the 'column_props' parameter is used, it should be an arrayref of hashrefs,
with one hashref for each column of the table. The columns are counted from 
left to right, so the hash reference at C<$col_props[0]> will hold properties 
for the first column (from left to right).
If you DO NOT want to give properties for a column, but to give for another, 
just insert an empty hash reference into the array for the column that you want 
to skip. This will cause the counting to proceed as expected and the properties 
to be applied at the right columns.

Each hashref can contain any of the keys shown below:

=over

=item B<min_w> - Minimum width of this column. 

Auto calculation will try its 
best to honor this parameter, but applying it is NOT guaranteed.

B<Value:> can be any whole number satisfying C<0 < min_w < w>

B<Default:> Auto calculated

=item B<max_w> - Maximum width of this column. 

Auto calculation will try its 
best to honor this parameter, but applying it is NOT guaranteed.

B<Value:> can be any whole number satisfying C<0 < max_w < w>

B<Default:> Auto calculated

=item B<font> - instance of PDF::Builder::Resource::Font defining the font to be
used in this column.

B<Value:> can be any PDF::Builder::Resource::* type of font

B<Default:> C<font> of the table. See table parameter 'font' for more details.

=item B<font_size> - Font size of this column.

B<Value:> can be any positive number

B<Default:> C<font_size> of the table.

=item B<fg_color> - Font color of this column.

B<Value:> Color specifier as 'name' or '#rrggbb'

B<Default:> C<fg_color> of the table.

B<Deprecated name:> I<font_color> (will go away in the future!)

=item B<bg_color> - Background color of this column.

B<Value:> Color specifier as 'name' or '#rrggbb'

B<Default:> undef

B<Deprecated name:> I<background_color> (will go away in the future!)

=item B<underline> - Underline of this cell's text.

B<Value:> 'auto', integer of distance, or arrayref of distance & thickness 
(more than one pair will provide multiple underlines). Negative distance gives 
strike-through. C<[]> or 'none' gives no underline.

B<Default:> none

B<Deprecated name:> I<font_underline> (will go away in the future!)

=item B<justify> - Alignment of text in this column

B<Value:> One of 'left', 'right', 'center'

B<Default:> C<'left'>

Example:

    my $col_props = [
        # This is an empty hash to indicate default properties for first col.
        {},
        # the next hash will hold the properties for the second column from 
        # left to right.
        {
            'min_w'     => 100,       # Minimum column width of 100
            'max_w'     => 150,       # Maximum column width of 150
            'justify'   => 'right',   # Right text alignment
            'font'      => $pdf->corefont("Helvetica", 
                                          -encoding => "latin1"),
            'font_size' => 10,
            'fg_color'  => 'blue',
            'bg_color'  => '#FFFF00',
        },
        # etc.
    ];

=back

NOTE: If 'min_w' and/or 'max_w' parameter is used in 'col_props', keep in mind 
that it may be overridden by the calculated minimum/maximum cell width so that 
the table can be created.
When this happens, a warning will be issued with some suggestions on what can 
be done.
In cases of a conflict between column formatting and odd/even row formatting, 
'col_props' will override odd/even.

=head4 Cell Properties

If the 'cell_props' parameter is used, it should be an arrayref with arrays of 
hashrefs (of the same dimension as the data array) with one hashref for each 
cell of the table.

Each hashref can contain any of the keys shown below:

=over

=item B<font> - instance of PDF::Builder::Resource::Font defining the font to be 
used in this cell.

B<Value:> can be any PDF::Builder::Resource::* type of font

B<Default:> C<'font'> of the table. See table parameter 'font' for more details.

=item B<font_size> - Font size of this cell.

B<Value:> can be any positive number

B<Default:> C<font_size> of the table.

=item B<fg_color> - Font color of this cell.

B<Value:> Color specifier as 'name' or '#rrggbb'

B<Default:> C<fg_color> of the table.

B<Deprecated name:> I<font_color> (will go away in the future!)

=item B<bg_color> - Background color of this cell.

B<Value:> Color specifier as 'name' or '#rrggbb'

B<Default:> undef

B<Deprecated name:> I<background_color> (will go away in the future!)

=item B<underline> - Underline of this cell's text.

B<Value:> 'auto', integer of distance, or arrayref of distance & thickness 
(more than one pair will provide multiple underlines). Negative distance gives 
strike-through. C<[]> or 'none' gives no underline.

B<Default:> none

B<Deprecated name:> I<font_underline> (will go away in the future!)

=item B<justify> - Alignment of text in this cell.

B<Value:> One of 'left', 'right', 'center'

B<Default:> C<'left'>

=item B<colspan> - Span this cell over multiple columns to the right.

B<Value:> can be any positive number less than the number of columns to the 
right of the current column

B<Default:> undef

NOTE: If you want to have regular columns B<after> a colspan, you have to 
provide C<undef> for the columns that should be spanned

NOTE: If you use C<colspan> to span a column, but provide data for it, your 
table will be mangled: the spanned-but-data-provided-column will be rendered! 
But, as HTML works the same way, we do not consider this a bug.

Example:

    # row2 col1 should span 2 cols:
    @data = ( [ 'r1c1', 'r1c2', 'r1c3' ], ['r2c1+',undef,'r2c3'] );
    $tab->table( $pdf, $page, \@data, %TestData::required,
      'cell_props' => [
          [],
          [{'colspan' => 2}]
      ]
    );

=back

See the file C<examples/colspan.pl> for detailed usage.

Example:

    my $cell_props = [
        [ # This array is for the first row. 
          # If header_props is defined, it will override these settings.
            {    # Row 1 cell 1
                'bg_color'  => '#AAAA00',
                'fg_color'  => 'yellow',
                'underline' => [ 2, 2 ],
            },

            # etc.
        ],
        [ # Row 2
            {    # Row 2 cell 1
                'bg_color' => '#CCCC00',
                'fg_color' => 'blue',
            },
            {    # Row 2 cell 2
                'bg_color' => '#BBBB00',
                'fg_color' => 'red',
            },
            # etc.
        ],
        [ # Row 3
            {    # Row 3 cell 1 span cell 2
                'colspan' => 2
            },
            # etc.
        ],
        # etc.
    ];

    OR

    my $cell_props = [];
    $cell_props->[1][0] = {
        # Row 2 cell 1
        'bg_color' => '#CCCC00',
        'fg_color' => 'blue',
    };

B<NOTE:> In case of a conflict between column, odd/even, and cell formatting; 
cell formatting will override the other two.
In case of a conflict between header row and cell formatting, header 
formatting will override cell formatting.

=head2 text_block()

    my ($width_of_last_line, $ypos_of_last_line, $left_over_text) = 
        text_block( $txt, $data, %settings)

=over

=item Description

Utility method to create a block of text. The block may contain multiple 
paragraphs.
It is mainly used internally, but you can use it from outside for placing 
formatted text anywhere on the sheet.

NOTE: This method will NOT add more pages to the PDF instance if the space is 
not enough to place the string inside the block.
Leftover text will be returned and has to be handled by the caller - i.e., add 
a new page and a new block with the leftover.

=item Parameters

    $txt  - a PDF::Builder::Page::Text instance representing the text tool
    $data - a string that will be placed inside the block
    %settings - HASH with geometry and formatting parameters.

=item Returns

The return value is a 3 item list where

    $width_of_last_line - Width of last line in the block
    $final_y - The Y coordinate of the block bottom so that additional 
               content can be added after it
    $left_over_text - Text that did not fit in the provided box geometry.

=item Example

    # PDF::Builder objects
    my $page = $pdf->page();
    my $txt  = $page->text();

    my %settings = (
        # MANDATORY position and table size
        'x' => 10,
        'y' => 570,
        'w' => 220,
        'h' => 180,

        # OPTIONAL PARAMETERS
        'leading'  => $font_size*1.15 | $distance_between_lines,
        'align'    => "left|right|center|justify|fulljustify",
                        default: left
        'max_word_length' => $optional_max_word_chars_between_splits
                        default: 20
        'parspace' => $optional_vertical_space_before_paragraph,
                        default: 0 extra vertical space

        # Only one of the following parameters can be given.
        # They override each other, in the order given. C<hang> is the 
        # highest weight.
        'hang'     => $optional_hanging_indent,
        'flindent' => $optional_indent_of_first_line,
        'fpindent' => $optional_indent_of_first_paragraph,
        'indent'   => $optional_indent_of_text_to_every_non_first_line,
    );

    my ( $width_of_last_line, $final_y, $left_over_text ) = 
         $pdftable->text_block( $txt, $data, %settings );

=back

=head1 VERSION

1.000

=head1 AUTHOR

Daemmon Hughes

=head1 DEVELOPMENT

Further development Versions 0.02 -- 0.11 - Desislav Kamenov

Further development since Ver: 0.12 - Phil Perry

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2006 by Daemmon Hughes, portions Copyright 2004 Stone
Environmental Inc. (www.stone-env.com) All Rights Reserved.

Copyright (C) 2020 by Phil M Perry.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.7 or,
at your option, any later version of Perl 5 you may have available.
Note that Perl 5.10 is the minimum supported level.

=head1 PLUGS

=over

=item by Daemmon Hughes

Much of the work on this module was sponsered by
Stone Environmental Inc. (www.stone-env.com).

The text_block() method is a slightly modified copy of the one from
Rick Measham's PDF::API2 tutorial at
http://pdfapi2.sourceforge.net/cgi-bin/view/Main/YourFirstDocument

=item by Desislav Kamenov (@deskata on Twitter)

The development of this module was supported by SEEBURGER AG (www.seeburger.com) till year 2007

Thanks to my friends Krasimir Berov and Alex Kantchev for helpful tips and QA during development of versions 0.9.0 to 0.9.5

Thanks to all GitHub contributors!

=back

=head1 CONTRIBUTION

PDF::Table is on GitHub. You are more than welcome to contribute!

https://github.com/PhilterPaper/PDF-Table

=head1 SEE ALSO

L<PDF::API2>, L<PDF::Builder>

=cut

