use Test::More tests => 11;
use strict;
use warnings;

BEGIN {
   use_ok('PDF::Table')
}
my ($col_widths);
($col_widths, undef) = PDF::Table::CalcColumnWidths(
	[
		{ min_w => 50, max_w => 50 },
		{ min_w => 50, max_w => 50 },
		{ min_w => 50, max_w => 50 },
		{ min_w => 50, max_w => 50 },
	], 400);

is_deeply( $col_widths, [ 100, 100, 100, 100 ], 'CalcColumnWidths - even');

($col_widths, undef) = PDF::Table::CalcColumnWidths(
	[
		{ min_w => 41, max_w => 51 },
		{ min_w => 58, max_w => 600 },
		{ min_w => 48, max_w => 48 },
	], 400);

is_deeply( $col_widths, [ 51, 301, 48 ], 'CalcColumnWidths - uneven');

($col_widths, undef) = PDF::Table::CalcColumnWidths(
	[
		{ min_w => 50, max_w => 50 },
		{ min_w => undef, max_w => 50 },
	], 400);

is_deeply( $col_widths, [ 200, 200 ], 'CalcColumnWidths - undef');

my ($pdf, $page, $tab, @data, @required);

$tab = PDF::Table->new;
@data = (
      [ 'foo', 'bar', 'baz' ],
);
@required = (
      x => 10,
      w => 300,
      start_y => 750,
      next_y => 700,
      start_h => 40,
      next_h => 500,
);

$pdf = PDF::API2->new;
$page = $pdf->page;

#
# this tickles a bug (#34017) which causes an infinite loop
#
'foo' =~ /(o)(o)/;

$tab->table($pdf, $page, [@data], @required,
      border => 1,
      border_color => 'black',
      font_size => 12,
      background_color => 'gray',
      column_props => [
            {}, { background_color => 'red' }, {},
      ],
      cell_props => [
            [ {}, {}, { background_color => 'blue' } ],
      ],
);

ok($pdf->match(
      [[qw(translate 10 738)],[qw(text foo)]],
      [[qw(translate 110 738)],[qw(text bar)]],
      [[qw(translate 210 738)],[qw(text baz)]],
), 'text position');

ok($pdf->match(
      [[qw(rect 10 738 100 12)],[qw(fillcolor gray)]],
      [[qw(rect 110 738 100 12)],[qw(fillcolor red)]],
      [[qw(rect 210 738 100 12)],[qw(fillcolor blue)]],
), 'default header fillcolor');

ok($pdf->match(
      [[qw(gfx)],[qw(strokecolor black)],[qw(linewidth 1)]],
      [[qw(stroke)]],
), "draw borders");

$pdf = PDF::API2->new;
$page = $pdf->page;
$tab->table($pdf, $page, [@data], @required,
      border => 0,
      border_color => 'black',
      font_size => 12,
      column_props => [
            {}, { justify => 'center' }, { justify => 'center' },
      ],
      cell_props => [
            [ { justify => 'center' }, {}, { justify => 'right' } ],
      ],
);

ok($pdf->match(
      [[qw(translate 52.5 738)],[qw(text foo)]],
      [[qw(translate 152.5 738)],[qw(text bar)]],
      [[qw(translate 295 738)],[qw(text baz)]],
), 'justify right and center');

ok(!$pdf->match(
      [[qw(gfx)],[qw(strokecolor black)],[qw(linewidth 0)]],
), "don't set up zero-width borders");

# table is only 3 lines high (4*12 > 40).
@data = (
      [ 'foo', 'bar' ],
      [ 'one', 'two' ],
      [ 'thr', 'four score and seven years ago our fathers brought forth' ],
      [ 'fiv', 'six' ],
      [ 'sev', 'abcdefghijklmnopqrstuvwxyz' ],
);
$pdf = PDF::API2->new;
$page = $pdf->page;
$tab->table($pdf, $page, [@data], @required,
      border => 0,
      font_size => 12,
      max_word_length => 13,
      cell_props => [
            [],
            [ { background_color => 'blue' }, {} ],
      ],
);

ok($pdf->match(
      [[qw(page)]],
      [[qw(rect 10 714 20 12)],[qw(fillcolor blue)]],
      [[qw(translate 10 714)],[qw(text thr)]],
      [[qw(page)]],
      [[qw(rect 10 688 20 12)],[qw(fillcolor blue)]],
      [[qw(translate 10 688)],[qw(text -)]],
), 'keep cell_props values when row spans a page');

ok($pdf->match(
      [['text', 'abcdefghijklm nopqrstuvwxyz']],
), 'break long words on max_word_length');

# use this to craft new tests
#
#for ($pdf->getall) {
#   print join(' ', @$_), "\n";
#}

BEGIN {
   # Mock PDF::API2

   # this is a mini MockObject with factory methods
   package Mock;
   sub new { return bless [] => shift; }

   sub get {
      my $self = shift;
      my $method = shift; # optional method name
      return $method ?  grep($_->[0] eq $method, @$self) : @$self;
   }

   sub getall {
      my $self = shift;
      my @all;
      for (@$self) {
         push @all, ref($_->[1]) ? ([$_->[0]], $_->[1]->getall) : $_;
      }
      return @all;
   }

   sub match {
      my $self = shift;
      my $all = join("\n", map {join("\0", @$_)} $self->getall);
      for (@_) {
         my $patt = join("\n", map {join("\0", @$_)} @$_);
         return 0 unless $all =~ /^$patt$/mcg;
      }
      return 1;
   }

   # class methods for creating object methods

   sub set_true {
      my $class = shift;

      for my $method ( @_ ) {
         no strict 'refs';
         *{$class . '::' . $method} =
               sub { push @{+shift}, [$method, @_]; return 1 };
      }
   }

   sub factory {
      my $class = shift;
      my $target = shift;
      my $method = shift;

      no strict 'refs';
      *{$class . '::' . $method} = sub {
            my $thing = $target->new;
            push @{+shift}, [$method, $thing];
            return $thing;
      };
   }

   package PDF::API2;
   our @ISA = 'Mock';
   __PACKAGE__->set_true(qw(corefont));
   __PACKAGE__->factory('PDF::API2::Page', 'page');

   package PDF::API2::Page;
   our @ISA = 'Mock';
   __PACKAGE__->factory('PDF::API2::Content', 'gfx');
   __PACKAGE__->factory('PDF::API2::Content::Text', 'text');

   package PDF::API2::Content;
   our @ISA = 'Mock';
   __PACKAGE__->set_true(
         qw(strokecolor linewidth move hline vline fillcolor stroke rect fill));

   package PDF::API2::Content::Text;
   our @ISA = 'Mock';
   __PACKAGE__->set_true(qw(font fillcolor translate text));
   sub advancewidth { shift; return 5 * length shift }
}
