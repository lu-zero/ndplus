# -*- mode: perl; indent-width: 4; -*-
###############################################################################
#
#   Package: NaturalDocs::Parser::Native
#
###############################################################################
#
#   A package that converts comments from Natural Docs' native format into <NaturalDocs::Parser::ParsedTopic> objects.
#   Unlike most second-level packages, these are packages and not object classes.
#
###############################################################################

# This file is part of Natural Docs, which is Copyright (C) 2003-2008 Greg Valure
# Portions Copyright (C) 2008-2013 Adam Young
# Natural Docs is licensed under the GPL

use NaturalDocs::Parser::Table;
use NaturalDocs::Parser::TableCell;
use NaturalDocs::Parser::Indent;

use strict;
use integer;

package NaturalDocs::Parser::Native;


###############################################################################
# Group: Variables


# Return values of TagType().  Not documented here.
use constant POSSIBLE_OPENING_TAG => 1;
use constant POSSIBLE_CLOSING_TAG => 2;
use constant NOT_A_TAG => 3;


#
#   var: package
#
#   A <SymbolString> representing the package normal topics will be a part of at the current point in the file.  This is a package variable
#   because it needs to be reserved between function calls.
#
my $package;


#
#   hash: functionListIgnoredHeadings
#
#   An existence hash of all the headings that prevent the parser from creating function list symbols.  Whenever one of
#   these headings are used in a function list topic, symbols are not created from definition lists until the next heading.  The keys
#   are in all lowercase.
#
my %functionListIgnoredHeadings = ( 'parameters' => 1,
                                    'parameter' => 1,
                                    'params' => 1,
                                    'param' => 1,
                                    'arguments' => 1,
                                    'argument' => 1,
                                    'args' => 1,
                                    'arg' => 1 );

my %admonitions = ( 'tip'  => 1,                        #ND+ admonitions, TODO configuration
                    'note' => 1,
                    'example' => 1,
                    'important' => 1,
                    'warning' => 1,
                    'caution' => 1 );

###############################################################################
# Group: Interface Functions


#
#   Function: Start
#
#       This will be called whenever a file is about to be parsed.  It allows the package to reset its internal state.
#
sub Start #(FileName file)
    {
    my ($self, $file) = @_;
    $package = undef;
    };


#
#   Function: IsMine
#
#   Examines the comment and returns whether it is *definitely* Natural Docs content, i.e. it is owned by this package.  Note
#   that a comment can fail this function and still be interpreted as a Natural Docs content, for example a JavaDoc-styled comment
#   that doesn't have header lines but no JavaDoc tags either.
#
#   Parameters:
#
#       commentLines - An arrayref of the comment lines.  Must have been run through <NaturalDocs::Parser->CleanComment()>.
#       isJavaDoc - Whether the comment was JavaDoc-styled.
#
#   Returns:
#
#       Whether the comment is *definitely* Natural Docs content.
#
sub IsMine #(string[] commentLines, bool isJavaDoc)
    {
    my ($self, $commentLines, $isJavaDoc) = @_;

    # Skip to the first line with content.
    my $line = 0;

    while ($line < scalar @$commentLines && !length $commentLines->[$line])
        {  $line++;  };

    return $self->ParseHeaderLine($commentLines->[$line]);
    };


#
#   Function: ParseComment
#
#       This will be called whenever a comment capable of containing Natural Docs content is found.
#
#   Parameters:
#
#       file - The <ParsedFile> object of the source file being parsed.
#       commentLines - An arrayref of the comment lines.  Must have been run through <NaturalDocs::Parser->CleanComment()>.
#                               *The original memory will be changed.*
#       isJavaDoc - Whether the comment is JavaDoc styled.
#       lineNumber - The line number of the first of the comment lines.
#       parsedTopics - A reference to the array where any new <NaturalDocs::Parser::ParsedTopics> should be placed.
#
#   Returns:
#
#       The number of parsed topics added to the array, or zero if none.
#
sub ParseComment #(file, commentLines, isJavaDoc, lineNumber, parsedTopics)
    {
    my ($self, $file, $commentLines, $isJavaDoc, $lineNumber, $parsedTopics) = @_;

    my $topicCount = 0;
    my $prevLineBlank = 1;
    my $inCodeSection = 0;

    my ($type, $scope, $isPlural, $title, $symbol);

    my ($newKeyword, $newTitle);
    my $inPrototype;                            #ND+, prototype
    my @codeLines;

    my $index = 0;

    my $bodyStart = 0;
    my $bodyEnd = 0;                            # Not inclusive.

    while ($index < scalar @$commentLines)
        {
        # Everything but leading whitespace was removed beforehand.

        # If we're in a code section...
        if ($inCodeSection)
            {                                   #ND+, ditaa/mscgen/sdedit
            if ($commentLines->[$index] =~ /^ *\( *(?:end|finish|done)(?: +(?:table|code|example|diagram|ditaa|mscgen|sdedit))? *\)$/i)
                {  $inCodeSection = undef;  };

            $prevLineBlank = 0;
            $bodyEnd++;
            }

        # If the line is empty...
        elsif (!length($commentLines->[$index]))
            {
            $prevLineBlank = 1;

            if ($topicCount)
                {  $bodyEnd++;  };
            }

        # If the line has a recognized header and the previous line is blank...
        elsif ($prevLineBlank && (($newKeyword, $newTitle) = $self->ParseHeaderLine($commentLines->[$index])) )
            {
            # Process the previous one, if any.

            if ($topicCount)
                {
                if ($scope == ::SCOPE_START() || $scope == ::SCOPE_END())
                    {  $package = undef;  };

                my $body = $self->FormatBody($file, $commentLines, $bodyStart, $bodyEnd, $type, $isPlural);
                my $newTopic = $self->MakeParsedTopic($type, $title, $package, $body, $lineNumber + $bodyStart - 1, $isPlural);
                push @$parsedTopics, $newTopic;

                if (scalar @codeLines)          #ND+, prototype
                    {
                    $newTopic->SetPrototype( "@codeLines" )
                        if (scalar @codeLines);
                    @codeLines = ();
                    $inPrototype = 0;
                    }

                $package = $newTopic->Package();
                };

            $title = $newTitle;

            my $typeInfo;
            ($type, $typeInfo, $isPlural) = NaturalDocs::Topics->KeywordInfo($newKeyword);
            $scope = $typeInfo->Scope();

            $bodyStart = $index + 1;
            $bodyEnd = $index + 1;

            $topicCount++;

            $prevLineBlank = 0;
            }

        # If we're on a non-empty, non-header line of a JavaDoc-styled comment and we haven't started a topic yet...
        elsif ($isJavaDoc && !$topicCount)
            {
            $type = undef;
            $scope = ::SCOPE_NORMAL();          # The scope repair and topic merging processes will handle if this is a class topic.
            $isPlural = undef;
            $title = undef;
            $symbol = undef;

            $bodyStart = $index;
            $bodyEnd = $index + 1;
            }

        # Embedded "Prototype:"                 #ND+, prototype
        elsif ($inPrototype)
            {
            if ($commentLines->[$index] =~ /^ *[a-z0-9]*[a-z0-9 ]*: *$/i)
                {                               # .. header terminate
                $inPrototype = 0;
                }
            elsif ($commentLines->[$index] =~ /^ *\( *(end|finish|done)(?: +(?:prototype|synopsis))? *\)$/i)
                {                               # .. end marker
                $inPrototype = 0;
                $commentLines->[$index] = "";
                }
            else
                {
                push @codeLines, $commentLines->[$index];
                $commentLines->[$index] = "";   # remove from image
                }
            $prevLineBlank = undef;
            $bodyEnd++;
            }

        elsif ($commentLines->[$index] =~ /^ *(Prototype|Synopsis) *: *$/i &&
                    $file->Modeline('proto', 1))
            {
            $inPrototype = 1;                   # FIXME, config keyword
            $commentLines->[$index] = "";       # remove from image
            $prevLineBlank = undef;
            $bodyEnd++;
            }

        # If we're on a normal content line within a topic
        elsif ($topicCount)
            {
            $prevLineBlank = 0;
            $bodyEnd++;
                                                #ND+, ditaa/mscgen/sdedit
            if ($commentLines->[$index] =~ /^ *\( *(?:(?:start|begin)? +)(?:ditaa|mscgen|sdedit)([^\)]*)\)$/i)
                {  $inCodeSection = 1;  }
                                                #ND+, prototype
            elsif ($commentLines->[$index] =~ /^ *\( *(?:(?:start|begin)? +)?(?:table|code|example|diagram) *\)$/i)
                {  $inCodeSection = 1;  }
            };


        $index++;
        };


    # Last one, if any.  This is the only one that gets the prototypes.
    if ($bodyStart)
        {
        if ($scope == ::SCOPE_START() || $scope == ::SCOPE_END())
            {  $package = undef;  };

        my $body = $self->FormatBody($file, $commentLines, $bodyStart, $bodyEnd, $type, $isPlural);
        my $newTopic = $self->MakeParsedTopic($type, $title, $package, $body, $lineNumber + $bodyStart - 1, $isPlural);
        push @$parsedTopics, $newTopic;
        $topicCount++;

        if (scalar @codeLines)                  #ND+, prototype
            {  $newTopic->SetPrototype( "@codeLines" );  }

        $package = $newTopic->Package();
        };

    return $topicCount;
    };


#
#   Function: ParseHeaderLine
#
#   If the passed line is a topic header, returns the array ( keyword, title ).  Otherwise returns an empty array.
#
sub ParseHeaderLine #(line)
    {
    my ($self, $line) = @_;

    if ($line =~ /^ *([a-z0-9 ]*[a-z0-9]): +(.*)$/i)
        {
        my ($keyword, $title) = ($1, $2);

        # We need to do it this way because if you do "if (ND:T->KeywordInfo($keyword)" and the last element of the array it
        # returns is false, the statement is false.  That is really retarded, but there it is.
        my ($type, undef, undef) = NaturalDocs::Topics->KeywordInfo($keyword);

        if ($type)
            {  return ($keyword, $title);  }
        else
            {  return ( );  };
        }
    else
        {  return ( );  };
    };



###############################################################################
# Group: Support Functions


#
#   Function: MakeParsedTopic
#
#   Creates a <NaturalDocs::Parser::ParsedTopic> object for the passed parameters.  Scope is gotten from
#   the package variable <package> instead of from the parameters.  The summary is generated from the body.
#
#   Parameters:
#
#       type            - The <TopicType>.  May be undef for headerless topics.
#       title           - The title of the topic.  May be undef for headerless topics.
#       package         - The package <SymbolString> the topic appears in.
#       body            - The topic's body in <NDMarkup>.
#       lineNumber      - The topic's line number.
#       isList          - Whether the topic is a list.
#
#   Returns:
#
#       The <NaturalDocs::Parser::ParsedTopic> object.
#
sub MakeParsedTopic #(type, title, package, body, lineNumber, isList)
    {
    my ($self, $type, $title, $package, $body, $lineNumber, $isList) = @_;

    my $summary;

    if (defined $body)
        {  $summary = NaturalDocs::Parser->GetSummaryFromBody($body);  };

    return NaturalDocs::Parser::ParsedTopic->New($type, $title, $package, undef, undef, $summary,
                                                $body, $lineNumber, $isList);
    };


#
#    Function: FormatBody
#
#       Converts the section body to <NDMarkup>.
#
#    Parameters:
#
#       file            - The <ParsedFile> object of the source file being parsed;
#                               it may undef if within a page footer/header or table.
#       commentLines    - The arrayref of comment lines.
#       startingIndex   - The starting index of the body to format.
#       endingIndex     - The ending index of the body to format, *not* inclusive.
#       type            - The type of the section.  May be undef for headerless comments.
#       isList          - Whether it's a list topic.
#
#    Returns:
#
#        The body formatted in <NDMarkup>.
#
sub FormatBody #(file, commentLines, startingIndex, endingIndex, type, isList)
    {
    my ($self, $file, $commentLines, $startingIndex, $endingIndex, $type, $isList) = @_;

    use constant TAG_NEW => 0;
    use constant TAG_NONE => 1;
    use constant TAG_PARAGRAPH => 2;
    use constant TAG_BULLETLIST => 3;
    use constant TAG_DESCRIPTIONLIST => 4;
    use constant TAG_ORDEREDLIST => 5;
    use constant TAG_HEADING => 6;
    use constant TAG_PREFIXCODE => 7;
    use constant TAG_CODE => 8;
    use constant TAG_DITAA => 9;
    use constant TAG_DRAWING => 10;
    use constant TAG_MSCGEN => 11;
    use constant TAG_SDEDIT => 12;
    use constant TAG_ADMONITION => 13;
    use constant TAG_QUOTE => 14;

    my %lineEnders = (
            TAG_BULLETLIST() => '</li>',
            TAG_DESCRIPTIONLIST() => '',    #</dd> not required + causes HTML issues
            TAG_ORDEREDLIST() => '</li>');

    my %tagEnders = (   
            TAG_NEW() => '',                #ND+, ordered/ditaa/ededit
            TAG_NONE() => '',
            TAG_PARAGRAPH() => '</p>',
            TAG_BULLETLIST() => '</ul>',
            TAG_DESCRIPTIONLIST() => '</dl>',
            TAG_ORDEREDLIST() => '</ol>',
            TAG_HEADING() => '</h>',
            TAG_PREFIXCODE() => '</prefixcode>',
            TAG_CODE() => "\n</code>",
            TAG_DITAA() => "\n</ditaa>",
            TAG_DRAWING() => "\n</drawing>",
            TAG_SDEDIT() => "\n</sdedit>",
            TAG_MSCGEN() => "\n</mscgen>",
            TAG_QUOTE() => "\n</quote>");

    my %tagDescs = (    
            TAG_BULLETLIST() => 'Bullet',
            TAG_DESCRIPTIONLIST() => 'Desc',
            TAG_ORDEREDLIST() => 'Ordered');

    my $currTag = TAG_NONE;

    my $output;
    my $textBlock;
    my @textBlocks = ();

    my $prevLineBlank = 1;
                                                #ND+, indent
    my $indent = NaturalDocs::Parser::Indent->New($file, \%lineEnders, \%tagEnders, \%tagDescs);

    my $table;                                  #ND+, table
    my $tabletype = ($type eq 'table' ? 1 : ($type eq 'tableEmbedded' ? 2 : 0));

                                                #ND+, inline code mode; disabled within tables
    my $inlinemode = ($tabletype ? 0 : ($file ? $file->Modeline('code', 1) : 1));

    my $codeBlock;
    my $admonition = '';
    my $removedCodeSpaces;

    my $ignoreListSymbols;

    my $index = $startingIndex;

    while ($index < $endingIndex)
        {                                       #ND+, parser
        my $commentLine = $commentLines->[$index];      

        # If we're in a table...
        if ($table)
            {
            if ($commentLine =~ /^ *\( *(?:end|finish|done)(?: +(?:table))? *\)$/i)
                {
                $table->ParseEnd();
                $table = undef;
                }
            else
                {
                my $blank = ($commentLine =~ /^\s*$/);

                if ($tabletype >= 1 && ! $blank)
                    {
                    if ($prevLineBlank)
                        {  $commentLine = '!' . $commentLine;  }
                    else
                        {  $commentLine = ' ' . $commentLine;  }
                    }

                $table->ParseLine($commentLine);
                $prevLineBlank = $blank;
                }
            }

        # If we're in a tagged section, code, ditaa, mscgen, sdedit or drawing
        elsif ($currTag == TAG_CODE || $currTag == TAG_QUOTE ||
                    $currTag == TAG_DITAA || $currTag == TAG_DRAWING || $currTag == TAG_MSCGEN || $currTag == TAG_SDEDIT)
            {                                   #ND+, ditaa/mscgen/sdedit/drawing
            if ($commentLine =~ /^ *\( *(?:end|finish|done)(?: +(?:table|code|example|diagram|ditaa|mscgen|sdedit|drawing))? *\)$/i)
                {
                if (defined $codeBlock)
                    {
                    $codeBlock =~ s/\n+$//;
                    if ($currTag == TAG_CODE || $currTag == TAG_QUOTE)
                        {  $output .= NaturalDocs::NDMarkup->ConvertAmpChars($codeBlock);  }
                    else
                        {  $output .= $codeBlock;  }
                    $codeBlock = undef;
                    }
                $output .= $tagEnders{$currTag};
                $currTag = TAG_NONE;
                $prevLineBlank = undef;
                }
            else
                {
                if ($currTag == TAG_DRAWING || $currTag == TAG_QUOTE)
                    { $codeBlock .= $commentLine . "\n"; }
                else
                    { $self->AddToCodeBlock($commentLine, \$codeBlock, \$removedCodeSpaces); }
                }
            }

        elsif ($admonition && $commentLine =~ /^ *\(end!\) *$/i)
            {
            $output .= $admonition;
            $admonition = '';
            }

        # If the line starts with a code designator...
        elsif ((1 == $inlinemode && $commentLine =~ /^ *[>:|](.*)$/) ||
                    (2 == $inlinemode && $commentLine =~ /^[>:|](.*)$/))
            {
            my $code = $1;

            $output .= $admonition;
            $admonition = '';

            if ($currTag == TAG_PREFIXCODE)
                {
                $self->AddToCodeBlock($code, \$codeBlock, \$removedCodeSpaces);
                }
            else    #$currTag != TAG_PREFIXCODE
                {
                if (defined $textBlock)
                    {
                    $output .= $self->RichFormatTextBlock($textBlock);
                    $textBlock = undef;
                    };

                $output .= $indent->End($currTag) . '<prefixcode>';
                $currTag = TAG_PREFIXCODE;

                $self->AddToCodeBlock($code, \$codeBlock, \$removedCodeSpaces);
                };
            }

        # If we're not in a tagged section nor table...
        else
            {
            # Strip any leading whitespace.
            my $column = 0;

            $column = length ($1)               #ND+, indent
                if ($commentLine =~ s/^(\s+)//);

            # If we were in a prefixed code section...
            if ($currTag == TAG_PREFIXCODE)
                {
                if (defined $codeBlock)
                    {
                    $codeBlock =~ s/\n+$//;
                    $output .= NaturalDocs::NDMarkup->ConvertAmpChars($codeBlock);
                    $codeBlock = undef;
                    }
                $output .= $tagEnders{$currTag};
                $currTag = TAG_NONE;
                $prevLineBlank = undef;
                };

            # If the line is blank...
            if (!length($commentLine))
                {
                # End a paragraph.  Everything else ignores it for now.
                if ($currTag == TAG_PARAGRAPH)
                    {
                    $output .= $self->RichFormatTextBlock($textBlock) . '</p>';
                    $textBlock = undef;
                    $currTag = TAG_NONE;
                    };

                $prevLineBlank = 1;
                }

            # If the line starts with a bullet...
            elsif ($commentLine =~ /^[-\*o+] +([^ ].*)$/ &&
                        (substr($1, 0, 2) ne '- ') &&   # Make sure "o - Something" is a definition, not a bullet.
                        ($file && $file->Modeline('butlist', 1)))
                {
                my $bulleted = $1;

                if (defined $textBlock)
                    {  $output .= $self->RichFormatTextBlock($textBlock);  };

                $output .= $indent->Process(\$currTag, TAG_BULLETLIST, $column);

                if ($currTag != TAG_BULLETLIST)
                    {
                    $output .= $tagEnders{$currTag};
                    $output .= '<ul>' . $indent->Markup ();
                    $currTag = TAG_BULLETLIST;
                    };
                $output .= '<li>';

                $textBlock = $bulleted;
                $prevLineBlank = undef;
                }

            # If the line is a numbered list entry...
            elsif ((($currTag != TAG_PARAGRAPH &&        #ND+, ordered lists (i. a. 0.)
                        $commentLine =~ /^([ia-z0-9])\. +([^ ].*)$/i) ||
                    ($currTag == TAG_ORDEREDLIST &&
                        $commentLine =~ /^([1-9]+)\. +([^ ].*)$/)) &&
                    ($file && $file->Modeline('numlists', 1)))
                {
                my ($order, $text) = ($1, $2);

                if (defined $textBlock)
                    {  $output .= $self->RichFormatTextBlock($textBlock);  };

                $output .= $indent->Process(\$currTag, TAG_ORDEREDLIST, $column, $order);

                if ($currTag != TAG_ORDEREDLIST)
                    {
                    $order = '1' if ($order =~ /[0-9]+/);
                    $output .= $tagEnders{$currTag};
                    $output .= '<ol type="' . $order . '">' . $indent->Markup ();
                    $currTag = TAG_ORDEREDLIST;
                    };
                $output .= '<li>';

                $textBlock = $text;
                $prevLineBlank = undef;
                }

            # If the line looks like a definition list entry...
            elsif ($currTag != TAG_PARAGRAPH &&
                        $commentLine =~ /^(.+?) +- +([^ ].*)$/ &&
                        ($file && $file->Modeline('deflists', 1)))
                {
                my $tag;
                my $entry = $1;
                my $description = $2;

                if (defined $textBlock)
                    {  $output .= $self->RichFormatTextBlock($textBlock);  };

                $output .= $indent->Process(\$currTag, TAG_DESCRIPTIONLIST, $column);

                if ($currTag != TAG_DESCRIPTIONLIST)
                    {
                    $output .= $tagEnders{$currTag};
                    $output .= '<dl>' . $indent->Markup ();
                    $currTag = TAG_DESCRIPTIONLIST;
                    };

                if (($isList && !$ignoreListSymbols) || $type eq ::TOPIC_ENUMERATION())
                    {  $tag = 'ds';  }
                else
                    {  $tag = 'de';  };
                $output .=
                    "<$tag>" . NaturalDocs::NDMarkup->ConvertAmpChars($entry) . "</$tag><dd>";

                $textBlock = $description;
                $prevLineBlank = undef;
                }

            # Indenting (manual)                #ND+, indent
            elsif ($commentLine =~ /^\( *indent *(on|off) *\)$/i)
                {
                $indent->Auto (lc($1) eq "on");
                }

            elsif ($commentLine =~ /^indent\+\$/)
                {                               #ND+, manual increase
                $indent->Increase ();
                }

            elsif ($commentLine =~ /^ident\-\$/)
                {                               #ND+, manual decrease
                my $t_output = $indent->Decrease ();

                if (defined $t_output)
                    {
                    if (defined $textBlock)
                        {
                        $output .= $self->RichFormatTextBlock($textBlock);
                        $textBlock = undef;
                        };
                    $output .= $t_output;
                    }
                }

            # If the line looks like an embedded table.
            elsif ($tabletype == 0 &&           #ND+, table
                        $commentLine =~ /^ *\( *(?:(?:start|begin)? +)?table([^\)]*)\)$/i)
                {
                my $options = $1;

                if (defined $textBlock)
                    {
                    $output .= $self->RichFormatTextBlock($textBlock);
                    $textBlock = undef;
                    };

                $output .= $indent->End($currTag);
                $currTag = TAG_NONE;

                # create table insert a table object reference
                $table = NaturalDocs::Parser::Table->New(0, 0, $options);
                $output .= '<table=' . NaturalDocs::Parser->OnObject($table) . '>';

                $prevLineBlank = undef;
                }

            elsif ($tabletype == 1 &&           #ND+, table
                        $commentLine =~ /^\[\[(.+)$/i)
                {
                if (defined $textBlock)
                    {
                    $output .= $self->RichFormatTextBlock($textBlock);
                    $textBlock = undef;
                    };

                $output .= $indent->End($currTag);
                $currTag = TAG_NONE;

                # create table insert a table object reference
                $table = NaturalDocs::Parser::Table->New(0, 0, '--Embedded');
                $output .= '<table=' . NaturalDocs::Parser->OnObject($table) . '>';

                # parse the table column definition
                $table->ParseLine (' ' x ($column) . '[ ' . $1);
                $prevLineBlank = undef;
                }

            # If the line could be a admonishment container
            elsif ($prevLineBlank && $commentLine =~ /^\s*([a-z]+)!:(.*)$/i &&
                        exists $admonitions{lc($1)} && $file->Modeline('admon', 1))
                {                               #ND+, admonition's
                my $leading = $1;
                my $trailing = ":" . $2;

                if (defined $textBlock)
                    {
                    $output .= $self->RichFormatTextBlock($textBlock);
                    $textBlock = undef;
                    };

                $leading =~ s/([\w]+)/\u\L$1/g; # captialise leading character
                $output .= $indent->End($currTag);
                $output .= $admonition;
                $output .=
                    '<admon-' . $leading . '>' .
                        '<ah>' . $self->RichFormatTextBlock($leading.$trailing) . '</ah>';
                $admonition = '</admon-' . $leading . ">\n";
                $currTag = TAG_NONE;

                $prevLineBlank = undef;
                }

            # If the line could be a header.
            elsif ($prevLineBlank && $commentLine =~ /^\s*(.*)([^ \t]):$/)
                {
                my $headerText = $1 . $2;

                if (defined $textBlock)
                    {
                    $output .= $self->RichFormatTextBlock($textBlock);
                    $textBlock = undef;
                    };

                $output .= $indent->End($currTag);
                $output .= $admonition;
                $output .= '<h>' . $self->RichFormatTextBlock($headerText) . '</h>';
                $admonition = '';
                $currTag = TAG_NONE;

                if ($type eq ::TOPIC_FUNCTION() && $isList)
                    {
                    $ignoreListSymbols = exists $functionListIgnoredHeadings{lc($headerText)};
                    };

                $prevLineBlank = undef;
                }

            # If the line looks like a tag...
            elsif ($commentLine =~ /^\( *(?:(?:start|begin)? +)?(?:code|example|diagram)([^\)]*)\)$/i)
                {
                my $options = $1;

                if (defined $textBlock)
                    {
                    $output .= $self->RichFormatTextBlock($textBlock);
                    $textBlock = undef;
                    };

                $output .= $indent->End($currTag) . "<code$options>";
                $currTag = TAG_CODE;
                }

            elsif ($commentLine =~ /^ *\(quote\) *$/i)
                {                               #ND+, quote
                my $options = $1;

                if (defined $textBlock)
                    {
                    $output .= $self->RichFormatTextBlock($textBlock);
                    $textBlock = undef;
                    };

                $output .= $indent->End($currTag) . "<quote>";
                $currTag = TAG_QUOTE;
                }

            # If the line looks like a line drawing tag...
            elsif ($commentLine =~ /^ *\( *(?:(?:start|begin)? +)?ditaa([^\)]*)\)$/i)
                {                               #ND+, ditaa
                my $options = $1;

                if (defined $textBlock)
                    {
                    $output .= $self->RichFormatTextBlock($textBlock);
                    $textBlock = undef;
                    };

                $output .= $indent->End($currTag) . "<ditaa $options>\n";
                $currTag = TAG_DITAA;
                }

            # If the line looks like a line drawing tag...
            elsif ($commentLine =~ /^ *\( *(?:(?:start|begin)? +)?drawing([^\)]*)\)$/i)
                {                               #ND+, drawing/svg
                my $options = $1;

                if (defined $textBlock)
                    {
                    $output .= $self->RichFormatTextBlock($textBlock);
                    $textBlock = undef;
                    };

                $output .= $indent->End($currTag) . "<drawing $options>\n";
                $currTag = TAG_DRAWING;
                }

            # If the line looks like a line drawing tag...
            elsif ($commentLine =~ /^ *\( *(?:(?:start|begin)? +)?mscgen([^\)]*)\)$/i)
                {                               #ND+, mscgen
                my $options = $1;

                if (defined $textBlock)
                    {
                    $output .= $self->RichFormatTextBlock($textBlock);
                    $textBlock = undef;
                    };

                $output .= $indent->End($currTag) . "<mscgen $options>\n";
                $currTag = TAG_MSCGEN;
                }

            # If the line looks like a line drawing tag...
            elsif ($commentLine =~ /^ *\( *(?:(?:start|begin)? +)?sdedit([^\)]*)\)$/i)
                {                               #ND+, sdedit
                my $options = $1;

                if (defined $textBlock)
                    {
                    $output .= $self->RichFormatTextBlock($textBlock);
                    $textBlock = undef;
                    };

                $output .= $indent->End($currTag) . "<sdedit $options>\n";
                $currTag = TAG_SDEDIT;
                }

            # If the line looks like an inline image...
            elsif ($commentLine =~ /^(\( *see +)([^\)]+?)( *\))$/i)
                {
                if (defined $textBlock)
                    {
                    $output .= $self->RichFormatTextBlock($textBlock);
                    $textBlock = undef;
                    };

                $output .= $tagEnders{$currTag};
                $currTag = TAG_NONE;
                $output .= '<img mode="inline" target="' . NaturalDocs::NDMarkup->ConvertAmpChars($2) . '" '
                                . 'original="' . NaturalDocs::NDMarkup->ConvertAmpChars($1 . $2 . $3) . '">';

                $prevLineBlank = undef;
                }

            # If the line isn't any of those, we consider it normal text.
            else
                {
                # A blank line followed by normal text ends lists. We don't handle this when we
                # detect if the line's blank because we don't want blank lines between list items
                # to break the list.
                #
                if ($prevLineBlank && (defined $lineEnders{$currTag}))
                    {                           #ND+, continuation
                    $output .= $self->RichFormatTextBlock($textBlock);

                    if ($indent->CanIncrease($column))
                        { $output .= '<br>'; }  # continuation
                    else
                        {                       # otherwise, new paragraph
                        $output .= $indent->End($currTag) . '<p>';
                        $currTag = TAG_PARAGRAPH;
                        }
                    $textBlock = undef;
                    }

                elsif ($currTag == TAG_NONE)
                    {
                    $output .= '<p>';
                    $currTag = TAG_PARAGRAPH;
                    # textBlock will already be undef.
                    };

                if (defined $textBlock)
                    {  $textBlock .= ' ';  };   # word break

                $textBlock .= $commentLine;     # new text
                $prevLineBlank = undef;
                };
            };

        $index++;
        };

    # Clean up anything left dangling.

    if ($table)
        {
        $table->ParseEnd ();
        $table = undef;
        }
    elsif (defined $textBlock)
        {
        $output .= $self->RichFormatTextBlock ($textBlock);
        $textBlock = undef;
        }
    elsif (defined $codeBlock)
        {
        $codeBlock =~ s/\n+$//;
        if ($currTag == TAG_DITAA || $currTag == TAG_DRAWING || $currTag == TAG_MSCGEN || $currTag == TAG_SDEDIT)
            {  $output .= $codeBlock;  }        #ND+, ditaa/mscgen/sdedit
        else
            {  $output .= NaturalDocs::NDMarkup->ConvertAmpChars ($codeBlock);  }
        $codeBlock = undef;
        }

    if (defined $lineEnders{$currTag})
        {
        $output .= $indent->End ($currTag);     #ND+, ident/cont
        }
    elsif ($tagEnders{$currTag} ne '')
        {
        $output .= $tagEnders{$currTag} . "\n";
        }

    $output .= $admonition;

    return $output;
    };


#
#   Function: AddToCodeBlock
#
#   Adds a line of text to a code block, handling all the indentation processing required.
#
#   Parameters:
#
#       line - The line of text to add.
#       codeBlockRef - A reference to the code block to add it to.
#       removedSpacesRef - A reference to a variable to hold the number of spaces removed.  It needs to be stored between calls.
#                                      It will reset itself automatically when the code block codeBlockRef points to is undef.
#
sub AddToCodeBlock #(line, codeBlockRef, removedSpacesRef)
    {
    my ($self, $line, $codeBlockRef, $removedSpacesRef) = @_;

    $line =~ /^( *)(.*)$/;
    my ($spaces, $code) = ($1, $2);

    if (!defined $$codeBlockRef)
        {
        if (length($code))
            {
            $$codeBlockRef = $code . "\n";
            $$removedSpacesRef = length($spaces);
            };
        # else ignore leading line breaks.
        }

    elsif (length $code)
        {
        # Make sure we have the minimum amount of spaces to the left possible.
        #
        # ND+/XXX - need margin option
        #
        if (length($spaces) != $$removedSpacesRef)
            {
            my $spaceDifference = abs( length($spaces) - $$removedSpacesRef );
            my $spacesToAdd = ' ' x $spaceDifference;

            if (length($spaces) > $$removedSpacesRef)
                {
                $$codeBlockRef .= $spacesToAdd;
                }
            else
                {
                $$codeBlockRef =~ s/^(.)/$spacesToAdd . $1/gme;
                $$removedSpacesRef = length($spaces);
                };
            };

        $$codeBlockRef .= $code . "\n";
        }

    else # (!length $code)
        {
        $$codeBlockRef .= "\n";
        };
    };


#
#   Function: RichFormatTextBlock
#
#       Applies rich <NDMarkup> formatting to a chunk of text.  This includes both amp chars,
#       formatting tags, and link tags.
#
#   Parameters:
#
#       text - The block of text to format.
#
#   Returns:
#
#       The formatted text block.
#
sub RichFormatTextBlock #(text)
    {
    my ($self, $text) = @_;
    my $output;


    # First find bare urls, e-mail addresses, and images.  We have to do this before the split because they may contain underscores
    # or asterisks.  We have to mark the tags with \x1E and \x1F so they don't get confused with angle brackets from the comment.
    # We can't convert the amp chars beforehand because we need lookbehinds in the regexps below and they need to be
    # constant length.  Sucks, huh?

    $text =~ s{
                       # The previous character can't be an alphanumeric or an opening angle bracket.
                       (?<!  [a-z0-9<]  )

                       # Optional mailto:.  Ignored in output.
                       (?:mailto\:)?

                       # Begin capture
                       (

                       # The user portion.  Alphanumeric and - _.  Dots can appear between, but not at the edges or more than
                       # one in a row.
                       (?:  [a-z0-9\-_]+  \.  )*   [a-z0-9\-_]+

                       @

                       # The domain.  Alphanumeric and -.  Dots same as above, however, there must be at least two sections
                       # and the last one must be two to four alphanumeric characters (.com, .uk, .info, .203 for IP addresses)
                       (?:  [a-z0-9\-]+  \.  )+  [a-z]{2,4}

                       # End capture.
                       )

                       # The next character can't be an alphanumeric, which should prevent .abcde from matching the two to
                       # four character requirement, or a closing angle bracket.
                       (?!  [a-z0-9>]  )

                       }

                       {"\x1E" . 'email target="' . NaturalDocs::NDMarkup->ConvertAmpChars($1) . '" '
                       . 'name="' . NaturalDocs::NDMarkup->ConvertAmpChars($1) . '"' . "\x1F"}igxe;

    $text =~ s{
                       # The previous character can't be an alphanumeric or an opening angle bracket.
                       (?<!  [a-z0-9<]  )

                       # Begin capture.
                       (

                       # URL must start with one of the acceptable protocols. ND+
                       (?:http|https|ftp|ftps|news|file|git)\:

                       # The acceptable URL characters as far as I know.
                       [a-z0-9\-\=\~\@\#\%\&\_\+\/\;\:\?\*\.\,]*

                       # The URL characters minus period and comma.  If it ends on them, they're probably intended as
                       # punctuation.
                       [a-z0-9\-\=\~\@\#\%\&\_\+\/\;\:\?\*]

                       # End capture.
                       )

                       # The next character must not be an acceptable character or a closing angle bracket.  This will prevent the URL
                       # from ending early just to get a match.
                       (?!  [a-z0-9\-\=\~\@\#\%\&\_\+\/\;\:\?\*\>]  )

                       }

                       {"\x1E" . 'url target="' . NaturalDocs::NDMarkup->ConvertAmpChars($1) . '" '
                       . 'name="' . NaturalDocs::NDMarkup->ConvertAmpChars($1) . '"' . "\x1F"}igxe;


    # Find image links.  Inline images should already be pulled out by now.

    $text =~ s{(\( *see +)([^\)]+?)( *\))}
                      {"\x1E" . 'img mode="link" target="' . NaturalDocs::NDMarkup->ConvertAmpChars($2) . '" '
                        . 'original="' . NaturalDocs::NDMarkup->ConvertAmpChars($1 . $2 . $3) . '"' . "\x1F"}gie;


    # Split the text from the potential tags.
                                                            #ND+, italic/image/strikethru
    my @tempTextBlocks = split(/([\'\*_\~<>\x1E\x1F])/, $text);

    # Since the symbols are considered dividers, empty strings could appear between two in a row or at the beginning/end of the
    # array.  This could seriously screw up TagType(), so we need to get rid of them.
    my @textBlocks;

    while (scalar @tempTextBlocks)
        {
        my $tempTextBlock = shift @tempTextBlocks;

        if (length $tempTextBlock)
            {  push @textBlocks, $tempTextBlock;  };
        };


    my $bold;
    my $underline;
    my $underlineHasWhitespace;
    my $italic;                                             #ND+, italic
    my $strike;
#   my $monotype;                                           #ND+, monotype

    my $index = 0;

    while ($index < scalar @textBlocks)
        {
        if ($textBlocks[$index] eq "\x1E")
            {
            $output .= '<';
            $index++;

            while ($textBlocks[$index] ne "\x1F")
                {
                $output .= $textBlocks[$index];
                $index++;
                };

            $output .= '>';
            }

        elsif ($textBlocks[$index] eq '<' && $self->TagType(\@textBlocks, $index) == POSSIBLE_OPENING_TAG)
            {
            my $endingIndex = $self->ClosingTag(\@textBlocks, $index, undef);

            if ($endingIndex != -1)
                {
                my $linkText;
                $index++;

                while ($index < $endingIndex)
                    {
                    $linkText .= $textBlocks[$index];
                    $index++;
                    };

                # Index will be incremented again at the end of the loop.

                $linkText = NaturalDocs::NDMarkup->ConvertAmpChars($linkText);

                if ($linkText =~ /^(?:mailto\:)?((?:[a-z0-9\-_]+\.)*[a-z0-9\-_]+@(?:[a-z0-9\-]+\.)+[a-z]{2,4})$/i)
                    {  $output .= '<email target="' . $1 . '" name="' . $1 . '">';  }

                                                            #ND+, links
                elsif ($linkText =~ /^(?:http|https|ftp|ftps|news|file|git)\:/i)
                    {  $output .= '<url target="' . $linkText . '" name="' . $linkText . '">';  }

                else
                    {  $output .= '<link target="' . $linkText . '" name="' . $linkText . '" original="&lt;' . $linkText . '&gt;">';  };
                }

            else # it's not a link.
                {
                $output .= '&lt;';
                };
            }

        elsif ($textBlocks[$index] eq '*')                  # bold
            {
            my $tagType = $self->TagType(\@textBlocks, $index);

            if ($tagType == POSSIBLE_OPENING_TAG && $self->ClosingTag(\@textBlocks, $index, undef) != -1)
                {
                # ClosingTag() makes sure tags aren't opened multiple times in a row.
                $bold = 1;
                $output .= '<b>';
                }
            elsif ($bold && $tagType == POSSIBLE_CLOSING_TAG)
                {
                $bold = undef;
                $output .= '</b>';
                }
            else
                {
                $output .= '*';
                };
            }

        elsif ($textBlocks[$index] eq '_')                  # underline
            {
            my $tagType = $self->TagType(\@textBlocks, $index);

             if ($tagType == POSSIBLE_OPENING_TAG && $self->ClosingTag(\@textBlocks, $index, \$underlineHasWhitespace) != -1)
                {
                # ClosingTag() makes sure tags aren't opened multiple times in a row.
                $underline = 1;
                #underlineHasWhitespace is set by ClosingTag().
                $output .= '<u>';
                }
            elsif ($underline && $tagType == POSSIBLE_CLOSING_TAG)
                {
                $underline = undef;
                #underlineHasWhitespace will be reset by the next opening underline.
                $output .= '</u>';
                }
            elsif ($underline && !$underlineHasWhitespace)
                {
                # If there's no whitespace between underline tags, all underscores are replaced by spaces so
                # _some_underlined_text_ becomes <u>some underlined text</u>.  The standard _some underlined text_
                # will work too.
                $output .= ' ';
                }
            else
                {
                $output .= '_';
                };
            }

        elsif ($textBlocks[$index] eq '\'')                 #ND+, italic
            {
            my $tagType = $self->TagType(\@textBlocks, $index);

            if ($tagType == POSSIBLE_OPENING_TAG && $self->ClosingTag(\@textBlocks, $index, undef) != -1)
                {
                # ClosingTag() makes sure tags aren't opened multiple times in a row.
                $italic = 1;
                $output .= '<i>';
                }
            elsif ($italic && $tagType == POSSIBLE_CLOSING_TAG)
                {
                $italic = undef;
                $output .= '</i>';
                }
            else
                {
                $output .= '\'';
                };
            }

        elsif ($textBlocks[$index] eq '~' && 
                    ($index + 1) < scalar @textBlocks && $textBlocks[$index + 1] eq '~')
            {                                               #ND+, strikethrough ~~xxxx~~
            my $tagType = $self->TagType(\@textBlocks, $index);

            if ($tagType == POSSIBLE_OPENING_TAG && $self->ClosingTag(\@textBlocks, $index, undef) != -1)
                {
                # ClosingTag() makes sure tags aren't opened multiple times in a row.
                $strike = 1;
                $output .= '<del>';
                $index++;
                }
            elsif ($strike && $tagType == POSSIBLE_CLOSING_TAG)
                {
                $strike = undef;
                $output .= '</del>';
                $index++;
                }
            else
                {
                $output .= '\'';
                };
            }

    #   elsif ($textBlocks[$index] eq '{' && $textBlocks[$index+1] eq '{')
    #       {                                               #ND+, monotype '{{monospace}}'
    #       }

    #others???
    #   elsif ($textBlocks[$index] eq '^' && $textBlocks[$index+1] eq '^')
    #       {                                               #ND+, superscript '^^superscript^^'
    #       }
    #
    #   elsif ($textBlocks[$index] eq 'v' && $textBlocks[$index+1] eq 'v')
    #       {                                               #ND+, subscript 'vvsubscriptvv'
    #       }
    #

        else    #plain text or a > that isn't part of a link
            {
            $output .= NaturalDocs::NDMarkup->ConvertAmpChars($textBlocks[$index]);
            };

        $index++;
        };

    return $output;
    };


#
#   Function: TagType
#
#   Returns whether the tag is a possible opening or closing tag, or neither.  "Possible" because it doesn't check if an opening tag is
#   closed or a closing tag is opened, just whether the surrounding characters allow it to be a candidate for a tag.  For example, in
#   "A _B" the underscore is a possible opening underline tag, but in "A_B" it is not.  Support function for <RichFormatTextBlock()>.
#
#   Parameters:
#
#       textBlocks  -   A reference to an array of text blocks.
#       index -         The index of the tag.
#
#   Returns:
#
#       POSSIBLE_OPENING_TAG, POSSIBLE_CLOSING_TAG, or NOT_A_TAG.
#
sub TagType #(textBlocks, index)
    {
    my ($self, $textBlocks, $index) = @_;


    # Possible opening tags

    if ( ( $textBlocks->[$index] =~ /^[\'\*_<]$/ ) &&     #ND+, italic/bold/underline

            # Before it must be whitespace, the beginning of the text, or ({["'-/.
            ( $index == 0 || $textBlocks->[$index-1] =~ /[\ \t\n\(\{\[\"\'\-\/]$/ ) &&

            # After it must be non-whitespace.
            ( $index + 1 < scalar @$textBlocks && $textBlocks->[$index+1] !~ /^[\ \t\n]/) &&

            # Make sure we don't accept <<, <=, <-, or *= as opening tags
            ( $textBlocks->[$index] ne '<' || $textBlocks->[$index+1] !~ /^[<=-]/ ) &&
            ( $textBlocks->[$index] ne '*' || $textBlocks->[$index+1] !~ /^\=/ ) )
        {
        return POSSIBLE_OPENING_TAG;
        }

    elsif ( ( $textBlocks->[$index] eq '~' ) &&             #ND+, strikethrough (~~)

            # Before it must be whitespace, the beginning of the text, or ({["'-/.
            ( $index == 0 || $textBlocks->[$index-1] =~ /[\ \t\n\(\{\[\"\'\-\/]$/ ) &&

            # After it must be non-whitespace.
            ( $index + 2 < scalar @$textBlocks && $textBlocks->[$index+2] !~ /^[\ \t\n]/) )
        {
        return POSSIBLE_OPENING_TAG;
        }

    # Possible closing tags

    elsif ( ( $textBlocks->[$index] =~ /^[\'\*_>]$/) &&     #ND+, italic/mono

            # After it must be whitespace, the end of the text, or )}].,!?"';:-/.
            ( $index + 1 == scalar @$textBlocks || $textBlocks->[$index+1] =~ /^[ \t\n\)\]\}\.\,\!\?\"\'\;\:\-\/]/ ||
                # Links also get plurals, like <link>s, <linx>es, <link>'s, and <links>'.
                ( $textBlocks->[$index] eq '>' && $textBlocks->[$index+1] =~ /^(?:es|s|\')/ ) ) &&

            # Before it must be non-whitespace.
            ( $index != 0 && $textBlocks->[$index-1] !~ /[ \t\n]$/ ) &&

            # Make sure we don't accept >>, ->, or => as closing tags.  >= is already taken care of.
            ( $textBlocks->[$index] ne '>' || $textBlocks->[$index-1] !~ /[>=-]$/ ) )
        {
        return POSSIBLE_CLOSING_TAG;
        }

    elsif ( ( $textBlocks->[$index] =~ /^[\~]$/ ) &&        #ND+, strikethrough (~~)

            # After it must be whitespace, the end of the text, or )}].,!?"';:-/.
            ( $index + 2 == scalar @$textBlocks || $textBlocks->[$index+2] =~ /^[ \t\n\)\]\}\.\,\!\?\"\'\;\:\-\/]/) &&

            # Before it must be non-whitespace.
            ( $index >= 2 && $textBlocks->[$index-2] !~ /[ \t\n]$/ ) )
        {
        return POSSIBLE_CLOSING_TAG;
        }

    else
        {
        return NOT_A_TAG;
        };

    };


#
#   Function: ClosingTag
#
#   Returns whether a tag is closed or not, where it's closed if it is, and optionally whether there is any whitespace between the
#   tags.  Support function for <RichFormatTextBlock()>.
#
#   The results of this function are in full context, meaning that if it says a tag is closed, it can be interpreted as that tag in the
#   final output.  It takes into account any spoiling factors, like there being two opening tags in a row.
#
#   Parameters:
#
#       textBlocks        - A reference to an array of text blocks.
#       index             - The index of the opening tag.
#       hasWhitespaceRef  - A reference to the variable that will hold whether there is whitespace between the tags or not.  If
#                           undef, the function will not check.  If the tag is not closed, the variable will not be changed.
#
#   Returns:
#
#       If the tag is closed, it returns the index of the closing tag and puts whether there was whitespace between the tags in
#       hasWhitespaceRef if it was specified.  If the tag is not closed, it returns -1 and doesn't touch the variable pointed to by
#       hasWhitespaceRef.
#
sub ClosingTag #(textBlocks, index, hasWhitespace)
    {
    my ($self, $textBlocks, $index, $hasWhitespaceRef) = @_;

    my $hasWhitespace;
    my $closingTag;
    my $closingTag2;                                        #ND+, strikethrough      

    if ($textBlocks->[$index] eq '*' || $textBlocks->[$index] eq '_' ||
                  $textBlocks->[$index] eq '\'')            #ND+, italic
        {
        $closingTag = $textBlocks->[$index];
        }
    elsif ($textBlocks->[$index] eq '~')
        {                                                   #ND+, strikethrough
        $closingTag = $textBlocks->[$index];
        $closingTag2 = $closingTag;
        }
    elsif ($textBlocks->[$index] eq '<')
        {  $closingTag = '>';  }
    else
        {  return -1;  };

    my $beginningIndex = $index;
    $index++;

    while ($index < scalar @$textBlocks)
        {
        if ($textBlocks->[$index] eq '<' && $self->TagType($textBlocks, $index) == POSSIBLE_OPENING_TAG)
            {
            # If we hit a < and we're checking whether a link is closed, it's not.  The first < becomes literal and the second one
            # becomes the new link opening.
            if ($closingTag eq '>')
                {
                return -1;
                }

            # If we're not searching for the end of a link, we have to skip the link because formatting tags cannot appear within
            # them.  That's of course provided it's closed.
            else
                {
                my $linkHasWhitespace;

                my $endIndex = $self->ClosingTag($textBlocks, $index,
                                    ($hasWhitespaceRef && !$hasWhitespace ? \$linkHasWhitespace : undef) );

                if ($endIndex != -1)
                    {
                    if ($linkHasWhitespace)
                        {  $hasWhitespace = 1;  };

                    # index will be incremented again at the end of the loop, which will bring us past the link's >.
                    $index = $endIndex;
                    };
                };
            }

        elsif ($textBlocks->[$index] eq $closingTag &&
                    (! $closingTag2 || 
                            (($index + 1) < scalar @$textBlocks && $textBlocks->[$index + 1] eq $closingTag2)))
            {                                               #ND+, strikethrough
            my $tagType = $self->TagType($textBlocks, $index);

            if ($tagType == POSSIBLE_CLOSING_TAG)
                {
                # There needs to be something between the tags for them to count.
                if ($index == $beginningIndex + 1)
                    {  return -1;  }
                else
                    {
                    # Success!

                    if ($hasWhitespaceRef)
                        {  $$hasWhitespaceRef = $hasWhitespace;  };

                    return $index;
                    };
                }

            # If there are two opening tags of the same type, the first becomes literal and the next becomes part of a tag.
            elsif ($tagType == POSSIBLE_OPENING_TAG)
                {  return -1;  }
            }

        elsif ($hasWhitespaceRef && !$hasWhitespace)
            {
            if ($textBlocks->[$index] =~ /[ \t\n]/)
                {  $hasWhitespace = 1;  };
            };

        $index++;
        };

    # Hit the end of the text blocks if we're here.
    return -1;
    };

1;
