use strict;
use warnings;
use File::Slurp;

# new paragraph WITHIN a list item... indent 4 spaces

my $TextMarkdown = '0';
my $TextMultiMarkdown = '0';

if (@ARGV != 1) {
  print "usage: md2html basename\n  expect basename.md as readable file,\n  produce basename.html as output.\n";
  exit(1);
}

my $basename = $ARGV[0];
my $input  = "$basename.md";
my $output = "$basename.html";
print "Input: $input, Output: $output\n";

my $in_txt = '';
my $out_txt  = "<html>\n<head>\n<title>$basename Markdown</title>\n<style>\n";
   $out_txt .= "body { font-size: 12pt; }\nli { margin-top: 6pt; }\n";
   $out_txt .= "</style>\n</head>\n<body>\n";

   $in_txt = read_file($input);
#$out_txt .= _md1_hash($in_txt);
$out_txt .= _md2_hash($in_txt);
$out_txt .= "</body>\n</html>\n";

open(my $OUT, '>', $output) or die "unable to open output file $output";
my @OUTPUT = split /\n/,$out_txt;
while (@OUTPUT) {
    my $line = shift @OUTPUT;
    print $OUT "$line\n";
}
close($OUT);

sub _md1_hash {
    my ($text, %opts) = @_;
    my $page_numbers = 0;
    $page_numbers = $opts{'page_numbers'} if defined $opts{'page_numbers'};

    my @array;
    my ($html, $rc);
    $rc = eval {
        require Text::Markdown;
	1;
    };
    if (!defined $rc) { $rc = 0; }  # else is 1
    if ($rc) {
	# installed, but not up to date?
	if (version->parse("v$Text::Markdown::VERSION")->numify() <
	    version->parse("v$TextMarkdown")->numify()) { $rc = 0; }
    }

    if ($rc) {
	# MD converter appears to be installed, so use it
	$html = Text::Markdown::markdown($text);
    } else {
	# leave as MD, will cause a chain of problems
	warn "Text::Markdown not installed, can't process Markdown";
	$html = $text;
    }

    # need to fix something in Text::Markdown -- custom HTML tags are
    # disabled by changing < to &lt;. change them back!
    $html =~ s/&lt;_ref /<_ref /g;
    $html =~ s/&lt;_reft /<_reft /g;
    $html =~ s/&lt;_nameddest /<_nameddest /g;
    $html =~ s/&lt;_sl /<_sl /g;
    $html =~ s/&lt;_move /<_move /g;
    $html =~ s/&lt;_marker /<_marker /g;
    # probably could just do it with s/&lt;_/<_/ but the list is short
    
    # blank lines within a list tend to create paragraphs in list items
    $html =~ s/<li><p>/<li>/g;
    $html =~ s#</p></li>#</li>#g;

    # standard Markdown ~~ line-through (strike-out) not recognized
    my $did_one = 1;
    while ($did_one) {
	$did_one = 0;
	if ($html =~ s#~~([^~])#<del>$1#) {
	    # just one at a time. replace ~~ by <del>
	    $did_one = 1;
	}
	# should be another, replace ~~ by </del>
	$html =~ s#~~([^~])#</del>$1#;
    }

    # standard Markdown === by itself not recognized as a horizontal rule
    $html =~ s#<p>===</p>#<hr>#g;

    # dummy (or real) style element will be inserted at array element [0]
    #   by _html_hash()

    # blank-line separated paragraphs already wrapped in <p> </p>
#   @array = _html_hash($page_numbers, $html, %opts);

#   return @array;
    return $html;
} # end of _md1_hash()

# convert md2 string to html, returning array of hashes
sub _md2_hash {
    my ($text, %opts) = @_;
    my $page_numbers = 0;
    $page_numbers = $opts{'page_numbers'} if defined $opts{'page_numbers'};

    my @array;
    my ($html, $rc);
    $rc = eval {
        require Text::MultiMarkdown;
	1;
    };
    if (!defined $rc) { $rc = 0; }  # else is 1
    if ($rc) {
	# installed, but not up to date?
	if (version->parse("v$Text::MultiMarkdown::VERSION")->numify() <
	    version->parse("v$TextMultiMarkdown")->numify()) { $rc = 0; }
    }

    my $heading_ids = 0; # default no automatic id generation for hX
    if (defined $opts{'heading_ids'}) { $heading_ids = $opts{'heading_ids'}; }

    if ($rc) {
	# MD converter appears to be installed, so use it
	$html = Text::MultiMarkdown->new(
		'heading_ids' => $heading_ids,
		'img_ids' => 0,
		'empty_element_suffix' => '>',
	)->markdown($text);
    } else {
	# leave as MD, will cause a chain of problems
	warn "Text::MultiMarkdown not installed, can't process Markdown";
	$html = $text;
    }

   # need to fix something in Text::Markdown -- custom HTML tags are
    # disabled by changing < to &lt;. change them back!
    $html =~ s/&lt;_ref /<_ref /g;
    $html =~ s/&lt;_reft /<_reft /g;
    $html =~ s/&lt;_nameddest /<_nameddest /g;
    $html =~ s/&lt;_sl /<_sl /g;
    $html =~ s/&lt;_move /<_move /g;
    $html =~ s/&lt;_marker /<_marker /g;
    # probably could just do it with s/&lt;_/<_/ but the list is short
    
    # blank lines within a list tend to create paragraphs in list items
    $html =~ s/<li><p>/<li>/g;
    $html =~ s#</p></li>#</li>#g;

    # standard Markdown ~~ line-through (strike-out) not recognized
    my $did_one = 1;
    while ($did_one) {
    	$did_one = 0;
    	if ($html =~ s#~~([^~])#<del>$1#) {
    	    # just one at a time. replace ~~ by <del>
    	    $did_one = 1;
    	}
    	# should be another, replace ~~ by </del>
    	$html =~ s#~~([^~])#</del>$1#;
    }

    # standard Markdown === by itself not recognized as a horizontal rule
    $html =~ s#<p>===</p>#<hr>#g;

    # dummy (or real) style element will be inserted at array element [0]
    #   by _html_hash()

    # blank-line separated paragraphs already wrapped in <p> </p>
#    @array = _html_hash($page_numbers, $html, %opts);

#    return @array;
    return $html;
} # end of _md2_hash()

