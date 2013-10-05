# -*- mode: perl; indent-width: 4; -*-
###############################################################################
#
#   Package: NaturalDocs::Parser::Table
#
###############################################################################
#
#   A package that processes indentations within Natural Docs' native format.
#
###############################################################################

# This file is part of Natural Docs. Author Adam Young
# Natural Docs is licensed under the GPL

use NaturalDocs::Parser::TableCell;

use strict;
use integer;

package NaturalDocs::Parser::Table;


###############################################################################
#   Group:      Interface Functions
#

#
#   Function:       New
#       Create and initialise a parsed table class.
#
#   Parameters:
#       rows -              Initial rows.
#
#       cols -              Initial columns.
#
#       options -           Options
#
#   Table format:
#
#>      [title], [caption], [options ..]
#
#   Option:
#
#>      title=text
#
#>      caption=text
#
#>      format=[auto|nd|simple|csv|wiki]
#
#>      justification=[left|center|right]
#
#   Others/todo:
#
#>      border=[none|single|double]             Border style (default=single)
#
#>      frame=[none|single|double]              Cell frame style (default=single)
#
#>      css=style                               User defined CSS style (expert only)
#
sub New #($rows, $cols, $options)
    {
    my ($self, $rows, $cols, $options) = @_;

    my ($object) = {
            ROWS            => $rows || 0,
            COLS            => $cols || 0,
            CURSOR          => 0,
            RULER_COLS      => 0,
            RULER_WIDTH     => 0,
            MAXWIDTH        => 0,
            FORMAT          => 1,               # Default ND
            JUSTIFICATION   => -1,              # default, none
            LINK            => 1,
            HEADER          => 1,
            FILE            => undef,
            TYPE            => 'table'
            };

    if (defined $options)
        {
        $options = $self->ParseCSV($options);

        # [--Embedded]

        if (scalar @$options && $$options[0] eq '--Embedded')
            {
            $object->{TYPE} = 'tableEmbedded';
            $object->{FORMAT} = 1;
            shift @$options;
            }

        # [[title,] [caption]]

        if (scalar @$options && $$options[0] !~ /=/)
            {
            $object->{TITLE} = shift @$options;

            if (scalar @$options && $$options[0] !~ /=/)
                {
                $object->{CAPTION} = shift @$options;
                }
            }

        # options

        foreach (@$options)
            {
            if (/^title\s*=(.*)$/i)
                { $object->{TITLE} = $1; }

            elsif (/^caption\s*=(.*)$/i)
                { $object->{CAPTION} = $1; }

            elsif (/^link\s*=(.*)$/i)
                { $object->{LINK} = (lc($1) eq 'yes' ? 1 : 0); }

            elsif (/^header\s*=(.*)$/i)
                { $object->{HEADER} = (lc($1) eq 'yes' ? 1 : 0); }

            elsif (/^format\s*=(.*)$/i)
                {
                my $format = lc ($1);

                if ($format eq 'auto')
                    { $format = 0; }

                elsif ($format eq 'nd' || $format eq 'nd+')
                    { $format = 1; }

                elsif ($format eq 'simple')
                    { $format = 2; }

                elsif ($format eq 'csv' || $format eq 'cvs')
                    { $format = 3; }            # allow a common misspelling

                else
                    { $format = 0; }            # unknown, try auto

                $object->{FORMAT} = $format;
                }
            elsif (/^justification\s*=(.*)$/i || /^justify\s*=(.*)$/i) 
                {
                my $justification = lc ($1);

                if ($justification eq 'left')
                    { $justification = 0; }

                elsif ($justification eq 'center')
                    { $justification = 1; }

                elsif ($justification eq 'right')
                    { $justification = 1; }

                else 
                    { $justification = -1; }

                $object->{JUSTIFICATION} = $justification;
                };
            };
        };

    return bless $object, $self;
    }


#
#   Function:       Rows
#       Retrieve the current table row limit.
#
sub Rows
    {
    my ($self) = @_;

    return $self->{ROWS};
    }


#
#   Function:       Cols
#       Retrieve the current table column limit.
#
sub Cols
    {
    my ($self) = @_;

    return $self->{COLS};
    }


#
#   Function:       Embedded
#
sub Embedded
    {
    my ($self) = @_;

    return ($self->{TYPE} eq 'tableEmbedded');
    }

#
#   Function:       Caption
#       Retrieve the caption (if any) associated with the table.
#
sub Caption
    {
    my ($self) = @_;

    return $self->{CAPTION};
    }


#
#   Function:       Title
#       Retrieve the title (if any) associated with the table.
#
sub Title
    {
    my ($self) = @_;

    return $self->{TITLE};
    }


#
#   Function:       Summary
#       Retrieve the summary (if any) associated with the table.
#
sub Summary
    {
    my ($self) = @_;

    return $self->{SUMMARY};
    }


#
#   Function:       Cell
#       Retrieve the cell (if any) associated with the specified coords.
#
#   Parameters:
#       row -       row reference
#
#       col -       column reference
#
#   Returns:
#       A NaturalDocs::Parser::TableCell reference
#
sub Cell #(row, col)
    {
    my ($self, $row, $col) = @_;

    return undef
        if ($row > $self->{ROWS} || $col > $self->{COLS});

    return $self->{RARRAY}[$row]->{CARRAY}[$col]
        if (exists $self->{RARRAY}[$row]->{CARRAY}[$col]);

    return undef;
    }

#
#   Function:       ParseLine
#       Table line parser
#
sub ParseLine
    {
    my ($self, $line, $break) = @_;
    my $format = $self->{FORMAT};

    if (2 == $format)
        { return $self->ParseLineSIMPLE($line, $break); }

    elsif (3 == $format)
        { return $self->ParseLineCSV($line, $break); }

    return $self->ParseLineND($line, $break);
    }


#
#   Function:       ParseLineND
#       Parse a ND+ table definition
#
sub ParseLineND #(line)
    {
    my ($self, $line) = @_;

    my ($length) = length ($line);

    # If the line starts with a header delimiter, process (sub)header and
    # build the associated ruler.
    #
    # Support two different formats;
    #
    #   New format using '[text' blocks (with optional closing ']'),
    #
    #       [Field      ][Field     ][Field     ]
    #
    #   and a more traditional '|' delimiter format.
    #
    #       |field      |field      |field      |
    #
    #   lines which begin with [[ are also ignored as these represent
    #   header definitions within sub-tables.
    #
    if (($self->{FORMAT} >= 1 && $line =~ /^(\s*)(\[)[^\[]/) ||
                    ($self->{CURSOR} == 0 && $line =~ /^(\s*)(\|)/))
        {
        # Ignore sub-headers if the primary does not exist

        return if ($self->{CURSOR} && ! $self->{RULER_COLS});

        # Convert to older format if required.

        my $format = $self->{FORMAT};           # current

        if ($self->{CURSOR} == 0 && ($2 eq '|'))
            {
            $format = $self->{FORMAT} = 0;      # disable advanced features
            }

        # End previous row and start new

        $self->RowEnd();
        $self->HeaderStart(length($1), $length);

        # Build header cells

        my ($pos, $col) = (0, 0);

        while (($format == 0 && $line =~ /^(\s*\|)([^\|]+)/) ||
                    ($format > 0 && $line =~ /^(\s*\[)([^\[\]]*)([\]]{0,1})/))
            {
            my ($leading, $text, $len) = (length($1), $2, length($2));

            # Determine leading and rules length,
            #
            #   [] -    The ruler includes the opening brace and the
            #           optional closing brace.
            #
            #   | -     The ruler length is the field contained between
            #           the delimitors.
            #
            if ($format > 0)
                {
                $leading--;                     # Column include opening '['
                $len += ($3 eq ']' ? 2 : 1);    # plus options closing ']'
                }

            $pos += $leading;                   # increment cursor past leading text

            $col++;                             # new column

            my $cell = $self->HeaderField ($col, $pos, ($pos + $len) - 1);

            if ($text =~ /^[-]+$/)              # null field ?
                {
                $cell->IsNull(1);
                }
            else
                {
                $cell->{C_LINE} = Compress($text);
                }

                                                # remove definition
            $line = substr($line, $leading + $len);

            $pos += $len;                       # increment cursor past field
            }
        }

    # Summary/description text
    elsif ($self->{CURSOR} == 0 && $line !~ /^\s*[-+\!]/)
        {
        if (length($line))
            {
            $self->{SUMMARY} .= ' '             # delimiter
                if (defined($self->{SUMMARY}));
            $self->{SUMMARY} .= $line;          # concat
            }
        }

    # Otherwise field text
    else
        {
        my ($row) = $self->{CURSOR};

        my ($pos, $col, $cell) = (0, 1, undef); # working vars

        my ($newrow) = -1;

        # If the line leading delimiter (-+) introduce a new line
        # plus if the first line disable ! delimiter processing.

        if ($line =~ /^\s*[-+]+\s*$/)
            {
            if (0 == $self->{ROWS})             # special, first line ignore
                {
                $self->{FORMAT} = 0;            # disable extensions
                return;
                }
            $newrow = 0;
            }

        # If the line starts with a row delimitor (bang)

        elsif ($self->{FORMAT} >= 1 && $line =~ /^(\s*\!)/)
            {
            $newrow = length($1);
            }

        # Introduce a new row

        if ($newrow >= 0)
            {
            # End previous row and start new

            $row = $self->RowEnd ();            # new row

            # Build new row using current ruler

            while ($pos < $self->{MAXWIDTH} && $col <= $self->{COLS})
                {                               # who owns this column?
                for (my $t_col = 1; ! $cell && $t_col <= $self->{COLS}; $t_col++)
                    {
                    if (my $t_cell = $self->Cell($row - 1, $t_col))
                        {
                        if ($pos >= $t_cell->Start() && $pos <= $t_cell->End())
                            {
                            $cell = $t_cell->Clone();
                            }
                        }
                    }

                if ($cell)
                    {                           # parent
                    $pos = $cell->End () + 1;
                    $self->CellSet($row, $col, $cell);
                    $cell = undef;
                    $col++;
                    }

                $pos++;
                }

            # Seed scanner point
            return if ($newrow < 0);            # consume line

            $pos = $newrow;                     # skip bang
            }

        # Add text to columns, note that the columns can be either header
        # cell or standard cells.

        ($col, $cell) = (1, undef);

LOOP:   while ($pos < $length)
            {
            # Next cell

            while (! defined $cell || $pos > $cell->End())
                {
                $cell = $self->Cell ($row, $col++);

                last LOOP if (! $cell);

                $pos = $cell->Start()           # seek field start
                    if ($pos < $cell->Start());
                }

            # Populate field

            my $len = ($cell->End() - $pos) + 1;
            my $text = substr($line, $pos, $len);

            if (length($text))
                {                               # close previous line
                push @{$cell->{C_LINES}}, $cell->{C_LINE}
                    if (defined $cell->{C_LINE});

                if (defined $cell->{C_LINES} &&
                        ($cell->{C_BREAK} || $cell->IsHead()))
                    {                           # new paragraph or header line
                    push @{$cell->{C_LINES}}, "\n";
                    }

                $cell->{C_LINE} = $text;
                $cell->{C_BREAK} = 0;
                }
            else
                {
                $cell->{C_BREAK} = 1;
                }

            $pos += $len;                       # end of field
            }

        # For missing cells, force a paragraph break

        while ($col <= $self->{COLS})
            {
            $cell = $self->Cell ($row, $col++);

            $cell->{C_BREAK} = 1
                if (defined $cell);
            }
        }
    }


#
#   Function:       ParseLineSIMPLE
#       Table line parser
#
sub ParseLineSIMPLE
    {
    my ($self, $line) = @_;

    # Leading delimiter

    return if ($line !~ /^(\s*)(\|)/);

    my ($length) = length($line);

    # Header

    if (0 == $self->{CURSOR} && $self->{HEADER})
        {
        # End previous row and start new

        $self->RowEnd ();
        $self->HeaderStart (0, $length);

        # Build header cells

        my ($pos, $col) = (0, 0);

        while ($line =~ /^(\s*)\|([^\|]+)/)
            {
            my ($leading, $text, $len) = (length($1) + 1, $2, length($2));

            $col++;                             # new column

            $pos += $leading;                   # inc cursor past leading text

            my $cell = $self->HeaderField ($col, $pos, ($pos + $len) - 1);

            if ($text =~ /^[-]+$/)              # null field ?
                {  $cell->IsNull(1);  }
            else
                {  $cell->{C_LINE} = Compress($text);  }

                                                # remove definition
            $line = substr($line, $leading + $len);
            $pos += $len;                       # inc cursor past field
            }
        }

    else
        {
        # End previous row and start new

        my $row = $self->RowEnd ();             # new row

        # Populate cells

        my @fields = split (/\|/, $line);

        shift @fields;

        for (my $col = 1; scalar @fields; $col++)
            {
            my $cell;

            # Create cell, CSV table maybe created without a ruler.

            if (0 == $self->{RULER_COLS})
                {  $cell = NaturalDocs::Parser::TableCell->New ();  }
            else
                {
                $cell = $self->Cell ($row - 1, $col);
                $cell = ($cell ? $cell->Clone () : NaturalDocs::Parser::TableCell->New ());
                }

            $self->CellSet ($row, $col, $cell);

            # Cell value

            my $field = shift @fields;

            if ($field =~ /^(\s*)\{/)           # grouped ?
                {
                #
                #   Undocumented!
                #
                my $nesting = 1;

                $field = substr($field, length($1) + 1);
                do {
                    my $len = length($field);

                    # last field
                    if ($field =~ /\}(\s*)$/)   # group termination
                        {
                        $field = substr($field, 0, $len - (length($1) + 1));
                        $nesting--;
                        }

                    # field text
                    push @{$cell->{C_LINES}}, "\n"
                        if (scalar @{$cell->{C_LINES}});

                    push @{$cell->{C_LINES}}, $field;
                    }
                while ($nesting && ($field = shift @fields));
                }
            else                                # standard
                {
                push @{$cell->{C_LINES}}, $field;
                }
            }
        }
    }


#
#   Function:       ParseLineCSV
#       Table line parser
#
sub ParseLineCSV
    {
    my ($self, $line, $break) = @_;
    my ($length) = length ($line);

    # Continuation

#needs work
#   if (! $break && $line =~ /(\"\s*)$/)
#       {                                       # open quote
#       $self->{CACHE} .= $line;
#       return;
#       }
#   if ($self->{CACHE})
#       {
#       $line = $self->{CACHE} . $line;
#       $self->{CACHE} = undef;
#       }

    return if ($line =~ /^\s*$/);               # blank line, ignore

    # New Line

    if (0 == $self->{CURSOR} && $self->{HEADER})
        {
        # Ruler limits

        $self->RowEnd ();
        $self->HeaderStart (0, $length);

        # Build header cells

        my ($pos, $col) = (0, 0);

        my $fields = $self->ParseCSV ($line);

        for (my $col = 1; scalar @$fields; $col++)
            {
            my $text = shift @$fields;
            my $len = length($text);

            my $cell = $self->HeaderField($col, $pos, ($pos + $len) - 1);

            if ($text =~ /^[-]+$/)              # null field ?
                {  $cell->IsNull(1);  }
            else
                {  $cell->{C_LINE} = Compress($text);  }

            $pos += $len;                       # inc cursor past field
            }
        }

    # Data

    else
        {
        # End previous row and start new

        my $row = $self->RowEnd();              # new row

        # Populate cells

        my $fields = $self->ParseCSV ($line);

        for (my $col = 1; scalar @$fields; $col++)
            {
            my $cell;

            # Create cell, CSV table maybe created without a ruler.

            if (0 == $self->{RULER_COLS})
                {  $cell = NaturalDocs::Parser::TableCell->New ();  }
            else
                {
                $cell = $self->Cell ($row-1, $col);
                $cell = ($cell ? $cell->Clone () : NaturalDocs::Parser::TableCell->New ());
                }

            $self->CellSet ($row, $col, $cell);

            # Cell value

            push @{$cell->{C_LINES}}, shift @$fields;
            }
        }
    }


#
#   Function:   ParseCSV
#       Parse a CSV definition
#
sub
ParseCSV ($)
{
    my ($self, $text) = @_;
    my  @fields = ();

    # The regexp deals cleanly with all trailing whitespace, but also dealing
    # with opening whitespace makes it messy, hence simplify the issue.
    $text =~ s/^\s*//;                          # removing leading

    # Pull each and every field
    while ($text =~ m{
            # Either some non-quote/non-comma text
            ( [^",]+ ) ,? \s*
				
            # or ... a double-quoted field: (with "" allowed inside)
            # now a field is either, non-quotes or adjacent quote pairs
            | " ((?: [^"] | "")*) " \s* ,? \s*
									
            # or ... empty field
            | () , \s*
											
            }gx)                                # g=dont skip chars, x=ignore white/comments
        {
        if (defined $1)
            {
            push @fields, Trim ($1);
            }
        elsif (defined $2)
            {
            my $field;

            ($field = $2) =~ s/\"\"/\"/g;       # remove quoted double-quotes
            push @fields, Trim ($field);        # and whitespace
            }
        else
            {
            push @fields, "";
            }
        };

    return \@fields;
}
																									

#
#   Function:       ParseEnd
#       Table parser completion
#
sub ParseEnd
    {
    my ($self) = @_;

    $self->RowEnd ();
    }


#
#   Function:       AddReferences
#       Add link and image references contained within the cell(s)
#
sub AddReferences #(source)
{
    my ($self, $source, $topic) = @_;
    my ($rows, $cols) = ($self->Rows(), $self->Cols());

    # empty table?

    return undef
        if ($rows <= 0 || $cols <= 0);

    # links disabled?

    return
        if (! $self->{LINK});

    # Each row

    for (my $row = 1; $row <= $rows; $row++)
        {
        # Each column
        for (my $col = 1; $col <= $cols; $col++)
            {
            my $cell = $self->Cell($row, $col);

            if (defined $cell && ! $cell->IsNull())
                {
                my $body = $cell->ContentGet ();

                # Add references in the topic.

                if (defined $body)
                    {
                    while ($body =~ /<link target=\"([^\"]*)\" name=\"[^\"]*\" original=\"[^\"]*\">/g)
                        {
                        my $linkText = NaturalDocs::NDMarkup->RestoreAmpChars($1);
                        my $linkSymbol = NaturalDocs::SymbolString->FromText($linkText);

                        NaturalDocs::SymbolTable->AddReference(::REFERENCE_TEXT(), $linkSymbol,
                                            $topic->Package(), $topic->Using(), $source);
                        }

                    # Add images in the topic.

                    while ($body =~ /<img mode=\"[^\"]*\" target=\"([^\"]+)\" original=\"[^\"]*\">/g)
                        {
                        my $target = NaturalDocs::NDMarkup->RestoreAmpChars($1);
                        NaturalDocs::ImageReferenceTable->AddReference($source, $target);
                        }
                    }
                }
            }
        }
}


##############################################################################
#   Group:      Support Function

#
#   Function:       CellSet
#       Update the cell association.
#
sub CellSet #(row, col, cell)
    {
    my ($self, $row, $col, $cell) = @_;

    # Extend table (if required)
    $self->{ROWS} = $row
        if ($row > $self->{ROWS});

    $self->{COLS} = $col
        if ($col > $self->{COLS});

    # Assign
    $self->{RARRAY}[$row]->{CARRAY}[$col] = $cell;
    }


#
#   Function:       HeaderStart
#
#       Mark the start of new header or subheader definition.
#
sub HeaderStart #(indent, length)
    {
    my ($self, $indent, $length) = @_;

    $self->{MAXWIDTH} = $length                 # max line length
        if (! $self->{MAXWIDTH} || $length > $self->{MAXWIDTH});

    $self->{RULER_COLS} = 0;                    # reset ruler
    $self->{RULER_WIDTH} = ($length - $indent) + 1;
    }


#
#   Function:       HeaderField
#
#       Process a header field definition.
#
#       o Apply spanning rules.
#       o Update the cell width.
#
sub HeaderField #(col, cell, col, start, end)
    {
    my ($self, $col, $start, $end) = @_;

    $self->{RULER_COLS} += 1;                   # increment ruler width

    # Create cell

    my $cell = NaturalDocs::Parser::TableCell->New(1, $start, $end);

    $self->CellSet ($self->{CURSOR}, $col, $cell);

    # Apply spanning rules
    my $spanning = 1;

    if ($self->{CURSOR})
        {                                       # test against primary ruler
        while (my $t_cell = $self->Cell(1, $col + $spanning))
            {
            # if the subheader definitions crosses a field to its right,
            # increment the spanning count and inturn test the next field
            # for the same condition.
            last if ($cell->End() < $t_cell->Start());

            $spanning++;
            }
        }

    if ($spanning > 1)
        {
        $cell->Spanning($spanning);             # spanning count
        }

    return $cell;
    }


#
#   Function:       RowEnd
#
#       Table line completion
#
sub RowEnd
    {
    my ($self) = @_;

    # Increment cursor

    my $row = $self->{CURSOR};                   # current row (cursor)

    $self->{CURSOR} += 1;                        # increment cursor

    return 1 if (! $row);

    # Line caching

    $self->ParseLine ("", 1)
        if (defined $self->{CACHE});

    # foreach column with current header/subheader definition

    my $totalwidth = 0;

    for (my $col = 1; $col <= $self->{COLS}; $col++)
        {
        my $cell = $self->Cell($row, $col);

        # Generate missing cells

        if (! defined $cell)
            {                                   # past ruler
            next if ($col > $self->{RULER_COLS});

            $cell = $self->Cell ($row-1, $col)->Clone();
            $self->CellSet ($row, $col, $cell);
            }

        # Flush content and apply markups

        push @{$cell->{C_LINES}}, $cell->{C_LINE}
            if (defined $cell->{C_LINE});       # current line

        if (defined $cell->{C_LINES} && ! $cell->IsNull())
            {
            # Down the rabbit hole we go!

        #   if (! $self->Embedded())
        #       {
        #       print "FormatCell:\n";
        #       foreach (@{$cell->{C_LINES}})
        #           {
        #           print "$: '$_'\n";
        #           }
        #       print "\n";
        #       }

            my $body = NaturalDocs::Parser::Native->FormatBody($self->{FILE},
                            $cell->{C_LINES}, 0, scalar @{$cell->{C_LINES}}, $self->{TYPE}, 0);

            # Cleanup results

            $cell->ContentSet ($body);          # resulting body
            }

        # Calculate field width
        #   performed normally only on column headers, which are then
        #   inherited by all cloned children

        if ($self->{RULER_WIDTH} > 0)
            {
            my $width;

            if ($col == $self->{COLS} && $self->{FORMAT} == 1)
                { $width = 100 - $totalwidth; } # force width to 100%
            else
                {
                my $length = ($cell->End() - $cell->Start()) + 1;
                my $ruler = $self->{RULER_WIDTH};

                $width = ($length * 100) / $ruler;
                }

            $cell->Width ($width);
            $totalwidth += $width;
            }

        # Destroy local variables

        delete $cell->{C_BREAK};
        delete $cell->{C_LINE};
        }

    return $self->{CURSOR};
    }

																									
# Trim function to remove leading whitespace
#   ie. space, tab
#
sub
Trim($)
    {
    my $string = shift;

    $string =~ s/^[ \t]+//;                     # leading
    $string =~ s/[ \t]+$//;                     # trailing
    return $string;
    }


# Compress function to remove whitespace from the start and end of the
# string. and replace repeated white-spaces characters with a single space.
# ie. space, tab
#
sub
Compress($)
    {
    my $string = shift;

    $string =~ s/^[ \t]+//;                     # leading
    $string =~ s/[ \t]+$//;                     # trailing
    $string =~ s/[ \t]+/ /g;                    # repeating
    return $string;
    }

1;
