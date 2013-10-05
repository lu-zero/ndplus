# -*- mode: perl; indent-width: 4; -*-
###############################################################################
#
#   Package: NaturalDocs::Parser::TableCell
#
###############################################################################
#
#   A package that processes indentations within Natural Docs' native format.
#
###############################################################################

# This file is part of Natural Docs. Author Adam Young
# Natural Docs is licensed under the GPL

use strict;
use integer;

package NaturalDocs::Parser::TableCell;


###############################################################################
#   Group:      Interface Functions
#

#
#   Function:       New
#
#       Create and initialise a parsed table class.
#   
#   Parameters:
#       ishead -    Optional is header.
#
sub New #($ishead, $start, $end)
    {
    my ($self, $ishead, $start, $end) = @_;
    
    my ($object) = {};

    $object->{C_ISHEAD} = $ishead
        if (defined $ishead);

    $object->{C_START} = $start
        if (defined $start);

    $object->{C_END} = $end
        if (defined $end);

    $object->{C_LINES} = ();

    return bless $object, $self;
    }


#
#   Function:       Clone
#
#       Clone ourself based on the specified call style, 
#
#       The following cell attributes are copied during this process,
#           o C_START
#           o C_END 
#           o C_ISNULL 
#           o C_WIDTH
#
sub Clone
    {
    my ($self) = @_;

    my ($object) = NaturalDocs::Parser::TableCell->New();

    foreach my $key (qw(C_START C_END C_ISNULL C_SPANNING C_WIDTH))
        {
        $object->{$key} = $self->{$key}
            if (exists $self->{$key});
        }

    return $object;
    }


#
#   Function:       IsHead
#
sub IsHead #([ishead])
    {
    my ($self, $ishead) = @_;

    $self->{C_ISHEAD} = $ishead
        if (defined $ishead);

    return $self->{C_ISHEAD}
        if (exists $self->{C_ISHEAD});
    return 0;
    }


#
#   Function:       IsNull
#
sub IsNull #([isnull])
    {
    my ($self, $isnull) = @_;

    $self->{C_ISNULL} = $isnull
        if (defined $isnull);

    return $self->{C_ISNULL}
        if (exists $self->{C_ISNULL});
    return 0;
    }


#
#   Function:       Spanning
#
sub Spanning #([spanning])
    {
    my ($self, $spanning) = @_;

    $self->{C_SPANNING} = $spanning
        if (defined $spanning);

    return $self->{C_SPANNING}
        if (exists $self->{C_SPANNING});
    return 0;
    }


#
#   Function:       Width
#
sub Width #([width])
    {
    my ($self, $width) = @_;

    $self->{C_WIDTH} = $width
        if (defined $width);

    return $self->{C_WIDTH}
        if (exists $self->{C_WIDTH});
    return 0;
    }


#
#   Function:       Start
#
sub Start #([start])
    {
    my ($self, $start) = @_;

    $self->{C_START} = $start
        if (defined $start);
    return $self->{C_START};
    }


#
#   Function:       End
#
sub End #([end])
    {
    my ($self, $end) = @_;

    $self->{C_END} = $end
        if (defined $end);
    return $self->{C_END};
    }


#
#   Function:       ContentSet
#
sub ContentSet #([content])
    {
    my ($self, $content) = @_;

    $self->{C_CONTENT} = $content
        if (defined $content);
    return $self->{C_CONTENT};
    }


#
#   Function:       ContentGet
#
sub ContentGet
    {
    my ($self, $clean) = @_;

    return $self->{C_CONTENT}
        if (! $clean || ! $self->{C_CONTENT});

    my $text = $self->{C_CONTENT};

    # cleanup

    $text =~ s/^[ \t]+//;                       # leading
    $text =~ s/[ \t]+$//;                       # trailing
    $text =~ s/[ \t]+/ /g;                      # repeated

    $text =~ s/\\\[/[/g;                        # escaped ['s

    $text =~ s/<p>//g;                          # remove paragraphs
    $text =~ s/<\/p>/\n/g;

    $text =~ s/\n+/\n/g;                        # repeated new-lines
    $text =~ s/\n/<br>/g;                       # convert breaks

    return $text;
    }

1;
