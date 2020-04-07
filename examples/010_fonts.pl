#!/usr/bin/perl -w
use strict;
use warnings;
use Carp 'verbose'; local $SIG{__DIE__} = sub { Carp::confess(@_) }; use Data::Dumper;
use PDF::API2;
use PDF::Table;
my ( $pdf, $page, $font, $ttfont, $ttfont_serif, $text, $pdftable, $left_edge_of_table, $try, $dir );
$dir = '/usr/share/fonts/truetype/dejavu/';
use utf8; 
$try = " 
accents:         á é í ó ú  Á É Í Ó Ú 
Spanish (tilde): ñ Ñ   ¿ ¡
German (umlaut): ä ö ü ß Ö Ä Ü 
Cyrillic:        ѐ Ѐ Ѡ ѡ Ѣ 
Greek:           α β γ δ Γ Δ 
Armenian:        Ա Բ Գ Դ Ե 
Hebrew:          א ב ג ד 
Arabic:          ر     ش س ذ      
Mono:            iI lL zero=0 one=1
Latin-1 Supplement:  ° À Ð à ð
Latin-Extended A:    Ā Đ Ġ 
Latin-Extended B:    ƀ Ɛ Ơ
Cyrillic Supplement: Ԃ Ԡ Ԓ  
http://dejavu.sourceforge.net/samples/DejaVuSans.pdf

"; no utf8; 

# https://github.com/dejavu-fonts/dejavu-fonts
#   /usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf  
# You can save custom fonts in the folder ~/.fonts
# $ sudo apt update && sudo apt -y install font-manager
# https://dejavu-fonts.github.io/Samples.html 

&make_another('010_fonts-default.pdf', '', $try , 'logo.png' );
use utf8; my $try_utf8 = $try; 
&make_another('010_fonts-use_utf.pdf', 'DejaVuSans', $try_utf8 , 'logo.png' );
no utf8; my $no_utf8 = $try; 
&make_another('010_fonts-no_utf8.pdf', 'DejaVuSans', $no_utf8  , 'logo.png' );
# &make_another('010_fonts-default.pdf', 'DejaVuSans', $try , 'logo.png' );


sub make_another {
    my ($file, $passed_font_name, $passed_text, $passed_image_name ) = @_ ; 
    print "Passed \$file = '$file', \$font_name = '$passed_font_name', \$image_name = '$passed_image_name' \n"; 
    print "\n INLINE! 
accents:         á é í ó ú  Á É Í Ó Ú 
Spanish (tilde): ñ Ñ   ¿ ¡
German (umlaut): ä ö ü ß Ö Ä Ü 
Cyrillic:        ѐ Ѐ Ѡ ѡ Ѣ 
Greek:           α β γ δ Γ Δ 
Armenian:        Ա Բ Գ Դ Ե 
Hebrew:          א ב ג ד 
Arabic:          ر     ش س ذ      
Mono:            iI lL zero=0 one=1
Latin-1 Supplement:  ° À Ð à ð
Latin-Extended A:    Ā Đ Ġ 
Latin-Extended B:    ƀ Ɛ Ơ
Cyrillic Supplement: Ԃ Ԡ Ԓ  
http://dejavu.sourceforge.net/samples/DejaVuSans.pdf


    ";
    # Create a blank PDF file
    $pdf = PDF::API2->new();
    $pdftable = new PDF::Table;
    # Add a blank page
    $page = $pdf->page();
    # Set the page size
    # my $page->mediabox('Letter');
    # Add a built-in font to the PDF
        # Add some text to the page
    $text = $page->text();
    $font = $pdf->corefont('Helvetica-Bold' ,-encode => 'utf8' ); # but core fonts don't have utf8 ! 
    $text->font( $font, 14 );   $text->translate( 50, 700 );
    $text->text("In core font: $passed_text\n");
    print "$dir"."$passed_font_name".'.ttf';
    my $ttfont;
    if (!$passed_font_name) {$ttfont =  $pdf->ttfont($dir.'DejaVuSans'.'.ttf');}
    else {$ttfont =  $pdf->ttfont($dir.$passed_font_name.'.ttf');}
    $text->font( $ttfont, 14 );   $text->translate( 50, 650 );
    $text->text("In true type font: $passed_text\n");
    $text->translate( 50, 600 );
    $text->text("In true type font: INLINE!
accents:         á é í ó ú  Á É Í Ó Ú 
Spanish (tilde): ñ Ñ   ¿ ¡
German (umlaut): ä ö ü ß Ö Ä Ü 
Cyrillic:        ѐ Ѐ Ѡ ѡ Ѣ 
Greek:           α β γ δ Γ Δ 
Armenian:        Ա Բ Գ Դ Ե 
Hebrew:          א ב ג ד 
Arabic:          ر     ش س ذ      
Mono:            iI lL zero=0 one=1
Latin-1 Supplement:  ° À Ð à ð
Latin-Extended A:    Ā Đ Ġ 
Latin-Extended B:    ƀ Ɛ Ơ
Cyrillic Supplement: Ԃ Ԡ Ԓ  
http://dejavu.sourceforge.net/samples/DejaVuSans.pdf
 
    \n");

    my $some_data = [ ['core font: '. $passed_text], ];
    $left_edge_of_table = 50;
#    x                    
#    w                    
#    start_y              
#    start_h              
#    next_y               
#    next_h               
#    lead                 
#    padding              
#    padding_right        
#    padding_left         
#    padding_top          
#    padding_bottom       
#    background_color     
#    background_color_odd 
#    background_color_even
#    border               
#    border_color         
#    horizontal_borders   
#    vertical_borders     
#    font                 
#    font_size            
#    font_underline       
#    font_color           
#    font_color_even      
#    font_color_odd       
#    background_color_odd 
#    background_color_even
#    row_height           
#    new_page_func        
#    header_props         
#    column_props         
#    cell_props           
#    max_word_length      
#    cell_render_hook     
#    default_text
#
    # build the table layout
    $pdftable->table(
        # required params
        $pdf, $page, $some_data, x  => $left_edge_of_table, w  => 500, start_y => 500, start_h => 300,
        # some optional params
       font => $font , 
    #     next_y        => 750,
    #    next_h        => 500,
     #   padding       => 5,
      #  padding_right => 10,
#     background_color_odd  => "gray",
#     background_color_even => "lightblue", #cell background color for even rows
    );
    $some_data = [ ['true type font: '. $passed_text], ];
    $left_edge_of_table = 50;
if ($passed_font_name) {
    $pdftable->table( $pdf, $page, $some_data, x  => $left_edge_of_table, w  => 500, start_y => 200, start_h => 300, font => $ttfont , );
}
else {  # go to default font 
       $pdftable->table( $pdf, $page, $some_data, x  => $left_edge_of_table, w  => 500, start_y => 200, start_h => 300, );
}
   # Save the PDF
$pdf->saveas($file);
}