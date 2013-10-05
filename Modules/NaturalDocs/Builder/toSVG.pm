###############################################################################
#
#   Package: NaturalDocs::Builder::toSVG
#
###############################################################################
#
#   A package to produce SVG from (diagram) tags
#
###############################################################################

# This file is part of Natural Docs,
# which is Copyright (C) 2003-2006 Greg Valure
# This file is Copyright (C) 2007 Martin Thompson
# Natural Docs is licensed under the GPL
package NaturalDocs::Builder::toSVG;

use strict;
# use integer;

my $debug;
my $scale;
sub line # (x1, y2, x2, y2)
  {
    my ($x1, $y1, $x2, $y2) = @_;
    $x1*= $scale; $x2*=$scale; $y1*=$scale; $y2*=$scale;
    my $strokewidth=0.05*$scale;
    my $t = '<line style="stroke-linecap: round" stroke-width="'.$strokewidth.'" x1="'.$x1.'" y1="' .$y1.'" x2="'.$x2.'" y2="'.$y2.'" />';
    return $t;

}

sub dottedline # (x1, y2, x2, y2)
  {
    my ($x1, $y1, $x2, $y2) = @_;
    $x1*= $scale; $x2*=$scale; $y1*=$scale; $y2*=$scale;
    my $dots = $scale/8.0;
    my $gaps = 3*$scale/8.0;
    my $t = '<line style="stroke-dasharray: '.$dots.','.$gaps.'" x1="'.$x1.'" y1="' .$y1.'" x2="'.$x2.'" y2="'.$y2.'" />';
    return $t;
}

sub thinline # (x1, y2, x2, y2)
  {
    my ($x1, $y1, $x2, $y2) = @_;
    $x1*= $scale; $x2*=$scale; $y1*=$scale; $y2*=$scale;
    my $strokewidth=0.01*$scale;
    my $t = '<line stroke-width="'.$strokewidth.'" stroke="gray" x1="'.$x1.'" y1="' .$y1.'" x2="'.$x2.'" y2="'.$y2.'" />';
    return $t;

}

sub thickline # (x1, y2, x2, y2)
  {
    my ($x1, $y1, $x2, $y2) = @_;
    $x1*= $scale; $x2*=$scale; $y1*=$scale; $y2*=$scale;
    my $strokewidth=0.15*$scale;
    my $t = '<line style="stroke-linecap: round" stroke-width="'.$strokewidth.'" x1="'.$x1.'" y1="' .$y1.'" x2="'.$x2.'" y2="'.$y2.'" />';
    return $t;

}

sub circle # (cx, cy, radius)
{
  my ($cx, $cy, $radius) = @_;
    $cx*= $scale; $cy*=$scale; $radius*=$scale;
    my $strokewidth=0.05*$scale;
  return '<circle fill = "none" stroke-width="'.$strokewidth.'" cx="'.($cx).'" cy="' . ($cy).'" r="'.$radius.'" />';
}

sub blob # (cx, cy, radius)
{
  my ($cx, $cy, $radius) = @_;
    $cx*= $scale; $cy*=$scale; $radius*=$scale;
  return '<circle fill="red" stroke-width="0" cx="'.($cx).'" cy="' . ($cy).'" r="'.$radius.'" />';
}

# align can be start, end or middle
sub text # (x, y, text, align)
{
  my ($x, $y, $text, $align) = @_;
  $x*= $scale; $y*=$scale;

  # MJT debug: show intended alignment
  if ($debug) {
    if ($align eq "end") {
      $text .= '}';
    }
    elsif ($align eq "start") {
      $text='{'.$text;
    }
  }
  my $fontsize=0.9*$scale;
  # move it up a bit
  $y -= 0.12*$scale;
  my $t = '<text font-size="'.$fontsize.'" stroke-width="0" stroke="none" fill="black" font-family="monospace" text-anchor="'.$align.'" x="'.($x).'" y="' . ($y-0.2).'">'.$text.'</text>';
  # MJT debug - "show origin"
  if ($debug) {
    my $radius=0.1*$scale;
    $t .= '<circle stroke-width="0" fill="magenta" r="'.$radius.'" cx="'.$x.'" cy="'.$y.'" />';
  }
  return $t;
}

#
#   Function: drawingToSVG
#
#   Converts a drawing block of text into SVG
#
#   Parameters:
#
#       text - the block of text to convert
#   outputFile - filename of SVG file to create
#       config - dictionary of values to configure the output
#              - "debug" is an option, set to '1' to get a grid and see the justification of text
#              - "scale" can be a float - the output SVG will be scaled by this amount
#
#
# Examples:
#
#


sub drawingToSVG #(text, outputFile, config)
  {
  my ($text, $outputFile, %config) = @_;
  undef $debug;
# if ($config{"debug"}==1) {
#   $debug=1;
# }
# print "Begin drawing \n" if $debug;
  foreach (%config) {
    print $_."\n" if $debug;
  }
  # set a default scale
  $scale = 1.0;
  if ($config{"scale"}) {
    $scale=$config{"scale"};
  }
  # need to scale the scale to make things sensible
  $scale *= 15.0;

# print "\n---New drawing block---\n". $text."---\nEnd of block---\n" if $debug;
  # 
  # Conversion to SVG:
  # We convert to SVG by making the textblock into an array of characters
  # each character block is 1.0x1.0 units in size.  We then approximate the characters to filling those boxes.  The centre of the top left box is deemed to be at (0.5, 0.5)...
  # (begin diagram)
  #   012345
  # 0 -----
  # 1 ..... etc
  # (end diagram)
  # represents a line from (0,0.5 to 4, 0.5)
  # then we scale everyhting up by $scale, as firefox and konq struggle to line things up otherwise (even if we set the actual picture to be the same number of pixel wide!)

# print "New output: $outputFile\n";
  # create an array from the data input
  my @lines=split('\n', $text);
  if ($#lines < 1) {
    print "no data" if $debug;
    return '\n';
  }

# print "Lines\n";
# print join('\n', @lines);
  my $longest=0;
  foreach (@lines) {
    if (length($_) > $longest) {
      $longest=length($_);
    }
  }

# print "Longest line = $longest, lines=$#lines\n";
  my @a;
  # array a is used to store all the data... preallocate the end:
  $a[$longest-1][$#lines]=' ';
  my ($x, $y);
  $y=0;
  foreach my $l (@lines) {
    for ($x=0;$x < length($l); $x++) {
      my $c = substr($l, $x, 1);
      $a[$x][$y] = $c;
    }
    for (;$x<$longest;$x++) {
      $a[$x][$y] = ' ';
    }
    $y++;
  }

  # create the svg file
  my $scalex=1.0;#15.0/$scale;#*3.0/6.0;
  my $scaley=1.0;#15.0/$scale;
  my $width=$longest+1;
  my $height=$#lines+2;
  my $scaledwidth=$scale*($width)*$scalex;
  my $scaledheight=$scale*($height)*$scaley;
  open(f, ">".$outputFile);
  my $borderwidth=0.05*$scale;
  my $borderx=$scale*$width;
  my $bordery=$scale*$height;
  my $strokewidth=0.1*$scale;
  my $half=0.5*$scale;

  print f '<svg xmlns="http://www.w3.org/2000/svg"
     xmlns:xlink="http://www.w3.org/1999/xlink"'.
     "\nwidth=\"$scaledwidth\" height=\"$scaledheight\"
>

<g transform=\"scale($scalex,$scaley)\">
<rect fill=\"none\" stroke-width=\"$borderwidth\" stroke=\"blue\" x=\"0\" y=\"0\" width=\"$borderx\" height=\"$bordery\" />
<g transform=\"translate($half, $half)\" stroke-width=\"$strokewidth\" stroke=\"red\">\n";

  my $o;
  for ($y=0;$y<=$#lines;$y++) {
    for ($x=0;$x<$longest;$x++) {
      $o = "";
      # top left x,y of current cell
      my ($lx, $ty) = ($x, $y);
      # centre x, y
      my ($cx, $cy)=($lx+0.5, $ty+0.5);
      # right x, above y
      my ($rx, $by)=($lx+1, $ty+1);
      # $c is current char, $l is to left, $r to right, t is to top etc:
      #tl t tr 
      # l c r 
      #bl b br
      my $c=$a[$x][$y];
      my $l=$a[$x-1][$y];
      my $r=$a[$x+1][$y];
      my $t=$a[$x][$y-1];
      my $b=$a[$x][$y+1];
      my $tl=$a[$x-1][$y-1];
      my $tr=$a[$x+1][$y-1];
      my $bl=$a[$x-1][$y+1];
      my $br=$a[$x+1][$y+1];
      my $arrow = 0.3;
      undef $o;
#       print "$x $y $c\n";

#       print "$tl$t$tr\n";
#       print "$l$c$r\n";
#       print "$bl$b$br\n";

      if ($c=~/[A-Za-z0-9]+/ and ($r=~/[A-Za-z0-9:]+/ or $l =~/[A-Za-z0-9]+/)) {
	# need to merge text together and underline
	my $underlineleft=undef;
	if ($l eq '_') {
	  $underlineleft=$lx;
# 	  print "Got underline left $c $x $y\n"
	}
	my $text='';
	my $leftoftext = $l;
	for ($rx=$x+2; $rx<=$longest+1;$rx++) {
          $text.=$c;
	  $c = $r;
	  $r = $a[$rx][$y];
	}
#	print "\nStart:$text:\n" if $debug;
	# chop of >= 2 spaces
	$text =~ s/\s{2,}.*//;
	# chop off *X_*
	$text =~ s/([^_]*)[_]+X[_]+.*$/\1/;
#       print "1:$text:\n" if $debug;
	# chop off __.*
	$text =~ s/(.*)_[_]+/\1/;
#	print "2:$text:\n" if $debug;
	# chop off trailing _'s and whitespace
	$text =~ s/[_.]+\s*$//;
#	print "3:$text:\n" if $debug;
	# reduce to "plain" text
	$text =~ s/^([A-Za-z0-9_;,.!"£$%^&*\(\) ]+).*/\1/;
#	print "4:$text:\n" if $debug;
#	print "After: $text\n" if $debug;

	$x+=length($text); # setup next starting point
	$rx=$x;
	$r=$a[$x][$y];
	$x--;

	if ($underlineleft && $r eq '_') {
# 	  print "Got underline right $lx $rx $by \n";
	  $o .= line($lx, $by, $rx, $by);
	}
	my $align;
	my $rightoftext=$r;
	my $tx;
# 	print "$leftoftext, $rightoftext\n";
	if ($leftoftext ne ' ') {
	  if ($rightoftext ne ' ') {
	    $align="middle";
	    $tx=($rx+$lx)/2.0;
	  }
	  else { # we have a non text char to left, so butt up to it
	    $align="start";
	    $tx=$lx;
	    $text=$text;
	  }
	}
	else { # left of text is a space
	  if ($rightoftext eq ' ') { # between spaces
	    $align="middle";
	    $tx=($rx+$lx)/2.0;
	  }
	  else { # right of text is not a space
	    $align="end";
	    $tx=$rx;
	  }
	}
# 	print "$align, $lx, $rx, $tx, $leftoftext!$text!$rightoftext\n" if $debug;
	$o .= text($tx, $by, $text, $align);
      }
      elsif ($c eq '_') {
	$o = line($lx, $by, $rx, $by);
	if ($r eq '|' or $br eq '|') {
	  $o .= line($rx, $by, $rx+0.5, $by);
	}
	if ($l eq '|' or $bl eq '|') {
	  $o .= line($lx, $by, $lx-0.5, $by);
	}
      }
      elsif ($c eq '|') {
	$o = line($cx, $ty, $cx, $by);
      }
      elsif ($c eq '-' or $c eq '=') {
	# reach out to join adjacent \/|* 
#xxx could this be better done in those chars??? instead with a reach out function?
	if ($r =~ m/[*\\\/\|]+/) {
	  $rx += 0.5;
	}
	if ($l =~ m/[*\\\/\|]+/) {
	  $lx -= 0.5;
	}
	if ($c eq '-') {
	  $o = line($lx, $cy, $rx, $cy);
	}  else {
	  $o = thickline($lx, $cy, $rx, $cy);
	}
      }
      elsif ($c eq '[') {
	$o = line($cx, $by, $cx, $ty);
	$o .= line($cx, $by, $rx, $by);
	$o .= line($cx, $ty, $rx, $ty);
      }
      elsif ($c eq ']') {
	$o = line($cx, $by, $cx, $ty);
	$o .= line($lx, $by, $cx, $by);
	$o .= line($lx, $ty, $cx, $ty);
      }
      elsif ($c eq '.') {
	$o = dottedline($lx, $cy, $rx, $cy);
      }
      elsif ($c eq '\\') {
	$o = line($lx, $ty, $rx, $by);
      }
      elsif ($c eq '/') {
	$o = line($rx, $ty, $lx, $by);
      }
      elsif ($c eq '>') {
	if ($l eq '-') { # make a right arrow
	  $o = line($cx, $cy-$arrow, $rx, $cy);
	  $o .= line($cx, $cy+$arrow, $rx, $cy);
	  $o .= line($lx, $cy, $rx, $cy);
	}
	else {
	  $o  = line($lx, $ty, $cx, $cy);
	  $o .= line($lx, $by, $cx, $cy);
	}
      }
      elsif ($c eq '<') {
	if ($r eq '-') { # make a left arrow
	  $o = line($cx, $cy-$arrow, $lx, $cy);
	  $o .= line($cx, $cy+$arrow, $lx, $cy);
	  $o .= line($lx, $cy, $rx, $cy);
	}
	else {
	  $o  = line($rx, $ty, $cx, $cy);
	  $o .= line($rx, $by, $cx, $cy);
	}
      }
      elsif ($c eq '^') {
	if ($b eq '|') { # make an upward arrow
	  $o = line($cx-$arrow, $cy, $cx, $ty);
	  $o .= line($cx+$arrow, $cy, $cx, $ty);
	  $o .= line($cx, $ty, $cx, $by);
	}
	else {
	  $o  = line($lx, $cy, $cx, $ty);
	  $o .= line($rx, $cy, $cx, $ty);
	}
      }
      elsif ($c eq 'V') {
	$o  = line($lx, $ty, $cx, $by);
	$o .= line($rx, $ty, $cx, $by);
      }
      elsif ($c eq 'v') {
	if ($t eq '|') { # make a downward arrow
	  $o = line($cx-$arrow, $cy, $cx, $by);
	  $o .= line($cx+$arrow, $cy, $cx, $by);
	  $o .= line($cx, $ty, $cx, $by);
	}
	else {
	  $o  = line($lx, $cy, $cx, $by);
	  $o .= line($rx, $cy, $cx, $by);
	}
      }
      elsif ($c eq 'X') {
	$o  = line($lx, $ty, $rx, $by);
	$o .= line($rx, $ty, $lx, $by);
      }
      elsif ($c eq 'O') {
	$o = circle($cx, $cy, 0.5);
      }
      elsif ($c eq 'o') {
	$o = circle($cx, $cy, 0.25);
      }
      elsif ($c eq '*') {
	$o = blob($cx, $cy, 0.25);
      }
      elsif ($c eq '+') {
	$o= "";
	if ($l eq '-' ) {
	  $o .= line($lx, $cy, $cx, $cy);
	}
	if ($r eq '-' ) {
	  $o .= line($cx, $cy, $rx, $cy);
	}
	if ($t eq '|' ) {
	  $o .= line($cx, $cy, $cx, $ty);
	}
	if ($b eq '|' ) {
	  $o .= line($cx, $cy, $cx, $by);
	}
      }
      elsif ($c eq ' ' or !$c) {
	# do nothing
      }
      else {
	$o .= text($cx, $by, $c, "middle")
      }
      if ($o) {
	print f $o."\n";
      }
    }
  } 
  # MJT debug: put a grid on
  if ($debug) {
    for ($x=0;$x<$width;$x++) {
      print f thinline($x, 0, $x, $height-1);
    }
    for ($y=0;$y<$height;$y++) {
      print f thinline(0, $y, $width-1, $y);
    }
  }
  print f "</g></g></svg>";
  close f;
#   print "$longest, $#lines\n";
#   print "$width, $height\n";
#   print "$scaledwidth, $scaledheight\n";
#   $scaledwidth += 0*$scalex*$scale;
#   $scaledheight += 0*$scaley*$scale;
#   print "$scaledwidth, $scaledheight\n";

  my $localFile = $outputFile;
  $localFile=~s/.*[\\\/](.*)/\1/; # reduce to last path element by splitting at slashes of either variety
  my $retval = "
<!-- we have to put table tags around the object, otherwise Firefox sticks the content inside the search results iframe for no discernable reason! -->
<table><tr><object data=\"$localFile\" type=\"image/svg+xml\" width=\"$scaledwidth\" height=\"$scaledheight\"></object></tr></table>\n";
#   print $retval;
  return $retval;
};

1;
