# PDF::Table Road Map

This module creates and inserts text blocks and tables into PDF documents 
using the PDF::API2 or PDF::Builder Perl module.

_We can offer no guarantees that any of these items listed will be addressed,
nor in what order. We will be happy to discuss offers of Pull Requests to implement 
specific items. Preferably, any new function will work equally well on PDF::API2 and
PDF::Builder._

Keep some things in mind. One is that PDF::Table needs to work properly on both
PDF::Builder and PDF::API2. It doesn't _absolutely_ rule out implementing something
that makes use of, say, `column()` (in PDF::Builder), but we _try_ to make
functionality work the same on both. The second is that PDF::Table is somewhat "inside
out" in its approach, as compared to Builder or API2's way of doing things. PDF::Table,
while limiting itself to a page at a time, _does_ try to push the whole table out
in one call, creating new pages if necessary. This makes it a bit complicated (but not
necessarily impossible) if you want to output other stuff on a page. Unfortunately, to
change this behavior would probably introduce a great deal of incompatibility, or
require a new API.

1. Some level of hyphenation (word splitting) so that excessively long
words don't cause problems (#83). Do in sync with PDF::Builder with regards to what
word-splitter library is used.
2. Handle request (#66) for cell contents that can be preformatted and/or
fixed-pitch font. If using PDF::Builder, the use of the `column()` facility
will fulfill this in part.
3. Be able to control vertical alignment of cell content across a row.
4. Permit defining of table footer (tfoot tag).
5. Permit images within cells (#51). When PDF::Builder's `column()`
supports images, that will fulfill this in part. Images as the sole content of a cell
shouldn't be too bad, but trying to mix with text will be a challenge. We don't want
to go down the rabbit hole of building an entire markup language just for this.
6. Implement <i>rowspan</i> capability.
7. Make sure that dashed option names are silently converted to undashed forms.
Possibly deprecate dashed forms at some point.
8. Think about what might be done to make each segment of table _inside_ a
given page and text context (called separately), so a table is set up once, but segments
are output (up to a page full) one at a time. Ref: note above about "inside out" design.
9. Although a method exists to measure the vertical size of each row, and can be
used to decide how (and if) to split a table across multiple pages, it is not terribly
efficient (basically, create an entire table, while not putting out any ink). Is there
a better way?
10. Validate parameters by data type and range (allowed values), per #12.
11. Possibly a table caption (tcap), per #31?
12. Longstanding desire to "make more OOP-ish" (#5), but I'm not sure it's worth the effort.
13. Multi-page tables add "continued" or "(Cont.)" at bottom right and top left.
14. Fully check functioning of text_block's _hang, indent, fpindent, flindent,_ etc. 
Make sure they are properly documented in the POD. _parspace_ ignore on first paragraph.
Check if align is done properly, particularly with use of text_center and text_right.
15. Numeric formatting: horizontal alignment on decimal point. Allow room for something 
like 'CR' after the last digit or parentheses around negatives ( - 1234.56CR ) so vertically,
cell contents align. Might want to give `deltaX` value to align "decimal" character on 
(text_center the whole string?).
16. TODO list: implement set_data() and set_options().
17. TODO list: header props compatibility and col_props compatibility.
