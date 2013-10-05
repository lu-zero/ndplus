# -*- mode: perl; indent-width: 4; -*-
###############################################################################
#
#   Package: NaturalDocs::Parser::Indent
#
###############################################################################
#
#   A package that processes indentations within Natural Docs' native format.
#
###############################################################################

# This file is part of Natural Docs. Author Adam Young
# Natural Docs is licensed under the GPL

use strict;

package NaturalDocs::Parser::Indent;

###############################################################################
#   Group:      Interface Functions
#

#
#   Function:   New
#
#       Create and initialise an indent control class.
#
#   Parameters:
#
#       file -          The <ParsedFile> object of the source file being parsed.
#
#       lineEnders -    An arrayref of the NDMarkup tags used as line closures.
#
#       tagEnders -     An arrayref of the NDMarkup tags used as tag closures.
#
#       tagDesc -       An arrayref of the NDMarkup tag descriptions
#
#
sub New #(file, lineEnders, tagEnders, tagDesc)
    {
    my ($self, $file, $lineEnders, $tagEnders, $tagDesc) = @_;

    my $indent;
    my $auto = 1;

    $indent = NaturalDocs::Settings->TabLength();

    if (defined $file)
        {
        $indent = $file->Modeline('indent');    # modeline specification, if any.

        if (! defined $indent || $indent <= 1) 
            {
            my $language = $file->Language();

            if (defined ($language))
                {
                if (defined $language->IndentLength())
                    {  $indent = $language->IndentLength();  }

                elsif (defined $language->TabLength())
                    {  $indent = $language->TabLength();  }
                }
            };

        $auto = $file->Modeline('lvl', $auto);
        };

    $indent = 8                                 # default
        if (! defined $indent || $indent <= 1);

    my (@stack) = ();
    my ($object) = {
            INDENTDEFAULT => $indent,           # Indentation settings
            LINEENDERS => $lineEnders,          # Markup closures for element.
            TAGENDERS => $tagEnders,            # Markup closures for session.
            TAGDESC => $tagDesc,                # Markup identifiers
            AUTO => $auto,                      # Whether automatic indentation should occur.
            INDENT => $indent,                  # Automatic indentation threshold, cleared on override.
            COLUMN => 0,                        # Current column.
            STACK => \@stack,                   # Indentation stack (COLUMN/LEVEL).
            PRETTY => 1                         # Format output based on identation
        };

    return bless $object, $self;
    }

#
#   Function:   Reset
#
#       Reset the state 
#
sub Reset ($self)
{
    my ($self) = @_;

    $self->{COLUMN} = 0;
    $self->{INDENT} = ($self->{AUTO} ? $self->{INDENTDEFAULT} : 0);
}


#
#   Function:   Process
#
#       Process the current indentation level, either increase or decrease as required.
#
#   Parameters:
#
#       column -        Current starting column.
#
#       currTagRef -    IntegerRef containing the tag of the current parse status.
#
#       newTag -        New tag being applied
#
#       type -          Optional tag text
#
#   Returns:
#       Output string
#
sub Process #currTag, newTag, column, type)
    {
    my ($self, $currTagRef, $newTag, $column, $type) = @_;

    my $currTag = $$currTagRef;                 # current tag

    # Close off previous

    if (! defined ${$self->{LINEENDERS}}{$currTag})
        {
        $self->{COLUMN} = $column;              # save column position

        return "";                              # not an indentible type
        }

    my $output = ${$self->{LINEENDERS}}{$currTag};
    
    # Auto indentation

    my $stack = $self->{STACK};
    my $increase = 0;

    if ($self->{INDENT})
        {
        # Indent out, at most one level

        if ($self->CanIncrease ($column, $type))
            {
            $increase = 1;
            }

        # Ident in, one or more levels

        elsif (scalar @$stack && $self->CanDecrease ($column, $type))
            {
            my $indent = @$stack [scalar @$stack-1];

            ($indent->{TAG} == $currTag) or
                die "Ident::Process: currTag disagree ($indent->{TAG} != $currTag)\n";

            do {
                # Unstack level

                $output .= $self->Pop ($currTagRef);

                } while (scalar @$stack && $self->CanDecrease ($column, $type));
            }
        }

    # Is the type changing at the current/restored level

    if (! $increase && scalar @$stack)
        {
        if ($currTag != $newTag)
            {
            $output .= $self->Pop ($currTagRef);

            $increase = 1;                      # generate a 'new' tag
            }
        }

    # Increase identation by one

    if ($increase)
        {
        $self->Push ($$currTagRef, $newTag);    # create new level

        $$currTagRef = 0;                       # force a new closure (NEW)
        }

    $self->{COLUMN} = $column;                  # new column

    $output .= "\n" . ("\t" x (scalar @$stack))
        if ($self->{PRETTY});

    return $output;
    }

#
#   Function:   Markup
#
#       Return the markup string representing the current indentation level.
#
#   Returns:
#       Output string.
#
sub Markup
    {
    my ($self) = @_;
    my $output = "";

    my $level = $self->{LEVEL};

    if ($level > 0)
        {
        my $stack = $self->{STACK};
        my $indent = @$stack[$level-1];

        ($indent->{TAG} < 0) or
            die "Ident::Markup: not a new level ($indent->{TAG})\n";

        $indent->{TAG} = $indent->{TAG} * -1;

        $output .= '<' . $indent->{DESC} . 'Indent'. $level. '>';
        }

    $output .= "\n"."\t"x$level
        if ($self->{PRETTY});

    return $output;
    }


#
#   Function:   End
#       End any current indentation(s).
#
#   Parameters:
#       currTag -       Current the parse tag.
#
#   Returns:
#       Output string.
#
sub End #(currTag)
    {
    my ($self, $currTag) = @_;

    my $stack = $self->{STACK};
    my $output = "";

    # Close off element

    if (defined ${$self->{LINEENDERS}}{$currTag})
        {
        $output .= ${$self->{LINEENDERS}}{$currTag};
        }

    $output .= "\n"
        if ($self->{PRETTY});

    # Unnest levels (if any)

    while (scalar @$stack)
        {
        $output .= $self->Pop (\$currTag);
        }

    $output .= ${$self->{TAGENDERS}}{$currTag};

    # Reset class

    $self->Reset ();

    return $output;
    }


#
#   Function:   Auto
#       Enable/disable automatic indentation processing.
#
#   Parameters:
#       status -        True is enabled.
#
#   Returns:
#       True or False.
#
sub Manual #(status)
    {
    my ($self, $status) = @_;

    if (($self->{AUTO} = $status) && $self->{LEVEL} == 0)
        {
        $self->{INDENT} = $self->{INDENTDEFAULT};
        }
    }

#   Function:   Increase
#       Manually increase the indentation level.
#
#   Returns:
#       Nothing
#
sub Increase
    {
    my ($self) = @_;

    $self->{INDENT} = 0;                        # disable auto indentation

    $self->{LEVEL}++;                           # inc level, next process shall nest
    }


#   Function:   Decrease
#
#       Manually decrease the indentation level.
#
#   Parameters:
#       currTagRef -    IntegerRef containing the tag of the current parse status.
#
#   Returns:
#       Output string
#
sub Decrease #(currTagRef)
    {
    my ($self, $currTagRef) = @_;
    
    my $stack = $self->{STACK};
    my $tagEnders = $self->{TAGENDERS};
    my $output = undef;

    if ($self->{LEVEL} > 0)
        {
        # Pop level, decrease by one

        if ($self->{LEVEL} <= scalar @$stack)
            {
            $output .= ${$self->{LINEENDERS}}{$$currTagRef};
            $output .= $self->Pop ($currTagRef);
            }

        # If we have decreased to the top most level, reset INDENT

        if (! scalar @$stack)
            {
            $self->Reset ();
            }
        }

    return $output;
    }


#private
#
#   Function:   Push
#       Initialise a new indentation
#
sub Push #(currTag, newTag)
    {
    my ($self, $currTag, $newTag) = @_;
    my $stack = $self->{STACK};

    my $indent = {
            PREV    => $currTag,                # tag being indented
            COLUMN  => $self->{COLUMN},         # column being indented
            TAG     => -$newTag,                # new tag, converted for r/t assert
            DESC    => ${$self->{TAGDESC}}{$newTag}
            };

    push @$stack, $indent;

    $self->{LEVEL} = scalar @$stack;
}


#private
#   
#   Function:   Pop
#       Pop the current level
#
#   Parameters:
#       currTag -       IntegerRef containing the tag of the current parse status.
#
#   Returns:
#       Output string
#
#
sub Pop #(currTag)
    {
    my ($self, $currTag) = @_;

    my $stack = $self->{STACK};
    my $level = scalar @$stack;
    my $output = "";

    if ($level)
        {
        my $indent = pop @$stack;               # level

        $output .= "\n" . ("\t" x $level)
            if ($self->{PRETTY});

        $output .= '</' . $indent->{DESC} . 'Indent'. $level. '>' . 
                                ${$self->{TAGENDERS}}{$indent->{TAG}};

        $self->{COLUMN} = $indent->{COLUMN};    # restored cursor positioned

        $$currTag = $indent->{PREV}             # restored tag
            if (defined $currTag);
        }

    $self->{LEVEL} = scalar @$stack;            # new level

    return $output;
    }


#private
#
#   Function:   CanIncrease
#       Determine if the identation level can be increased.
#
#   Parameters:
#       column -        Current starting column.
#       type -          Indentation specification, if given using dot notation 
#                           the level is explicity driven by the dot count.
#
#   Returns:
#       True or False.
#
sub CanIncrease
    {
    my ($self, $column, $type) = @_;
    my (@levels) = split (/\./, $type);         # count dots

    if (scalar @levels > 1)
        {                                       # dotted
        $self->{INDENT} = -1;
        return ((scalar @levels)-1 > $self->{LEVEL});
        }

    if ((my $indent = $self->{INDENT}) > 0)
        {                                       # otherwise column
        return ($column/$indent > $self->{COLUMN}/$indent);
        }

    return 0;
    }


#private
#
#   Function:   CanDecrease
#       Determine if the identation level can be decreased.
#
#   Parameters:
#
#       column -        Current starting column.
#
#   Returns:
#       True or False.
#
sub CanDecrease
    {
    my ($self, $column, $type) = @_;
    my (@levels) = split (/\./, $type);

    if (scalar @levels > 1)
        {                                       # dotted
        $self->{INDENT} = -1;
        return ((scalar @levels)-1 < $self->{LEVEL});
        }

    if ((my $indent = $self->{INDENT}) > 0)
        {                                       # otherwise column
        return ($column/$indent < $self->{COLUMN}/$indent);
        }

    return 0;
    }

1;

