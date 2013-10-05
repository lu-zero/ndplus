# -*- mode: perl; indent-width: 4; -*-
###############################################################################
#
#   Package: NaturalDocs::Parser
#
###############################################################################
#
#   A package that coordinates source file parsing between the <NaturalDocs::Languages::Base>-derived objects and its own
#   sub-packages such as <NaturalDocs::Parser::Native>.  Also handles sending symbols to <NaturalDocs::SymbolTable> and
#   other generic topic processing.
#
#   Usage and Dependencies:
#
#       - Prior to use, <NaturalDocs::Settings>, <NaturalDocs::Languages>, <NaturalDocs::Project>, <NaturalDocs::SymbolTable>,
#         and <NaturalDocs::ClassHierarchy> must be initialized.  <NaturalDocs::SymbolTable> and <NaturalDocs::ClassHierarchy>
#         do not have to be fully resolved.
#
#       - Aside from that, the package is ready to use right away.  It does not have its own initialization function.
#
###############################################################################

# This file is part of Natural Docs, which is Copyright (C) 2003-2008 Greg Valure
# ND+ extensions, Copyright (C) 2007-2013 Adam Young
# Natural Docs is licensed under the GPL

use NaturalDocs::Parser::ParsedFile;            #ND+, package/modeline
use NaturalDocs::Parser::ParsedTopic;
use NaturalDocs::Parser::Native;
use NaturalDocs::Parser::JavaDoc;

use strict;
use integer;

package NaturalDocs::Parser;


###############################################################################
# Group: Variables

#
#   var: parsedStreams
#
#       The result of each file parsed or pushed topic stream.
#
my %parsedStreams;                              #ND+, package

#
#   var: parsedObjects
#
#       The result of each embedded object parsed.
#
my %parsedObjects;                              #ND+, package

#
#   var: parsedFooter
#
#       The result of the parsed page footer, if any.
#
my $parsedFooter;                               #ND+, pagefooter

#
#   var: sourceFile
#
#       The source <FileName> currently being parsed.
#
#ND+ - hack, remove globals
#my $sourceFile;

#
#   removed var: language
#
#       The language object for the file, derived from <NaturalDocs::Languages::Base>.
#
#ND+, package
#my $language;

#
#   Array: parsedFile
#
#       An ArrayRef of <NaturalDocs::Parser::ParsedTopic> objects.
#
#ND+, package                                   #ND+ - FIXME remove globals, use ParsedFile
my $parsedTopics;

#
#   Array: parsedObjects
#
#       An ArrayRef of parser specific embedded objects.
#
#ND+, table                                     #ND+ - FIXME, remove globals, use ParsedFile
my $parsedObjects;

#
#   var: parsedHierarchy
#
#       If defined shall contain the encountered class hierarchy.
#
#ND+, package                                   #ND+ - FIXME, remove globals, use ParsedFile
my $parsedHierarchy;


###############################################################################
# Group: Functions

#
#   Function:   Load
#
#       Load the specified file, parsing the topics contained within and
#       building up details on the class hierarchy.
#
#   Parameters:
#
#       source - Path of the source file to parse.
#
#   Returns:
#       An arrayref of the source file as <NaturalDocs::Parser::ParsedTopic> objects.
#
#ND+, package
sub Load #(source)
    {
    my ($self, $source) = @_;

    my $file = $self->ParsedFile($source);

    $parsedTopics = [];
    $parsedObjects = [];
    $parsedHierarchy = [];

    $file->SetTopics($parsedTopics);
    $file->SetObjects($parsedObjects);

    $self->Parse($file, undef);

    $file->SetHierarchy($parsedHierarchy)
        if (scalar @$parsedHierarchy);

    $parsedTopics = undef;
    $parsedObjects = undef;
    $parsedHierarchy = undef;
    return $file;
    }


#
#   Function:   ParsedFile
#
#       Retrieve the associated parser results object, creating one if not does not already exist.
#
#   Parameters:
#       source - The topic stream.
#
#ND+, package
sub ParsedFile #(source])
    {
    my ($self, $source) = @_;
    my $file;

    return $parsedStreams{$source}
        if (exists $parsedStreams{$source});

    my $file = NaturalDocs::Parser::ParsedFile->New($source);
    $parsedStreams{$source} = $file;
    return $file;
    };


#
#   Function: Drop
#
#       Drop the topic table and object table for the specified file, forcing a
#       reload upon the next <Topics> reference.
#
#   Parameters:
#       source - The topic stream.
#
#ND+, package
sub Drop #(source)
    {
    my ($self, $source) = @_;

    if (! defined $parsedStreams{$source})
        {  die "Internal: $source was not previously loaded ...\n";  }

    $parsedStreams{$source}->SetTopics(undef);  # parsed topics
    $parsedStreams{$source}->SetObjects(undef); # embedded objects
    };


#
#   Function: Unload
#
#       Unload the input stream completely.
#
#   Parameters:
#       source - The topic stream.
#
#ND+, package
sub Unload #(source)
    {
    my ($self, $source) = @_;

    if (! defined $parsedStreams{$source})
        {  die "Internal: $source was not previously loaded ...\n";  }

    delete $parsedStreams{$source};
    };


#
#   Function: Topics
#
#       Retrieve the encountered topics for the specified input stream, reload
#       the topics on demand if previously dropped using <Drop>, within
#       a <NaturalDocs::Parser::ParsedTopic> arrayref.
#
#   Parameters:
#       source - The topic stream.
#       reloaded - If defined, set to whether the file was reloaded.
#
#   Returns:
#       An arrayref of the source stream as <NaturalDocs::Parser::ParsedTopic> objects.
#
#ND+, package
sub Topics #(source, [reloaded])
    {
    my ($self, $source, $reloaded) = @_;

    if (! defined $parsedStreams{$source})
        {  die "Internal: $source was not previously loaded ...\n";  }

    my $file = $parsedStreams{$source};

    if (! defined $file->Topics())
        {                                       # reload
        $parsedTopics = [];
        $parsedObjects = [];

        $file->SetTopics($parsedTopics);
        $file->SetObjects($parsedObjects);

        $self->Parse($file, $file->Language());

        $parsedTopics = undef;
        $parsedObjects = undef;

        if (defined $reloaded)
            {  $$reloaded = 1;  }
        }
    else
        {
        if (defined $reloaded)
            {  $$reloaded = 0;  }
        }

    return $file->Topics();
    };


#
#   Function:   Hierarchy
#
#       Retrieve the encountered class hierarchy within the specified input stream.
#
#   Parameters:
#       source - The topic stream.
#
#ND+, package
sub Hierarchy #(source)
    {
    my ($self, $source) = @_;

    if (! defined $parsedStreams{$source})
        {  die "Internal: $source was not previously loaded ...\n";  }

    return $parsedStreams{$source}->Hierarchy();
    };


#
#   Function:   DefaultMenuTitle
#
#       Retrieve the default menu title for the specified input stream.
#
#   Parameters:
#       source - The topic stream.
#
#ND+, package
sub DefaultMenuTitle #(source)
    {
    my ($self, $source) = @_;

    if (! defined $parsedStreams{$source})
        {  die "Internal: $source was not previously loaded ...\n";  }

    return $parsedStreams{$source}->DefaultMenuTitle();
    };


#
#   Function:   Language
#
#       Retrieve the language for the specified input stream.
#
#   Parameters:
#       source - The topic stream.
#
#   Returns:
#       An <NaturalDocs::Languages::Base>-derived object
#
#ND+, package
sub Language #(source)
    {
    my ($self, $source) = @_;

    if (! defined $parsedStreams{$source})
        {  die "Internal: $source was not previously loaded ...\n";  }

    return $parsedStreams{$source}->Language();
    };


#
#   Function:   Object
#
#       Retrieve a related object
#
#ND+, table
sub Object #(source, objectid)
    {
    my ($self, $source, $objectid) = @_;

    if (! defined $parsedStreams{$source})
        {  die "Internal: $source was not previously loaded ...\n";  }

    my $objects = $parsedStreams{$source}->Objects();

    if (!defined @$objects[ $objectid-1 ])
        {  die "Internal: referencing undefined $objectid within $source....\n";  }

    return @$objects[ $objectid-1 ];
    }


#
#   Function:   ObjectDup
#
#       Duplicate the specified object referenced thru 'objectid' owned by the
#       source stream 'source', to the new source stream 'new_source'.
#
#   Returns:
#       Local new_source specific object identifier.
#
#ND+, package/table
sub ObjectDup #($source, $objectid, $new_source, $pre, $post)
{
    my ($self, $source, $objectid, $new_source, $pre, $post) = @_;

    my $object = $self->Object($source, $objectid);

    if (! defined $parsedStreams{$source})
        {  die "Internal: $source was not previously loaded ...\n";  }

    my $srcObjects = $parsedStreams{$source}->Objects();

    if (! defined $parsedStreams{$new_source} )
        {  die "Internal: $new_source was not previously loaded ...\n";  }

    my $dstObjects = $parsedStreams{$new_source}->Objects();

    if (! defined $dstObjects)
        {  die "Internal: $new_source was not previously loaded ...\n";  }

    push @$dstObjects, $object;
    return @$dstObjects;
}


#
#   Function:   CopyTopic
#
#       Copy the specified 'topic' owned to a source stream, to the
#       new source stream 'new_source'.
#
#ND+, package/table
sub CopyTopic #(topic, source, new_source)
    {
    my ($self, $topic, $source, $new_source) = @_;

    if (! defined $parsedStreams{$source})
        {  die "Internal: $source was not previously loaded ...\n";  }

    if (! defined $parsedStreams{$new_source})
        {  die "Internal: $new_source was not previously loaded ...\n";  }

    my $clone = NaturalDocs::Parser::ParsedTopic->Clone($topic);

    if (my $body = $topic->Body())
        {
        # clone embedded table objects references ...
        $body =~ s/(<table=)([^>]+)(>)/$1.$self->ObjectDup($source,$2,$new_source).$3/ge;

        $clone->Body($body);                    # replace body
        }

    return $clone;
    }


#
#   Function: ParseSymbols
#
#       Processes the topics and class hierarchy encountered into the input
#       stream, reload the topics on demand if previously dropped using
#       <Drop>, updating the symbol information about the stream
#       maintained by <NaturalDocs::SymbolTable> and <NaturalDocs::Project>.
#
#       Note that the stream must have previously either <Loaded> or <Pushed>
#       into the parser.
#
#   Parameters:
#       source - The topic stream.
#
#ND+, package
sub ParseSymbols #(source)
    {
    my ($self, $source) = @_;

    # Retrieve stream topics, default menu title and language binding
    my $dropped;
    my $topics = $self->Topics($source, \$dropped);
    my $language = $self->Language($source);

    # Watch this parse so we detect any changes.
    NaturalDocs::SymbolTable->WatchFileForChanges($source);
    NaturalDocs::ClassHierarchy->WatchFileForChanges($source);
    NaturalDocs::SourceDB->WatchFileForChanges($source);

    foreach my $topic (@$topics)
        {
                                                #ND+, package/summaries
        next if ($topic->Summaries() == ::SUMMARIES_ONLY());

        my $type = $topic->Type();
        my $body = $topic->Body();

        # Add a symbol for the topic.

        if ($type eq ::TOPIC_CLASS())           #ND+, package
            {
            # If topic does not have a body (definition) treat it as a reference
            # not a symbol, allowing a class/package to split over multiple
            # source images.

            if ($body)  #TODO, $topic->IsDefinition())
                {                               # definition
                NaturalDocs::SymbolTable->AddSymbol($topic->Symbol(),
                        $source, $type, $topic->Prototype(), $topic->Summary());
                }
            else                                # otherwise, reference
                {
                NaturalDocs::SymbolTable->AddReference($topic->Symbol(), $source);
                }

            # Process the class hierarchy.

            if (defined (my $hierarchy = $self->Hierarchy($source)))
                {                               #ND+ - rethink ClassHierarchy() interface
                NaturalDocs::ClassHierarchy->WatchFileForChanges($source);

                foreach my $hier (@$hierarchy)
                    {
                    if (!defined $hier->{PARENT})
                        {  NaturalDocs::ClassHierarchy->AddClass($source, $hier->{CLASS});  }
                    else
                        {
                        NaturalDocs::ClassHierarchy->AddParentReference($source,
                                $hier->{CLASS}, $hier->{PARENT}, $hier->{SCOPE}, $hier->{USING}, $hier->{FLAGS}|::RESOLVE_NOPLURAL());
                        }
                    }

                NaturalDocs::ClassHierarchy->AnalyzeChanges();
                }
            }
        else
            {
            if ($type eq ::TOPIC_ENUMERATION())
                {  $type = ::TOPIC_TYPE();  };

            NaturalDocs::SymbolTable->AddSymbol($topic->Symbol(),
            $source, $type, $topic->Prototype(), $topic->Summary());
            }

        # If it's a list or enum topic, add a symbol for each description list entry.

        if ($topic->IsList() || $topic->Type() eq ::TOPIC_ENUMERATION())
            {
            # We'll hijack the enum constants to apply to non-enum behavior too.
            my $behavior;

            if ($topic->Type() eq ::TOPIC_ENUMERATION())
                {
                $type = ::TOPIC_CONSTANT();
                $behavior = $language->EnumValues();
                }
            elsif (NaturalDocs::Topics->TypeInfo($topic->Type())->Scope() == ::SCOPE_ALWAYS_GLOBAL())
                {
                $behavior = ::ENUM_GLOBAL();
                }
            else
                {
                $behavior = ::ENUM_UNDER_PARENT();
                };

            while ($body =~ /<ds>([^<]+)<\/ds><dd>(.*?)<\/dd>/g)
                {
                my ($listTextSymbol, $listSummary) = ($1, $2);

                $listTextSymbol = NaturalDocs::NDMarkup->RestoreAmpChars($listTextSymbol);
                my $listSymbol = NaturalDocs::SymbolString->FromText($listTextSymbol);

                if ($behavior == ::ENUM_UNDER_PARENT())
                    {  $listSymbol = NaturalDocs::SymbolString->Join($topic->Package(), $listSymbol);  }
                elsif ($behavior == ::ENUM_UNDER_TYPE())
                    {  $listSymbol = NaturalDocs::SymbolString->Join($topic->Symbol(), $listSymbol);  };

                NaturalDocs::SymbolTable->AddSymbol($listSymbol, $source, $type, undef,
                                $self->GetSummaryFromDescriptionList($listSummary));
                };
            };


        # Add references in the topic.

        while ($body =~ /<link target=\"([^\"]*)\" name=\"[^\"]*\" original=\"[^\"]*\">/g)
            {
            my $linkText = NaturalDocs::NDMarkup->RestoreAmpChars($1);
            my $linkSymbol = NaturalDocs::SymbolString->FromText($linkText);

            NaturalDocs::SymbolTable->AddReference(::REFERENCE_TEXT(), $linkSymbol,
                                $topic->Package(), $topic->Using(), $source);
            };

        # Add images in the topic.

        while ($body =~ /<img mode=\"[^\"]*\" target=\"([^\"]+)\" original=\"[^\"]*\">/g)
            {
            my $target = NaturalDocs::NDMarkup->RestoreAmpChars($1);
            NaturalDocs::ImageReferenceTable->AddReference($source, $target);
            };

        # Embedded Tables                       #ND+, tables

        while ($body =~ /<table=([^>]+)>/g)
            {
            my $table = $self->Object($source, $1);

            NaturalDocs::SymbolTable->AddSymbol($table->Title(),
                                $source, ::TOPIC_GENERIC(), undef, $table->Summary());

            $table->AddReferences($source, $topic);
            }
        };

    # Handle any changes to the file.
    NaturalDocs::ClassHierarchy->AnalyzeChanges();
    NaturalDocs::SymbolTable->AnalyzeChanges();
    NaturalDocs::SourceDB->AnalyzeWatchedFileChanges();

    # Update project on the file's characteristics.
    my ($hasContent) = (scalar @$topics > 0);

    NaturalDocs::Project->SetHasContent($source, $hasContent);
    if ($hasContent)
        {  NaturalDocs::Project->SetDefaultMenuTitle($source, $self->DefaultMenuTitle($source));  }

    # Drop locally loaded image
    if ($dropped)
        {  $self->Drop($source);  }

    return ($hasContent);
    };


#
#   Function: ParseForBuild
#
#       Retrieves the result of the file parser, reload the topics on demand
#       if previously dropped using <Drop> plus performing any required
#       final topic processing. returning it as a
#       <NaturalDocs::Parser::ParsedTopic> arrayref.
#
#       Topic processing involves the following;
#
#           o <CleanupAutoGroups>.
#           o <ApplyMergeAttributes>.
#           o <ApplySortAttributes>.
#           o <ApplySummariesAttributes>.
#           o <ApplyPageFooter>.
#
#       Note that all new and changed streams should be parsed for symbols via
#       <ParseSymbols> before calling this function on *any* stream.  The reason
#       is that <NaturalDocs::SymbolTable> needs to know about all the symbol
#       definitions and references to resolve them properly.
#
#   Parameters:
#
#       source - The topic stream to parse for building.
#
#   Returns:
#
#       Associated <Parsed|File> object.
#
#ND+, package
sub ParseForBuild #(source)
    {
    my ($self, $source) = @_;

    my $file = $self->ParsedFile($source);

    # Retrieve topics

    my $topics = $self->Topics($source);        # will be loaded if dropped.

    $self->CleanAutoGroups($source, $topics);

    # Apply attributes

    $self->ApplyMergeAttributes($source, $topics);

    $self->ApplySortAttributes($source, $topics);

    $self->ApplySummariesAttributes($source, $topics);

    $self->ApplyPageFooter($file, $topics);

    return $file;
    };


#
#   Function:   CleanupAutoGroups
#
#       Remove the auto-group within single topic image.
#
#   Parameters:
#
#       source - The topic stream being parsed.
#
#       topics - arrayref of the topics as <NaturalDocs::Parser::ParsedTopic> objects.
#
#ND+, package
sub CleanAutoGroups #(source, topics)
{
    my ($self, $source, $topics) = @_;
    my ($auto, $items) = (-1, 0);

    for (my $idx = 0; $idx < scalar @$topics && $items < 2; $idx++)
        {
        my $topic = $topics->[$idx];
        my $scope = NaturalDocs::Topics->TypeInfo($topic->Type())->Scope();

        if ($scope != ::SCOPE_START() && $scope != ::SCOPE_END())
            {
            if ($topic->Type() eq ::TOPIC_GROUP())
                {                               # new group
                if ($topic->IsAuto())
                    {  $auto = $idx;  }
                }
            else
                {  $items++;  }
            }
        }
    if ($items < 2 && $auto >= 0)               # remove
        {  splice @$topics, $auto, 1;  }
    };


#
#   Function:   ApplyMergeAttributes
#
#       Apply merge attributes to desired topic groups
#
#   Parameters:
#
#       source - The topic stream being parsed.
#
#       topics - arrayref of the topics as <NaturalDocs::Parser::ParsedTopic> objects.
#
#ND+, package
sub ApplyMergeAttributes #(source, topics)
{
    my ($self, $source, $topics) = @_;
    my ($status, $package, $section, $grouptitle, $grouptype) = (0, undef, undef, undef, undef);
    my $verbose = 0;

print "ApplyMergeAttributes ($source)\n"
    if ($verbose);

    for (my $idx = 0; $idx < scalar @$topics; $idx++)
        {
        my $topic = $topics->[$idx];
        my $typeinfo = NaturalDocs::Topics->TypeInfo ($topic->Type());
        my $scope = $typeinfo->Scope ();

        # Find group end

        if ($scope == ::SCOPE_START())
            { $status = 2; }                    # new section

        elsif ($scope == ::SCOPE_END())
            { $status = 3; }                    # global

        elsif ($topic->Type() eq ::TOPIC_GROUP())
            { $status = 1; }                    # new group

        elsif ($grouptitle && 0 == $status)
            {
            # First element within group test if merge is enabled
            #   by default Classes are always merged

            if ($topic->Type() ne ::TOPIC_CLASS() && ! $typeinfo->MergeGroupings())
                { $grouptitle = undef; }
            else                                # e.g. 'function'
                { $grouptype = $topic->Type(); }
            $status = -1;
            }

        # End of current group if a status change

        if ($status >= 1)
            {
            # Group start located

            if ($grouptitle)
                {
print "\tpkg=$package,\tscope=$scope,\ttype=" . $topic->Type() .
        ", grouptitle=$grouptitle,\tsymbol=" . $topic->Symbol() . "\n"
    if ($verbose);

                my $end = $idx;                 # end of previous group

                my $t_section = -1;             # current section start

                for (my $t_idx = $idx; $t_idx < scalar @$topics; $t_idx++)
                    {
            NEXT:;  my $t_topic = $topics->[$t_idx];
                    my $t_package = $t_topic->Package();
                    my $t_typeinfo = NaturalDocs::Topics->TypeInfo($t_topic->Type());
                    my $t_scope = $t_typeinfo->Scope();

print "\t\tpkg=$t_package,\tscope=$t_scope,\ttype=" . $t_topic->Type() .
        ",\tgrouptitle=" . $t_topic->Title() . ",\tsymbol=" . $t_topic->Symbol() . "\n"
    if ($verbose);

                    # Locate next matching scope

                    if ($t_scope == ::SCOPE_END())
                        {  $t_section = -1;  }

                    elsif ($t_scope == ::SCOPE_START())
                        {
                        if ($t_package eq $package)
                            {  $t_section = $t_idx;  }
                        else
                            {  $t_section = -1;  }
                        }

                    # Matching topic grouptitle (e.g function)

                    if ($t_section != -1)
                        {
                        if ($t_topic->Type() eq ::TOPIC_GROUP() &&
                                    $t_topic->Title() eq $grouptitle)
                            {
                            # remove group header

print "\t\t\tremoving group header\n"
    if ($verbose);

                            splice(@$topics, $t_idx, 1);

                            # foreach group member

                            while ($t_idx < scalar @$topics)
                                {
                                $t_topic = $topics->[$t_idx];
                                $t_typeinfo = NaturalDocs::Topics->TypeInfo($t_topic->Type());
                                $t_scope = $t_typeinfo->Scope();

print "\t\t\tpkg=" . $t_topic->Package() . ",\tscope=$t_scope,\ttype=" . $t_topic->Type() .
            ",\tgrouptitle=" . $t_topic->Title() . ",\tsymbol=" . $t_topic->Symbol() . "\n"
    if ($verbose);

                                # validate topic group

                                if ($t_scope == ::SCOPE_START() || $t_scope == ::SCOPE_END())
                                    {           # end of current section
                                    if ($t_section + 1 == $t_idx)
                                        {       # remove empty section header
                                        DeleteSection ($topics, $section, $t_section);
                                        $t_idx--;
                                        }
                                    goto NEXT;  # restart scan
                                    }
                                elsif ($t_topic->Type() eq ::TOPIC_GROUP())
                                    {                   # end of current group
                                    goto NEXT;  # restart scan
                                    }

                                # relocate topic

print "\t\t\trelocating (group)\n"
    if ($verbose);
                                splice(@$topics, $end++, 0, $t_topic);

                                splice(@$topics, ++$t_idx, 1);

                                if ($t_section >= 0)
                                    {           # side-effect of insert
                                    $t_section++;
                                    }
                                }
                            }
                        }

                    # or global within same package
                    #
                    #   this occurs in C++ when implicit class scoped definitions and
                    #   explicit (outside) the class definitions are mixed within
                    #   the same source.
                    #
                    #   For example:
                    #       class MyClass {
                    #               function();
                    #       };
                    #
                    #       MyClass::Function();
                    #

                    elsif (($t_topic->Type() eq $grouptype) && ($t_package eq $package))
                        {
print "\t\t\trelocating (global)\n"
    if ($verbose);

                            splice(@$topics, $end++, 0, $t_topic);
                            splice(@$topics, $t_idx + 1, 1);
                        };
                    };

                if ($t_section >= 0 && $t_section+1 == scalar @$topics)
                    {                           # remove empty section header
                    DeleteSection($topics, $section, $t_section);
                    }

                $idx = $end;    # start of new scan
                }

            # Setup next grouping (if any)
            if ($status == 2)                   # section
                {
                $section = $idx;
                $package = $topic->Package();
                $grouptitle = undef;
                $grouptype = undef;

print "\tstart: $package\tscope=$scope, type=" . $topic->Type() .
                    ", grouptitle=" . $topic->Title() . ", symbol=" . $topic->Symbol() . "\n"
    if ($verbose);

                }
            elsif ($status == 1)                # group
                {
                $grouptitle = $topic->Title();  # e.g. 'Functions'

print "\tgroup: $package\tscope=$scope, type=" . $topic->Type() .
                    ", grouptitle=" . $topic->Title() . ", symbol=" . $topic->Symbol() . "\n"
    if ($verbose);
                }

            else                                # global
                {
print "\tend:   $package\tscope=$scope, type=" . $topic->Type() .
                    ", grouptitle=" . $topic->Title() . ", symbol=" . $topic->Symbol() . "\n"
    if ($verbose);

                $section = undef;
                $package = undef;
                $grouptitle = undef;
                $grouptype = undef;
                }
            $status = 0;
            }
        }
    };


#
#   Function:   DeleteSection
#
#       Delete the summay header my merging the topics
#
#   Parameters:
#       prim -      Primary index
#
#       dup -       Duplicate index
#
#ND+, package
sub DeleteSection
    {
    my ($topics, $prim, $dup) = @_;

    # merge summary
    @$topics[$prim]->SetSummary(@$topics[$prim]->Summary() . @$topics[$dup]->Summary());

    # merge bodies
    @$topics[$prim]->SetBody(@$topics[$prim]->Body() . @$topics[$dup]->Body());

    # remove duplicate entry
    splice(@$topics, $dup, 1);
    }


#
#   Function:   ApplySortAttributes
#
#       Apply sort attributes to desired topic groups
#
#   Parameters:
#
#       source - The topic stream being parsed.
#
#       topics - arrayref of the topics as <NaturalDocs::Parser::ParsedTopic> objects.
#
#ND+, package
sub ApplySortAttributes #(source, topics)
{
    my ($self, $source, $topics) = @_;
    my ($status, $start, $end) = (0, -1, -1);

    for (my $idx = 0; $idx < scalar @$topics; $idx++)
        {
        my $topic = $topics->[$idx];
        my $typeinfo = NaturalDocs::Topics->TypeInfo($topic->Type());
        my $scope = $typeinfo->Scope();

        # Find sortable group start/end
        if ($scope == ::SCOPE_START() || $scope == ::SCOPE_END())
            {  $status = -1;  }                 # end (if any)

        elsif ($topic->Type() eq ::TOPIC_GROUP())
            {  $status = 1;  }                  # new group

        elsif ($end >= 0)
            {
            if ($typeinfo->SortGroupings())
                {  $end = $idx;  }              # extend group
            else
                {  $end = -1;  }                # not sortable
            }

        # Sort current group if a status change
        if ($status || ($end >= 0 && $idx+1 == scalar @$topics))
            {
            # At least two entries...
            if ($end > $start)
                {
                splice @$topics, $start, $end-$start+1, sort {
                            ::StringCompare($a->Title(), $b->Title())
                        } @{$topics}[$start .. $end];
                }

            # Setup next grouping
            $start = $idx+1;
            if ($status == 1)
                {  $end = $start;  }
            else
                {  $end = -1;  }
            $status = 0;
            }
        }
    }

#
#   Function:   ApplySummariesAttributes
#
#       Apply a topic summaries attributes.
#
#   Parameters:
#
#       source - The topic stream being parsed.
#
#       topics - arrayref of the topics as <NaturalDocs::Parser::ParsedTopic> objects.
#
#ND+, package
sub ApplySummariesAttributes #(source, topics)
{
    my ($self, $source, $topics) = @_;

    my ($group, $section) = (undef, undef);

    for (my $idx = 0; $idx < scalar @$topics; $idx++)
        {
        my $topic = $topics->[$idx];
        my $typeinfo = NaturalDocs::Topics->TypeInfo($topic->Type());
        my $scope = $typeinfo->Scope();

        if ($scope == ::SCOPE_START() || $scope == ::SCOPE_END())
            {
            if ($group)                         # close previous group
                {
                if ($section)                   # and section
                    {  $section->SetSummaries(::SUMMARIES_NO());  }
                $group->SetSummaries(::SUMMARIES_NO());
                }

            if ($topic->Summaries() == ::SUMMARIES_YES())
                {  $section = $topic;  }
            else
                {  $section = undef;  }
            $group = undef;
            }

        elsif ($topic->Type() eq ::TOPIC_GROUP())
            {
            if ($group)                         # close previous group
                {  $group->SetSummaries(::SUMMARIES_NO());  }

            if ($topic->Summaries() == ::SUMMARIES_YES())
                {  $group = $topic;  }
            else
                {  $group = undef;  }
            }

        elsif ($group)
            {                                   # summaries topic
            if ($typeinfo->DontSummaries() && $topic->Summaries() == ::SUMMARIES_YES())
                {  $topic->SetSummaries(::SUMMARIES_NO());  }
            else
                {  $group = undef;  }
            }
        }

    if ($group)                                 # close previous group
        {
        if ($section)                           # and section
            {  $section->SetSummaries(::SUMMARIES_NO());  }
        $group->SetSummaries(::SUMMARIES_NO());
        }
    };


#
#   Function:   ApplyPageFooter
#
#       Apply a pagefooter
#
#   Parameters:
#
#       file - The <ParsedFile> object of the parsed source.
#
#   Example:
#(start code)
#       "To send feedback on this topic *email:* feedback\@somewhere.org"
#       "<Copyright> (c) Somebody, Thier rights reserved.'";
#(end)
#
#ND+, package
sub ApplyPageFooter #(file, topics)
{
    my ($self, $file, $topics) = @_;

    if (! $parsedFooter &&
                (defined (my $footer = NaturalDocs::Menu->PageFooter())))
        {
        my $source = '__page/footer__.txt';

        # Format the body

        $footer =~ s/<br>/\n\n/g;               # break lines into paragraphs

        my @lines = split (/\n/, $footer);

        $parsedFooter = NaturalDocs::Parser::Native->FormatBody(
                                    $file, \@lines, 0, scalar @lines, ::TOPIC_GENERAL, 0);

        NaturalDocs::SymbolTable->WatchFileForChanges ($source);

        # Add references in the footer

        while ($parsedFooter =~ /<link target=\"([^\"]*)\" name=\"[^\"]*\" original=\"[^\"]*\">/g)
            {
            my $linkText = NaturalDocs::NDMarkup->RestoreAmpChars($1);
            my $linkSymbol = NaturalDocs::SymbolString->FromText($linkText);

            NaturalDocs::SymbolTable->AddReference(::REFERENCE_TEXT(), $linkSymbol,
                                undef, undef, $source);
            };

        # Add images in the footer

        while ($parsedFooter =~ /<img mode=\"[^\"]*\" target=\"([^\"]+)\" original=\"[^\"]*\">/g)
            {
            my $target = NaturalDocs::NDMarkup->RestoreAmpChars($1);
            NaturalDocs::ImageReferenceTable->AddReference($source, $target);
            };

        NaturalDocs::SymbolTable->AnalyzeChanges();
        }

    # Insert footer

    if ($parsedFooter)
        {                                       # insert pagefooter
        my $newtopic = NaturalDocs::Parser::ParsedTopic->New(::TOPIC_GENERAL,
                                undef, undef, undef, undef, undef, $parsedFooter);

        $newtopic->SetIsAuto(1);
        $newtopic->SetSummaries(::SUMMARIES_NO());

        push @$topics, $newtopic;
        }
    };


###############################################################################
# Group: Interface Functions

#
#   Function: OnComment
#
#       The function called by <NaturalDocs::Languages::Base>-derived objects when their parsers encounter a comment
#       suitable for documentation.
#
#   Parameters:
#
#       file - The <ParsedFile> object of the source file being parsed.
#       commentLines - An arrayref of the comment's lines.  The language's comment symbols should be converted to spaces,
#                               and there should be no line break characters at the end of each line.  *The original memory will be
#                               changed.*
#       lineNumber - The line number of the first of the comment lines.
#       isJavaDoc - Whether the comment is in JavaDoc format.
#
#   Returns:
#
#       The number of topics created by this comment, or zero if none.
#
sub OnComment #(ParsedFile file, string[] commentLines, int lineNumber, bool isJavaDoc)
    {
    my ($self, $file, $commentLines, $lineNumber, $isJavaDoc) = @_;

    # FIXME, remove parsedTopics/$parsedObjects arguments
    ($file->Topics()   == $parsedTopics)
        or die "OnComment() incorrect parsedTopics association\n";
    ($file->Objects()  == $parsedObjects)
        or die "OnComment() incorrect parsedObjects association\n";
    # FIXME

    $self->CleanComment($file->Language(), $commentLines);

    # We check if it's definitely Natural Docs content first.  This overrides all else, since it's possible that a comment could start
    # with a topic line yet have something that looks like a JavaDoc tag.  Natural Docs wins in this case.

    if (NaturalDocs::Parser::Native->IsMine($commentLines, $isJavaDoc))
        {  return NaturalDocs::Parser::Native->ParseComment($file, $commentLines, $isJavaDoc, $lineNumber, $parsedTopics); }

    elsif (NaturalDocs::Parser::JavaDoc->IsMine($commentLines, $isJavaDoc))
        {  return NaturalDocs::Parser::JavaDoc->ParseComment($file, $commentLines, $isJavaDoc, $lineNumber, $parsedTopics); }

    # If the content is ambiguous and it's a JavaDoc-styled comment, treat it as Natural Docs content.

    elsif ($isJavaDoc)
        {  return NaturalDocs::Parser::Native->ParseComment($file, $commentLines, $isJavaDoc, $lineNumber, $parsedTopics); }

    return 0;
    };


#
#   Function: OnClass
#
#       A function called by <NaturalDocs::Languages::Base>-derived objects when their parsers encounter a class declaration.
#
#   Parameters:
#
#       class - The <SymbolString> of the class encountered.
#
sub OnClass #(class)
    {
    my ($self, $class) = @_;

    if (defined $parsedHierarchy)
        {
        my $hier = {
                CLASS => $class
                };
        push @$parsedHierarchy, $hier;
        }
    };


#
#   Function: OnClassParent
#
#       A function called by <NaturalDocs::Languages::Base>-derived objects when their parsers encounter a declaration of
#       inheritance.
#
#   Parameters:
#
#       class - The <SymbolString> of the class we're in.
#       parent - The <SymbolString> of the class it inherits.
#       scope - The package <SymbolString> that the reference appeared in.
#       using - An arrayref of package <SymbolStrings> that the reference has access to via "using" statements.
#       resolvingFlags - Any <Resolving Flags> to be used when resolving the reference.  <RESOLVE_NOPLURAL> is added
#                              automatically since that would never apply to source code.
#
sub OnClassParent #(class, parent, scope, using, resolvingFlags)
    {
    my ($self, $class, $parent, $scope, $using, $resolvingFlags) = @_;

    if (defined $parsedHierarchy)
        {
        my $hier = {
                CLASS  => $class,
                PARENT => $parent,
                SCOPE  => $scope,
                USING  => $using,
                FLAGS  => $resolvingFlags
                };

        push @$parsedHierarchy, $hier;
        };
    };


#
#   Function:   OnObject
#
#       Set the object association with the source.
#
#   Returns:
#       Local object identifier
#
#ND+, table
sub OnObject #(object)
    {
    my ($self, $object) = @_;

    push @$parsedObjects, $object;

    return scalar @$parsedObjects;              # object identifier 1..x
    }


###############################################################################
# Group: Support Functions


#
#   Function: Parse
#
#       Opens the source file and parses process. Most of the actual parsing is done in
#       <NaturalDocs::Languages::Base->ParseFile()> and <OnComment()>, though.
#
#       *Do not call externally.*  Rather, call <ParseForInformation()> or <ParseForBuild()>.
#
#   Parameters:
#
#       file - ParsedFile object.
#
#       language - Optional language.
#
#   Returns:
#
#       Update the ParsedFile results.
#
sub Parse #(file, [language])
    {
    my ($self, $file, $language) = @_;

    my $sourceFile = $file->Source();

    NaturalDocs::Error->OnStartParsing($file);

    # Derive language
    if (! defined $language)
        {
        if (defined $file->Language())          # pre-defined
            {
            $language = $file->Language();
            }
        else
            {                                   # determine language
            $language = NaturalDocs::Languages->LanguageOf($sourceFile);
            $file->SetLanguage($language);
            }
        };

    NaturalDocs::Parser::Native->Start();

    if (defined $file->Modeline('nd') && 0 == $file->Modeline('nd'))
        {
        return;
        }

    my ($autoTopics, $scopeRecord) = $language->ParseFile($file, $parsedTopics);

    if (defined $file->Modeline('nd') && 0 == $file->Modeline('nd'))
        {
        # Non naturaldocs image, drop any content
        NaturalDocs::Error->OnEndParsing($file);
        $file->Topics([]);
        $file->Objects([]);
        return;
        };

    $self->AddToClassHierarchy();

    $self->BreakLists();

    if (defined $autoTopics)
        {
        if (defined $scopeRecord)
            {  $self->RepairPackages($autoTopics, $scopeRecord);  };

        $self->MergeAutoTopics($language, $autoTopics);
        };

    $self->RemoveRemainingHeaderlessTopics();

    # We don't need to do this if there aren't any auto-topics because the only package changes would be implied by the comments.
    if (defined $autoTopics)
        {  $self->AddPackageDelineators($language);  };

    if (!NaturalDocs::Settings->NoAutoGroup())
        {  $self->MakeAutoGroups($autoTopics);  };


    # Set the menu title.

    my $defaultMenuTitle = $sourceFile;

    if (scalar @$parsedTopics)
        {
        my $addFileTitle;

        if (NaturalDocs::Settings->OnlyFileTitles())
            {
            # We still want to use the title from the topics if the first one is a file.
            if ($$parsedTopics[0]->Type() eq ::TOPIC_FILE())
                {  $addFileTitle = 0;  }
            else
                {  $addFileTitle = 1;  };
            }
        elsif (scalar @$parsedTopics == 1 || NaturalDocs::Topics->TypeInfo( $$parsedTopics[0]->Type() )->PageTitleIfFirst())
            {  $addFileTitle = 0;  }
        else
            {  $addFileTitle = 1;  };

        if (!$addFileTitle)
            {
            $defaultMenuTitle = $$parsedTopics[0]->Title();
            }
        else
            {
            # If the title ended up being the file name, add a leading section for it.
            unshift @$parsedTopics,
                       NaturalDocs::Parser::ParsedTopic->New(::TOPIC_FILE(), $sourceFile,
                                        undef, undef, undef, undef, undef, 1, undef);
            };
        };

    $file->SetDefaultMenuTitle($defaultMenuTitle)
        if (! defined $file->DefaultMenuTitle());

    NaturalDocs::Error->OnEndParsing($file);

    };


#
#   Function: CleanComment
#
#       Removes any extraneous formatting and whitespace from the comment.  Eliminates comment boxes, horizontal lines, leading
#       and trailing line breaks, trailing whitespace from lines, and expands all tab characters.  It keeps leading whitespace, though,
#       since it may be needed for example code, and multiple blank lines, since the original line numbers are needed.
#
#   Parameters:
#
#       language  -  Language
#       commentLines  - An arrayref of the comment lines to clean.  *The original memory will be changed.*  Lines should have the
#                                language's comment symbols replaced by spaces and not have a trailing line break.
#
sub CleanComment #(language, commentLines)
    {
    my ($self, $language, $commentLines) = @_;

    use constant DONT_KNOW => 0;
    use constant IS_UNIFORM => 1;
    use constant IS_UNIFORM_IF_AT_END => 2;
    use constant IS_NOT_UNIFORM => 3;

    my $leftSide = DONT_KNOW;
    my $rightSide = DONT_KNOW;
    my $leftSideChar;
    my $rightSideChar;

    my $index = 0;
    my $tabLength;

    $tabLength = NaturalDocs::Settings->TabLength();    #ND+, tab&indent

    if (defined ($language) && defined $language->TabLength())
        {                                       # language override
        $tabLength = $language->TabLength();
        }

    while ($index < scalar @$commentLines)
        {
        # Strip trailing whitespace from the original.

        $commentLines->[$index] =~ s/[ \t]+$//;


        # Expand tabs in the original.  This method is almost six times faster than Text::Tabs' method.

        my $tabIndex = index($commentLines->[$index], "\t");

        while ($tabIndex != -1)
            {
            substr( $commentLines->[$index], $tabIndex, 1, ' ' x ($tabLength - ($tabIndex % $tabLength)) );
            $tabIndex = index($commentLines->[$index], "\t", $tabIndex);
            };


        # Make a working copy and strip leading whitespace as well.  This has to be done after tabs are expanded because
        # stripping indentation could change how far tabs are expanded.

        my $line = $commentLines->[$index];
        $line =~ s/^ +//;

        # If the line is blank...
        if (!length $line)
            {
            # If we have a potential vertical line, this only acceptable if it's at the end of the comment.
            if ($leftSide == IS_UNIFORM)
                {  $leftSide = IS_UNIFORM_IF_AT_END;  };
            if ($rightSide == IS_UNIFORM)
                {  $rightSide = IS_UNIFORM_IF_AT_END;  };
            }

        # If there's at least four symbols in a row, it's a horizontal line.  The second regex supports differing edge characters.  It
        # doesn't matter if any of this matches the left and right side symbols.  The length < 256 is a sanity check, because that
        # regexp has caused the perl regexp engine to choke on an insane line someone sent me from an automatically generated
        # file.  It had over 10k characters on the first line, and most of them were 0x00.
        elsif ($line =~ /^([^a-zA-Z0-9 ])\1{3,}$/ ||
                (length $line < 256 && $line =~ /^([^a-zA-Z0-9 ])\1*([^a-zA-Z0-9 ])\2{3,}([^a-zA-Z0-9 ])\3*$/) )
            {
#           # Convert the original to a blank line.
#           $commentLines->[$index] = '';       #ND+, ditaa/bug

            # This has no effect on the vertical line detection.
            }

        # If the line is not blank or a horizontal line...
        else
            {
            # More content means any previous blank lines are no longer tolerated in vertical line detection.  They are only
            # acceptable at the end of the comment.

            if ($leftSide == IS_UNIFORM_IF_AT_END)
                {  $leftSide = IS_NOT_UNIFORM;  };
            if ($rightSide == IS_UNIFORM_IF_AT_END)
                {  $rightSide = IS_NOT_UNIFORM;  };


            # Detect vertical lines.  Lines are only lines if they are followed by whitespace or a connected horizontal line.
            # Otherwise we may accidentally detect lines from short comments that just happen to have every first or last
            # character the same.

            if ($leftSide != IS_NOT_UNIFORM)
                {
                if ($line =~ /^([^a-zA-Z0-9])\1*(?: |$)/)
                    {
                    if ($leftSide == DONT_KNOW)
                        {
                        $leftSide = IS_UNIFORM;
                        $leftSideChar = $1;
                        }
                    else # ($leftSide == IS_UNIFORM)  Other choices already ruled out.
                        {
                        if ($leftSideChar ne $1)
                            {  $leftSide = IS_NOT_UNIFORM;  };
                        };
                    }

                # We'll tolerate the lack of symbols on the left on the first line, because it may be a
                # /* Function: Whatever
                #  * Description.
                #  */
                # comment which would have the leading /* blanked out.
                elsif ($index != 0)
                    {
                    $leftSide = IS_NOT_UNIFORM;
                    };
                };

            if ($rightSide != IS_NOT_UNIFORM)
                {
                if ($line =~ / ([^a-zA-Z0-9])\1*$/)
                    {
                    if ($rightSide == DONT_KNOW)
                        {
                        $rightSide = IS_UNIFORM;
                        $rightSideChar = $1;
                        }
                    else # ($rightSide == IS_UNIFORM)  Other choices already ruled out.
                        {
                        if ($rightSideChar ne $1)
                            {  $rightSide = IS_NOT_UNIFORM;  };
                        };
                    }
                else
                    {
                    $rightSide = IS_NOT_UNIFORM;
                    };
                };

            # We'll remove vertical lines later if they're uniform throughout the entire comment.
            };

        $index++;
        };


    if ($leftSide == IS_UNIFORM_IF_AT_END)
        {  $leftSide = IS_UNIFORM;  };
    if ($rightSide == IS_UNIFORM_IF_AT_END)
        {  $rightSide = IS_UNIFORM;  };


    my $inCodeSection;                          #ND+, ditaa/bug
    $index = 0;

    while ($index < scalar @$commentLines)
        {
        # Clear vertical lines.

        if ($leftSide == IS_UNIFORM)
            {
            # This works because every line should either start this way, be blank, or be the first line that doesn't start with a symbol.
            $commentLines->[$index] =~ s/^ *([^a-zA-Z0-9 ])\1*//;
            };

        if ($rightSide == IS_UNIFORM)
            {
            $commentLines->[$index] =~ s/ *([^a-zA-Z0-9 ])\1*$//;
            };

        # Code sections                         #ND+, ditaa/bug

        if ($inCodeSection)
            {                                   #ND+, ditaa/mscgen/sdedit/drawing
            if ($commentLines->[$index] =~ /^ *\( *(?:end|finish|done)(?: +(?:table|code|example|diagram|ditaa|mscgen|sdedit|drawing))? *\)$/)
                {  $inCodeSection = undef;  };
            }
                                                #ND+, ditaa/mscgen/sdedit/drawing
        elsif ($commentLines->[$index] =~ /^ *\( *(?:(?:start|begin)? +)(?:ditaa|mscgen|sdedit|drawing)([^\)]*)\)$/i ||
                    $commentLines->[$index] =~ /^ *\( *(?:(?:start|begin)? +)?(?:table|code|example|diagram) *\)$/i)
            {
            $inCodeSection = 1;
            }


        # If there's at least four symbols in a row, it's a horizontal line.

        else                                    #ND+, ditaa/bug
            {
            $commentLines->[$index] =~ s/^ *([^a-zA-Z0-9 ])\1{3,}$//;
            $commentLines->[$index] =~ s/^ *([^a-zA-Z0-9 ])\1*([^a-zA-Z0-9 ])\2{3,}([^a-zA-Z0-9 ])\3*$//;
            }

    #ND+, ditaa/bug
    #   # Clear horizontal lines again if there were vertical lines.  This catches lines that
    #   # were separated from the verticals by whitespace.  We couldn't do this in the first
    #   # loop because that would make the regexes over-tolerant.
    #
    #   elsif ($leftSide == IS_UNIFORM || $rightSide == IS_UNIFORM)
    #       {
    #       $commentLines->[$index] =~ s/^ *([^a-zA-Z0-9 ])\1{3,}$//;
    #       $commentLines->[$index] =~ s/^ *([^a-zA-Z0-9 ])\1*([^a-zA-Z0-9 ])\2{3,}([^a-zA-Z0-9 ])\3*$//;
    #       };

        $index++;
        };

    };



###############################################################################
# Group: Processing Functions


#
#   Function: RepairPackages
#
#   Recalculates the packages for all comment topics using the auto-topics and the scope record.  Call this *before* calling
#   <MergeAutoTopics()>.
#
#   Parameters:
#
#       autoTopics - A reference to the list of automatically generated <NaturalDocs::Parser::ParsedTopics>.
#       scopeRecord - A reference to an array of <NaturalDocs::Languages::Advanced::ScopeChanges>.
#
sub RepairPackages #(autoTopics, scopeRecord)
    {
    my ($self, $autoTopics, $scopeRecord) = @_;

    my $topicIndex = 0;
    my $autoTopicIndex = 0;
    my $scopeIndex = 0;

    my $topic = $$parsedTopics[0];
    my $autoTopic = $autoTopics->[0];
    my $scopeChange = $scopeRecord->[0];

    my $currentPackage;
    my $inFakePackage;

    while (defined $topic)
        {
        # First update the scope via the record if its defined and has the lowest line number.
        if (defined $scopeChange &&
                $scopeChange->LineNumber() <= $topic->LineNumber() &&
                    (!defined $autoTopic || $scopeChange->LineNumber() <= $autoTopic->LineNumber()) )
            {
            $currentPackage = $scopeChange->Scope();
            $scopeIndex++;
            $scopeChange = $scopeRecord->[$scopeIndex];  # Will be undef when past end.
            $inFakePackage = undef;
            }

        # Next try to end a fake scope with an auto topic if its defined and has the lowest line number.
        elsif (defined $autoTopic &&
                $autoTopic->LineNumber() <= $topic->LineNumber())
            {
            if ($inFakePackage)
                {
                $currentPackage = $autoTopic->Package();
                $inFakePackage = undef;
                };

            $autoTopicIndex++;
            $autoTopic = $autoTopics->[$autoTopicIndex];  # Will be undef when past end.
            }


        # Finally try to handle the topic, since it has the lowest line number.  Check for Type() because headerless topics won't have
        # one.
        else
            {
            my $scope;
            if ($topic->Type())
                {  $scope = NaturalDocs::Topics->TypeInfo($topic->Type())->Scope();  }
            else
                {  $scope = ::SCOPE_NORMAL();  };

            if ($scope == ::SCOPE_START() || $scope == ::SCOPE_END())
                {
                # They should already have the correct class and scope.
                $currentPackage = $topic->Package();
                $inFakePackage = 1;
                }
           else
                {
                # Fix the package of everything else.

                # Note that the first function or variable topic to appear in a fake package will assume that package even if it turns out
                # to be incorrect in the actual code, since the topic will come before the auto-topic.  This will be corrected in
                # MergeAutoTopics().

                $topic->SetPackage($currentPackage);
                };

            $topicIndex++;
            $topic = $$parsedTopics[$topicIndex];  # Will be undef when past end.
            };
        };

    };


#
#   Function: MergeAutoTopics
#
#   Merges the automatically generated topics into the file.  If an auto-topic matches an existing topic, it will have it's prototype
#   and package transferred.  If it doesn't, the auto-topic will be inserted into the list unless
#   <NaturalDocs::Settings->DocumentedOnly()> is set.  If an existing topic doesn't have a title, it's assumed to be a headerless
#   comment and will be merged with the next auto-topic or discarded.
#
#   Parameters:
#
#       language - The <NaturalDocs::Languages::Base>-derived class for the file.
#       autoTopics - A reference to the list of automatically generated topics.
#
sub MergeAutoTopics #(language, autoTopics)
    {
    my ($self, $language, $autoTopics) = @_;

    my $topicIndex = 0;
    my $autoTopicIndex = 0;
my $verbose = 0;

    # Keys are topic types, values are existence hashrefs of titles.
    my %topicsInLists;

print "MergeAutoTopics\n"
    if ($verbose);

    while ($topicIndex < scalar @$parsedTopics && $autoTopicIndex < scalar @$autoTopics)
        {
        my $topic = $$parsedTopics[$topicIndex];
        my $autoTopic = $autoTopics->[$autoTopicIndex];

        my $cleanTitle = $topic->Title();
        $cleanTitle =~ s/[\t ]*\([^\(]*$//;     #remove parameters

if ($verbose)
    {
    PrintTopic('topic', $topic);
    PrintTopic('auto', $autoTopic);
    }

        # Add the auto-topic if it's higher in the file than the current topic.
        if ($autoTopic->LineNumber() < $topic->LineNumber())
            {
            if (exists $topicsInLists{$autoTopic->Type()} &&
                exists $topicsInLists{$autoTopic->Type()}->{$autoTopic->Title()})
                {
                # Remove it from the list so a second one with the same name will be added.
                delete $topicsInLists{$autoTopic->Type()}->{$autoTopic->Title()};

print "==> remove-ref\n"
    if ($verbose);
                }
            elsif (! NaturalDocs::Settings->DocumentedOnly())
                {
                $self->ExpandElements($autoTopic, $autoTopic);

                splice(@$parsedTopics, $topicIndex, 0, $autoTopic);
                $topicIndex++;

print "==> auto-nondoc\n"
    if ($verbose);
                }
            else
                {
print "==> auto-keep\n"
    if ($verbose);
                };

            $autoTopicIndex++;
            }

        # Remove a headerless topic if there's another topic between it and the next auto-topic.
        elsif (!$topic->Title() && $topicIndex + 1 < scalar @$parsedTopics &&
                    $$parsedTopics[$topicIndex+1]->LineNumber() < $autoTopic->LineNumber())
            {
            splice(@$parsedTopics, $topicIndex, 1);

print "==> topic-remove\n"
    if ($verbose);
            }

        # Transfer information if we have a match or a headerless topic.
        elsif ( !$topic->Title() ||
                ($topic->Type() == $autoTopic->Type() && index($autoTopic->Title(), $cleanTitle) != -1))
            {
            # Import autotopic
            $topic->SetType($autoTopic->Type());

            if (! $topic->Prototype())          #ND+, prototype
                {  $topic->SetPrototype($autoTopic->Prototype());  };

            $topic->SetUsing($autoTopic->Using());

                                                #ND+, inline comments
            $self->ExpandElements($autoTopic, $topic);

            if (!$topic->Title())
                {  $topic->SetTitle($autoTopic->Title());  };

            if (NaturalDocs::Topics->TypeInfo($topic->Type())->Scope() != ::SCOPE_START())
                {  $topic->SetPackage($autoTopic->Package());  }
            elsif ($autoTopic->Package() ne $topic->Package())
                {
                my @autoPackageIdentifiers = NaturalDocs::SymbolString->IdentifiersOf($autoTopic->Package());
                my @packageIdentifiers = NaturalDocs::SymbolString->IdentifiersOf($topic->Package());

                while (scalar @autoPackageIdentifiers && $autoPackageIdentifiers[-1] eq $packageIdentifiers[-1])
                    {
                    pop @autoPackageIdentifiers;
                    pop @packageIdentifiers;
                    };

                if (scalar @autoPackageIdentifiers)
                    {  $topic->SetPackage( NaturalDocs::SymbolString->Join(@autoPackageIdentifiers) );  };
                };

            $topicIndex++;
            $autoTopicIndex++;

print "==> merged\n"
    if ($verbose);
            }

        # Extract topics in lists.
        elsif ($topic->IsList())
            {
            if (!exists $topicsInLists{$topic->Type()})
                {  $topicsInLists{$topic->Type()} = { };  };

            my $body = $topic->Body();

            while ($body =~ /<ds>([^<]+)<\/ds>/g)
                {  $topicsInLists{$topic->Type()}->{NaturalDocs::NDMarkup->RestoreAmpChars($1)} = 1;  };

            $topicIndex++;

print "==> islist\n"
    if ($verbose);
            }

        # Otherwise there's no match.  Skip the topic.  The auto-topic will be added later.
        else
            {
            $topicIndex++;

print "==> not-match\n"
    if ($verbose);
            }
        };

    # Add any auto-topics remaining.
    if (!NaturalDocs::Settings->DocumentedOnly())
        {
        while ($autoTopicIndex < scalar @$autoTopics)
            {
            my $autoTopic = $autoTopics->[$autoTopicIndex];

            if (exists $topicsInLists{$autoTopic->Type()} &&
                exists $topicsInLists{$autoTopic->Type()}->{$autoTopic->Title()})
                {
                # Remove it from the list so a second one with the same name will be added.
                delete $topicsInLists{$autoTopic->Type()}->{$autoTopic->Title()};
                }
            else
                {
                $self->ExpandElements($autoTopic, $autoTopic);
                push(@$parsedTopics, $autoTopic);
                };

            $autoTopicIndex++;
            };
        };
    };


sub PrintTopic #(title,topic,scope)
    {
    my ($label, $topic) = @_;

print "\t${label}" .
        " pkg=" .    $topic->Package() .
        ", type=" .  $topic->Type() .           #", symbol=" . $topic->Symbol() .
        ", title=" . $topic->Title() .
        ", body=" .  $topic->Body() .
        ", proto=" . $topic->Prototype() . "\n";
    my $elements = $topic->Elements();
    if ($elements)
        {
        foreach (@$elements)
            {
print "\t\t".$_->{NAME}."=".$_->{DESC}."\n";
            }
        }
    }

#
#   Function: ExpandElements
#
#       Expand topic elements
#
#ND+
sub ExpandElements
    {
    my ($self, $autoTopic, $topic) = @_;
    my $elements = $autoTopic->Elements();

    if ($elements &&
            ($autoTopic eq $topic ||
                $topic->Type() eq ::TOPIC_ENUMERATION() ||
                $topic->Type() eq ::TOPIC_TYPE() ||
                $topic->Type() eq ::TOPIC_FUNCTION()))
        {
        my $body = $topic->Body();

        $body .= "<dl>\n";
        foreach (@$elements)
            {
            $body .= "<ds>" . $_->{NAME} . "</ds><dd>" .
                        NaturalDocs::Parser::Native->RichFormatTextBlock($_->{DESC}) .
                        "</dd>";
            };
        $body .= "</dl>\n";
        $topic->SetBody($body);
        };
    };


#
#   Function: RemoveRemainingHeaderlessTopics
#
#   After <MergeAutoTopics()> is done, this function removes any remaining headerless topics from the file.  If they don't merge
#   into anything, they're not valid topics.
#
sub RemoveRemainingHeaderlessTopics
    {
    my ($self) = @_;

    my $index = 0;
    while ($index < scalar @$parsedTopics)
        {
        if ($$parsedTopics[$index]->Title())
            {  $index++;  }
        else
            {  splice(@$parsedTopics, $index, 1);  };
        };
    };


#
#   Function: MakeAutoGroups
#
#   Creates group topics for files that do not have them.
#
sub MakeAutoGroups
    {
    my ($self) = @_;

    # No groups only one topic.
    if (scalar @$parsedTopics < 2)
        {  return;  };

    my $index = 0;
    my $startStretch = 0;

    # Skip the first entry if its the page title.
    if (NaturalDocs::Topics->TypeInfo( $$parsedTopics[0]->Type() )->PageTitleIfFirst())
        {
        $index = 1;
        $startStretch = 1;
        };

    # Make auto-groups for each stretch between scope-altering topics.
    while ($index < scalar @$parsedTopics)
        {
        my $scope = NaturalDocs::Topics->TypeInfo($$parsedTopics[$index]->Type())->Scope();

        if ($scope == ::SCOPE_START() || $scope == ::SCOPE_END())
            {
            if ($index > $startStretch)
                {  $index += $self->MakeAutoGroupsFor($startStretch, $index);  };

            $startStretch = $index + 1;
            };

        $index++;
        };

    if ($index > $startStretch)
        {  $self->MakeAutoGroupsFor($startStretch, $index);  };
    };


#
#   Function: MakeAutoGroupsFor
#
#   Creates group topics for sections of files that do not have them.  A support function for <MakeAutoGroups()>.
#
#   Parameters:
#
#       startIndex - The index to start at.
#       endIndex - The index to end at.  Not inclusive.
#
#   Returns:
#
#       The number of group topics added.
#
sub MakeAutoGroupsFor #(startIndex, endIndex)
    {
    my ($self, $startIndex, $endIndex) = @_;

    # No groups if any are defined already.
    for (my $i = $startIndex; $i < $endIndex; $i++)
        {
        if ($$parsedTopics[$i]->Type() eq ::TOPIC_GROUP())
            {  return 0;  };
        };


    use constant COUNT => 0;
    use constant TYPE => 1;
    use constant SECOND_TYPE => 2;
    use constant SIZE => 3;

    # This is an array of ( count, type, secondType ) triples.  Count and Type will always be filled in; count is the number of
    # consecutive topics of type.  On the second pass, if small groups are combined secondType will be filled in.  There will not be
    # more than two types per group.
    my @groups;
    my $groupIndex = 0;


    # First pass: Determine all the groups.

    my $i = $startIndex;
    my $currentType;

    while ($i < $endIndex)
        {
        if (!defined $currentType ||
                ($$parsedTopics[$i]->Type() ne $currentType && $$parsedTopics[$i]->Type() ne ::TOPIC_GENERIC()))
            {
            if (defined $currentType)
                {  $groupIndex += SIZE;  };

            $currentType = $$parsedTopics[$i]->Type();

            $groups[$groupIndex + COUNT] = 1;
            $groups[$groupIndex + TYPE] = $currentType;
            }
        else
            {  $groups[$groupIndex + COUNT]++;  };

        $i++;
        };


    # Second pass: Combine groups based on "noise".  Noise means types go from A to B to A at least once, and there are at least
    # two groups in a row with three or less, and at least one of those groups is two or less.  So 3, 3, 3 doesn't count as noise, but
    # 3, 2, 3 does.

    $groupIndex = 0;

    # While there are at least three groups left...
    while ($groupIndex < scalar @groups - (2 * SIZE))
        {
        # If the group two places in front of this one has the same type...
        if ($groups[$groupIndex + (2 * SIZE) + TYPE] eq $groups[$groupIndex + TYPE])
            {
            # It means we went from A to B to A, which partially qualifies as noise.

            my $firstType = $groups[$groupIndex + TYPE];
            my $secondType = $groups[$groupIndex + SIZE + TYPE];

            if (NaturalDocs::Topics->TypeInfo($firstType)->CanGroupWith($secondType) ||
                NaturalDocs::Topics->TypeInfo($secondType)->CanGroupWith($firstType))
                {
                my $hasNoise;

                my $hasThrees;
                my $hasTwosOrOnes;

                my $endIndex = $groupIndex;

                while ($endIndex < scalar @groups &&
                         ($groups[$endIndex + TYPE] eq $firstType || $groups[$endIndex + TYPE] eq $secondType))
                    {
                    if ($groups[$endIndex + COUNT] > 3)
                        {
                        # They must be consecutive to count.
                        $hasThrees = 0;
                        $hasTwosOrOnes = 0;
                        }
                    elsif ($groups[$endIndex + COUNT] == 3)
                        {
                        $hasThrees = 1;

                        if ($hasTwosOrOnes)
                            {  $hasNoise = 1;  };
                        }
                    else # < 3
                        {
                        if ($hasThrees || $hasTwosOrOnes)
                            {  $hasNoise = 1;  };

                        $hasTwosOrOnes = 1;
                        };

                    $endIndex += SIZE;
                    };

                if (!$hasNoise)
                    {
                    $groupIndex = $endIndex - SIZE;
                    }
                else # hasNoise
                    {
                    $groups[$groupIndex + SECOND_TYPE] = $secondType;

                    for (my $noiseIndex = $groupIndex + SIZE; $noiseIndex < $endIndex; $noiseIndex += SIZE)
                        {
                        $groups[$groupIndex + COUNT] += $groups[$noiseIndex + COUNT];
                        };

                    splice(@groups, $groupIndex + SIZE, $endIndex - $groupIndex - SIZE);

                    $groupIndex += SIZE;
                    };
                }

            else # They can't group together
                {
                $groupIndex += SIZE;
                };
            }

        else
            {  $groupIndex += SIZE;  };
        };


    # Finally, create group topics for the parsed file.

    $groupIndex = 0;
    $i = $startIndex;

    while ($groupIndex < scalar @groups)
        {
        if ($groups[$groupIndex + TYPE] ne ::TOPIC_GENERIC())
            {
            my $topic = $$parsedTopics[$i];
            my $title = NaturalDocs::Topics->NameOfType($groups[$groupIndex + TYPE], 1);

            if (defined $groups[$groupIndex + SECOND_TYPE])
                {  $title .= ' and ' . NaturalDocs::Topics->NameOfType($groups[$groupIndex + SECOND_TYPE], 1);  };

            splice(@$parsedTopics, $i, 0, my $newtopic = NaturalDocs::Parser::ParsedTopic->New(::TOPIC_GROUP(),
                        $title,
                        $topic->Package(), $topic->Using(),
                        undef, undef, undef,
                        $topic->LineNumber()) );

            $newtopic->SetIsAuto(1);            #ND+, package
            $i++;
            };

        $i += $groups[$groupIndex + COUNT];
        $groupIndex += SIZE;
        };

    return (scalar @groups / SIZE);
    };


#
#   Function: AddToClassHierarchy
#
#       Adds any class topics to the class hierarchy, since they may not have been called with <OnClass()> 
#       if they didn't match up to an auto-topic.
#
sub AddToClassHierarchy
    {
    my ($self) = @_;

    foreach my $topic (@$parsedTopics)
        {
        if ($topic->Type() && NaturalDocs::Topics->TypeInfo( $topic->Type() )->ClassHierarchy())
            {
            if ($topic->IsList())
                {
                my $body = $topic->Body();

                while ($body =~ /<ds>([^<]+)<\/ds>/g)
                    {
                    $self->OnClass( NaturalDocs::SymbolString->FromText( NaturalDocs::NDMarkup->RestoreAmpChars($1) ) );
                    };
                }
            else
                {
                $self->OnClass($topic->Package());
                };
            };
        };
    };


#
#   Function: AddPackageDelineators
#
#       Adds section and class topics to make sure the package is correctly represented in the 
#       documentation.  Should be called last in this process.
#
sub AddPackageDelineators
    {
    my ($self, $language) = @_;

    my $index = 0;
    my $currentPackage;

##print "(D) AddPackageDelineators\n";

    # Values are the arrayref [ title, type ];
    my %usedPackages;

    while ($index < scalar @$parsedTopics)
        {
        my $topic = $$parsedTopics[$index];

        if ($topic->Package() ne $currentPackage)
            {
            $currentPackage = $topic->Package();
            my $scopeType = NaturalDocs::Topics->TypeInfo($topic->Type())->Scope();

            if ($scopeType == ::SCOPE_START())
                {
                $usedPackages{$currentPackage} = [ $topic->Title(), $topic->Type() ];
                }
            elsif ($scopeType == ::SCOPE_END())
                {
                my $newTopic;

                if (!defined $currentPackage)
                    {
                    $newTopic = NaturalDocs::Parser::ParsedTopic->New(::TOPIC_SECTION(), 'Global',
                                                    undef, undef, undef, undef, undef, $topic->LineNumber(), undef);
                    }
                else
                    {
                    my ($title, $body, $summary, $type);
                    my @packageIdentifiers = NaturalDocs::SymbolString->IdentifiersOf($currentPackage);

                    if (exists $usedPackages{$currentPackage})
                        {
                        $title = $usedPackages{$currentPackage}->[0];
                        $type = $usedPackages{$currentPackage}->[1];
                        $body = '<p>(continued)</p>';
                        $summary = '(continued)';
                        }
                    else
                        {
                        $title = join($language->PackageSeparator(), @packageIdentifiers);
                        $type = ::TOPIC_CLASS();

                        # Body and summary stay undef.

                        $usedPackages{$currentPackage} = $title;
                        };

                    my @titleIdentifiers = NaturalDocs::SymbolString->IdentifiersOf( NaturalDocs::SymbolString->FromText($title) );
                    for (my $i = 0; $i < scalar @titleIdentifiers; $i++)
                        {  pop @packageIdentifiers;  };

                    $newTopic = NaturalDocs::Parser::ParsedTopic->New($type, $title,
                                                    NaturalDocs::SymbolString->Join(@packageIdentifiers), undef,
                                                    undef, $summary, $body, $topic->LineNumber(), undef);
                    }

                splice(@$parsedTopics, $index, 0, $newTopic);
                $index++;
                }
            };

        $index++;
        };
    };


#
#   Function: BreakLists
#
#   Breaks list topics into individual topics.
#
sub BreakLists
    {
    my $self = shift;

    my $index = 0;

    while ($index < scalar @$parsedTopics)
        {
        my $topic = $$parsedTopics[$index];

        if ($topic->IsList() && NaturalDocs::Topics->TypeInfo( $topic->Type() )->BreakLists())
            {
            my $body = $topic->Body();

            my @newTopics;
            my $newBody;

            my $bodyIndex = 0;

            for (;;)
                {
                my $startList = index($body, '<dl>', $bodyIndex);

                if ($startList == -1)
                    {  last;  };

                $newBody .= substr($body, $bodyIndex, $startList - $bodyIndex);

                my $endList = index($body, '</dl>', $startList);
                my $listBody = substr($body, $startList, $endList - $startList);

                while ($listBody =~ /<ds>([^<]+)<\/ds><dd>(.*?)<\/dd>/g)
                    {
                    my ($symbol, $description) = ($1, $2);

                    push @newTopics, NaturalDocs::Parser::ParsedTopic->New( $topic->Type(), $symbol, $topic->Package(),
                                                                    $topic->Using(), undef,
                                                                    $self->GetSummaryFromDescriptionList($description),
                                                                    '<p>' . $description .  '</p>', $topic->LineNumber(), undef );
                    };

                $bodyIndex = $endList + 5;
                };

            $newBody .= substr($body, $bodyIndex);

            # Remove trailing headings.
            $newBody =~ s/(?:<h>[^<]+<\/h>)+$//;

            # Remove empty headings.
            $newBody =~ s/(?:<h>[^<]+<\/h>)+(<h>[^<]+<\/h>)/$1/g;

            if ($newBody)
                {
                unshift @newTopics, NaturalDocs::Parser::ParsedTopic->New( ::TOPIC_GROUP(), $topic->Title(), $topic->Package(),
                                                                    $topic->Using(), undef,
                                                                    $self->GetSummaryFromBody($newBody), $newBody,
                                                                    $topic->LineNumber(), undef );
                };

            splice(@$parsedTopics, $index, 1, @newTopics);

            $index += scalar @newTopics;
            }

        else # not a list
            {  $index++;  };
        };
    };


#
#   Function: GetSummaryFromBody
#
#       Returns the summary text from the topic body.
#
#   Parameters:
#
#       body - The complete topic body, in <NDMarkup>.
#
#   Returns:
#
#       The topic summary, or undef if none.
#
sub GetSummaryFromBody #(body)
    {
    my ($self, $body) = @_;

    my $summary;

    # Extract the first sentence from the leading paragraph, if any.  We'll tolerate a single header beforehand, but nothing else.

    if ($body =~ /^(?:<h>[^<]*<\/h>)?<p>(.*?)(<\/p>|[\.\!\?](?:[\)\}\'\ ]|&quot;|&gt;))/x)
        {
        $summary = $1;

        if ($2 ne '</p>')
            {  $summary .= $2;  };
        };

    return $summary;
    };


#
#   Function: GetSummaryFromDescriptionList
#
#       Returns the summary text from a description list entry.
#
#   Parameters:
#
#       description - The description in <NDMarkup>.  Should be the content between the <dd></dd> tags only.
#
#   Returns:
#
#       The description summary, or undef if none.
#
sub GetSummaryFromDescriptionList #(description)
    {
    my ($self, $description) = @_;

    my $summary;

    if ($description =~ /^(.*?)($|[\.\!\?](?:[\)\}\'\ ]|&quot;|&gt;))/)
        {  $summary = $1 . $2;  };

    return $summary;
    };

1;
