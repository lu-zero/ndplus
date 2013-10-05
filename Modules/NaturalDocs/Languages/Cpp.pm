##############################################################################
#
#   Class:          NaturalDocs::Languages::Cpp
#
###############################################################################
#
#   A subclass to handle the language variations of C++.
#
#   Topic:          Language Support
#
#       Supported:
#
#       - Namespaces (no topic generated)
#       - C linkage
#       - Classes/Struct/Unions
#       - Constants
#       - Constructors and Destructors
#       - Functions
#       - Operators
#       - Template (with limitations)
#       - Enums
#       - Variables
#
#       Not supported yet:
#
#       - Typedefs
#       - Friends (ignored)
#
###############################################################################

# This file is part of Natural Docs, which is Copyright (C) 2003-2005 Greg Valure
# This file is part of ND+, which is Copyright (C) 2007-2013 A.Young
# Natural Docs is licensed under the GPL

use strict;
use integer;

use NaturalDocs::Languages::Advanced::ScopeCpp;

package NaturalDocs::Languages::Cpp;

use base 'NaturalDocs::Languages::Advanced';


###############################################################################
#   Group:          Package Variables

my $cppdebug = 0;                               # XXX - debug level


#
#   Hash:           classKeywords
#       An existence hash of all the acceptable class keywords.  The keys are
#       in all lowercase.
#
my %classKeywords =   (
            'class'             => 2,
            'struct'            => 1,
            'union'             => 1
            );

#
#   Hash:           classModifiers
#       An existence hash of all the acceptable class modifiers.  The keys are in
#       all lowercase.
#
my %classModifiers = (
            'private'           => 1,
            'protected'         => 1,
            'public'            => 1,
            'static'            => 1,
            'virtual'           => 1
            );

#
#   Hash:           classScope
#       An existence hash of all the acceptable class scope modifiers. The keys are in
#       all lowercase.
#
my %classScope = (
            'public'            => 1,
            'protected'         => 1,
            'private'           => 1
            );

#
#   Hash:           functionStorageClass
#       An existence hash of all the acceptable function storage classes.
#       Also encompasses those for operators, but have more than are valid for them.
#       The keys are in all lowercase.
#
#   Others:
#       huge, near and far
#       interrupt
#       register
#
my %functionStorageClass = (
            '__based'           => 1,           # MSVC
            '_cdecl'            => 1,
            '__cdecl'           => 1,
            'const'             => 1,
            '_const'            => 1,
            '__declspec'        => 1,           # MSVC
            '__fastcall'        => 1,           # MSVC
            'extern'            => 1,
            'inline'            => 1,
            '__inline'          => 1,
            '__inline__'        => 1,
            'restrict'          => 1,           # c99
            '__restrict'        => 1,           # MSVC
            '__restrict__'      => 1,
            'static'            => 1,
            '__sptr'            => 1,           # MSVC
            '__stdcall'         => 1,           # MSVC
            '__unaligned'       => 1,           # MSVC
            '__uptr'            => 1,           # MSVC
            '__w64'             => 1,           # MSVC
            'virtual'           => 1
            );


my %functionAttributes = (
            '__attribute__'     => 1,           # gcc
            'const'             => 1,
            'throw'             => 1,
            '__restrict'        => 1,
            '__restrict__'      => 1
            );

#
#   Hash:           variableStorageClass
#       An existence hash of all the acceptable variable storage classes. The keys
#       are in all lowercase.
#
my %variableStorageClass = (
            'auto'              => 1,
            'const'             => 1,
            '__const'           => 1,
            '__const__'         => 1,
            'extern'            => 1,
            'register'          => 1,
            'restrict'          => 3,           # c99
            'static'            => 1,
            'typename'          => 2,           # C++
            'volatile'          => 1,
            '__volatile'        => 1
            );

#
#   Hash:           reservedWords
#       An hash of all the reserved words that cannot be in a types.
#
#       Values of 1 denote a C/C++ construct, otherwise 2 denotes a C++ only constructor.
#
my %reservedWords = (
            'asm'               => 1,
            '__asm'             => 1,
            '__asm__'           => 1,
            'auto'              => 1,
            'bool'              => 2,
            'break'             => 1,
            'case'              => 1,
            'catch'             => 2,
            'char'              => 1,
            'class'             => 2,
            'const'             => 1,
            '__const'           => 1,
            'const_cast'        => 2,
            'continue'          => 1,
            'default'           => 1,
            'delete'            => 2,
            'do'                => 1,
            'double'            => 1,
            'dynamic_cast'      => 2,
            'else'              => 1,
            'enum'              => 1,
            'explicit'          => 2,
            'export'            => 2,
            'extern'            => 1,
            'false'             => 2,
            'float'             => 1,
            'for'               => 1,
            'friend'            => 2,
            'goto'              => 1,
            'if'                => 1,
            'inline'            => 2,
            '__inline'          => 2,
            'int'               => 1,
            'long'              => 1,
            'mutable'           => 2,
            'namespace'         => 2,
            'new'               => 2,
            'operator'          => 2,
            'private'           => 2,
            'protected'         => 2,
            'public'            => 2,
            'register'          => 1,
            'reinterpret_cast'  => 2,
        #   'restrict'          => 1,           # c99
            '__restrict'        => 2,
            '__restrict__',     => 2,           # gcc
            'return'            => 1,
            'short'             => 1,
            'signed'            => 1,
            'sizeof'            => 1,
            'static'            => 1,
            'static_cast'       => 2,
            'struct'            => 1,
            'switch'            => 1,
            'template'          => 2,
            'this'              => 2,
            'throw'             => 2,
            'true'              => 2,
            'try'               => 2,
            'typedef'           => 1,
            'typeid'            => 2,
            'typename'          => 2,
            'union'             => 1,
            'unsigned'          => 1,
            'using'             => 2,
            'virtual'           => 2,
            'void'              => 1,
            'volatile'          => 1,
            '__volatile'        => 1,
            'wchar_t'           => 2,
            'while'             => 1,

        #rare
        #   'and'               => 2,
        #   'and_eq'            => 2,
        #   'bitand'            => 2,
        #   'bitor'             => 2,
        #   'compl'             => 2,
        #   'not'               => 2,
        #   'not_eq'            => 2,
        #   'or'                => 2,
        #   'or_eq'             => 2,
        #   'xor'               => 2,
        #   'xor_eq'            => 2
            );

#
#   Hash:           typeBuiltin
#       A type hash of all the reserved words that can be in a types.
#
my %typeBuiltins = (
            'bool'              => 1,           # bool
            'char'              => 2,           # unsigned char, long char
            'double'            => 2,
            'float'             => 2,
            'int'               => 2,
            'long'              => 2,           # unsigned long long, unsigned long int
            'longlong'          => 2,           # unsigned longlong
            '__longlong'        => 2,           # unsigned __longlong
            'short'             => 2,
            'unsigned'          => 2,
            '__unsigned'        => 2,
            'void'              => 1
            );

#
#   Hash:           classKeywords
#       An existence hash of all the acceptable type keywords.  The keys are
#       in all lowercase.
#
my %typeKeywords = (
            'class'             => 2,
            'enum'              => 1,
            'struct'            => 1,
            'union'             => 1
            );


#
#   Hash:           typesModifers
#       A type hash of all the reserved type modifiers
#
my %typeModifiers = (
            '&'                 => 1,           # c++, referenece
            '*'                 => 1,
            'restrict',         => 3,           # c99
            '__restrict',       => 1,
            '__restrict__',     => 1            # gcc
            );

###############################################################################
#   Group:          Interface Functions
#

#
#   Function:       PackageSeparator
#       Returns the package separator symbol.
#
sub
PackageSeparator
    {  return '::';  };


#
#   Function:       EnumValues
#       Returns the <EnumValuesType> that describes how the language handles enums.
#
sub
EnumValues
    {  return ::ENUM_UNDER_TYPE();  };


#
#   Function:       ParsePrototype
#       Parses the prototype and returns it as a <NaturalDocs::Languages::Prototype> object.
#
#   Parameters:
#       type -          The <TopicType>.
#       prototype -     The text prototype.
#
#   Returns:
#
#       A <NaturalDocs::Languages::Prototype> object.
#
sub ParsePrototype #(type, prototype)
    {
    my ($self, $type, $prototype, $isClass) = @_;

    if ($type eq ::TOPIC_ENUMERATION() || $type eq ::TOPIC_TYPE())
        {  $isClass = 1;  }                     # Allow '{ .. }' as delimiter

print "cpp: ParsePrototype ($type, $prototype)\n"
    if ($cppdebug >= 1);

    return $self->SUPER::ParsePrototype($type, $prototype, $isClass);
    }


#
#   Function:       ParseParameterLine
#       Parses a prototype parameter line and returns it as a
#       <NaturalDocs::Languages::Prototype::Parameter> object.
#
sub ParseParameterLine #(line)
    {
    my ($self, $line) = @_;

print "cpp: ParseParmeterLine ($line)\n"
    if ($cppdebug >= 1);

    return $self->SUPER::ParseParameterLine($line);
    }


#
#   Function: ParseFile
#       Parses the passed source file, sending comments acceptable for
#       documentation to <NaturalDocs::Parser->OnComment()>.
#
#   Parameters:
#       file - The <ParsedFile> object of the source file to parse.
#       topicList - A reference to the list of <NaturalDocs::Parser::ParsedTopics> being built by the file.
#
#   Returns:
#
#       The array ( autoTopics, scopeRecord ).
#
#       autoTopics - An arrayref of automatically generated topics from the file, or undef if none.
#       scopeRecord -  An arrayref of <NaturalDocs::Languages::Advanced::ScopeChanges>, or undef if none.
#
sub ParseFile #(file, topicsList)
    {
    my ($self, $file, $topicsList) = @_;
    my $sourceFile = $file->Source();           #ND+, package/modeline

    $self->ParseForCommentsAndTokens($file, ['//'], ['/*', '*/'], ['///'], ['/**', '*/']);

    my $tokens = $self->Tokens();
    my $index = 0;
    my $lineNum = 1;

    # Don't need to keep these around.
    while ($index < scalar @$tokens)
        {
print "cpp: $lineNum: $tokens->[$index] $tokens->[$index+1] $tokens->[$index+2]\n"
    if ($cppdebug >= 2);

        if ($self->SkipWhitespace(\$index, \$lineNum) ||
            $self->TryUsing(\$index, \$lineNum) ||
            $self->TryNamespace(\$index, \$lineNum) ||
            $self->TryLinkage(\$index, \$lineNum) ||
            $self->TryTypedefs(\$index, \$lineNum) ||
            $self->TryFriends(\$index, \$lineNum) ||
            $self->TryClass(\$index, \$lineNum) ||
            $self->TryScope(\$index, \$lineNum) ||
            $self->TryFunction(\$index, \$lineNum) ||
            $self->TryEnumeration(\$index, \$lineNum) ||
            $self->TryVariable(\$index, \$lineNum) )
            {
            # The functions above will handle everything.
            }
        elsif ($tokens->[$index] eq '{')
            {
print "cpp: newscope/brace\n"
    if ($cppdebug >= 2);

            $self->StartScope('}', $lineNum, undef, undef, undef);
            $index++;
            }
        elsif ($tokens->[$index] eq '}')
            {
            if ($self->ClosingScopeSymbol() eq '}')
                {  
print "cpp: endscope ($lineNum)\n"
    if ($cppdebug >= 2);

                $self->EndScope($lineNum);
                };
            $index++;
            }
        else
            {
            $self->SkipRestOfStatement(\$index, \$lineNum);
            };
        };

    # Convert structs/unions from classes to types
    $self->ConvertClasses();

    # Cleanup
    $self->ClearTokens();

    my $scopeRecord = $self->ScopeRecord();
    if (defined $scopeRecord && !scalar @$scopeRecord)
        {  $scopeRecord = undef;  };

    return ($self->AutoTopics(), $scopeRecord);
    };


#
#   Function:       NewScope
#       Create a new scope record
#
sub NewScope
    {
    my $self = shift;

    my $scope = $self->Scope();

print "cpp: newscope(@_)\n"
    if ($cppdebug);

    if ($scope)
        {
        my $linkage = $self->Scope()->Linkage();
        my $namespace = $self->Scope()->Namespace();

        return NaturalDocs::Languages::Advanced::ScopeCpp->New($linkage, $namespace, @_);
        };

    return NaturalDocs::Languages::Advanced::ScopeCpp->New(undef, undef, @_);
    };


#
#   Function:       ConvertClasses
#       Convert struct/union definitions which only contain variables from classes to simple types.
#
sub ConvertClasses
    {
    my ($self) = @_;

    my $autoTopics   = $self->AutoTopics();
    my $autoIndex    = 0;
    my $startStruct  = -1;
    my $startPackage = '';

print "cpp: convert structs/unions\n"
    if ($cppdebug >= 1);

    if (defined $autoTopics)
        {
        while ($autoIndex < scalar @$autoTopics)
            {
            my $autoTopic = $autoTopics->[$autoIndex];
            my $autoScope = NaturalDocs::Topics->TypeInfo($autoTopic->Type())->Scope();

            if ($autoScope == ::SCOPE_START())
                {
print "\t--scope-start--\n"
    if ($cppdebug >= 2);

                if ($autoTopic->Attribute('struct'))
                    {
PrintTopic('struct1', $autoTopic, $autoScope)
    if ($cppdebug >= 2);

                    $startStruct = $autoIndex;
                    $startPackage = $autoTopic->Package();
                    }
                else
                    {
                    $startStruct = -1;
                    };
                }

            elsif ($startStruct >= 0)
                {
PrintTopic('struct2', $autoTopic, $autoScope)
    if ($cppdebug >= 2);

                if ($autoScope == ::SCOPE_END() ||
                        ($startPackage ne $autoTopic->Package()))
                    {
print "\t--scope-end--\n"
    if ($cppdebug >= 2);

                    if ($startStruct >= 0)
                        {
                        # Struct elements,
                        #   compress into a single topic
                        my $structTopic = $autoTopics->[$startStruct];
                        my $prototype = $structTopic->Prototype();
                        my @elements;

                        $prototype .= "{";
                        for (my $idx = $startStruct+1; $idx < $autoIndex; $idx++)
                            {
                            my $topic = $autoTopics->[$idx];

PrintTopic('MERGE', $topic, $autoScope)
    if ($cppdebug >= 2);

                            $prototype .= " " . $topic->Prototype() . ";";
                            push @elements, {
                                    NAME => $topic->Title(),
                                    DESC => $topic->Body()
                                    };
                            };
                        $prototype .= "};";

                        splice @$autoTopics, $startStruct + 1, ($autoIndex - $startStruct) - 1;

                        # Create struct
                        $structTopic->SetType(::TOPIC_TYPE());
                        $structTopic->SetPackage($startPackage);
                        $structTopic->SetPrototype($prototype);
                        $structTopic->SetElements(\@elements);

                        my $structScope =
                                NaturalDocs::Topics->TypeInfo($structTopic->Type())->Scope();

PrintTopic('RESULT', $structTopic, $structScope)
    if ($cppdebug >= 2);

                        $autoIndex = $startStruct;
                        $startPackage = undef;
                        $startStruct = -1;
                        };
                    }
                else
                    {
                    if ($autoTopic->Type ne ::TOPIC_VARIABLE())
                        {
                        $startStruct = -1;
                        };
                    };
                }
            else
                {
PrintTopic('PKG', $autoTopic, $autoScope)
    if ($cppdebug >= 2);

                $startStruct = -1;
                };

            $autoIndex++;
            };
        };
    };


sub PrintTopic #(title,topic,scope)
{
    my ($label, $topic, $scope) = @_;

print "\t${label}" .
        "pkg=" . $topic->Package() .
        ", scope=" .  $scope .
        ", type=" .   $topic->Type() .      
        ", symbol=" . $topic->Symbol() .
        ", title=" .  $topic->Title() .     
        ", body=" .   $topic->Body() .
        ", proto=" .  $topic->Prototype() . "\n";
    my $elements = $topic->Elements();
    if ($elements) 
        {
        foreach (@$elements) 
            {
print "\t\t".$_->{NAME}."=".$_->{DESC}."\n";
            }
        }
}



###############################################################################
#   Group:          Statement Parsing Functions
#
#       All functions here assume that the current position is at the
#       beginning of a statement.
#

#
#   Function:       TryUsing
#       Determines whether the position is at a namespace using statement,
#       and if so, adjusts the scope, skips it, and returns true.
#
#   Supports:
#       using namespace 'name';
#
sub TryUsing  #(indexRef, lineNumRef)
    {
    my ($self, $indexRef, $lineNumRef) = @_;
    my $tokens = $self->Tokens();

    if ($tokens->[$$indexRef] ne 'using')
        {  return undef;  }

    my $index = $$indexRef+1;                   # consume 'using'
    my $lineNum = $$lineNumRef;

    $self->SkipWhitespace(\$index, \$lineNum);

    if ($tokens->[$index++] ne 'namespace')
        {  return undef;  };

    my $name = $self->GetIdentifier(\$index, \$lineNum);

    if (! defined $name)
        {  return undef;  };

    $self->SkipTerminator(\$index, \$lineNum, ';');

print "cpp: using namespace $name;\n"
    if ($cppdebug >= 1);

    $self->AddUsing(NaturalDocs::SymbolString->FromText($name));

    $$indexRef = $index;
    $$lineNumRef = $lineNum;

    return 1;
    };

#
#   Function:       TryNamespace
#       Determines whether the position is at a namespace declaration
#       statement, and if so, adjusts the scope, skips it, and returns true.
#
#   Why no topic?:
#
#       The main reason we don't create a Natural Docs topic for a namespace
#       is because in order to declare class A.B.C in C#, you must do this:
#
#       > namespace A.B
#       >    {
#       >    class C
#       >        { ... }
#       >    }
#
#       That would result in a namespace topic whose only purpose is really to
#       qualify C. It would take the default page title, and thus the default
#       menu title. So if you have files for A.B.X, A.B.Y, and A.B.Z, they all
#       will appear as A.B on the menu.
#
#       If something actually appears in the namespace besides a class, it
#       will be handled by <NaturalDocs::Parser->AddPackageDelineators()>.
#       That function will add a package topic to correct the scope.
#
#       If the user actually documented it, it will still appear because of
#       the manual topic.
#
#   Supported:
#
#       - namespace [name] {  }
#
#   Unsupported:
#
#       - namespace with an alias
#
sub TryNamespace #(indexRef, lineNumRef)
    {
    my ($self, $indexRef, $lineNumRef) = @_;
    my $tokens = $self->Tokens();

    if ($tokens->[$$indexRef] ne 'namespace')
        {  return undef;  }

    # namespace ...

    my $index = $$indexRef+1;                   # consume 'namespace'
    my $lineNum = $$lineNumRef;

    my $name = $self->GetIdentifier(\$index, \$lineNum);

    my $token = $tokens->[$index++];

    if ($token eq '=')
        {
        # namespace 'alias' = 'name';

        if (! defined $name)                    # name required
            {  return undef;  };

        my $equiv = $self->GetIdentifier(\$index, \$lineNum);
        if (! defined $equiv)
            {  return undef;  };

        $self->SkipTerminator(\$index, \$lineNum, ';');

print "cpp: namespace $name = $equiv;\n"
    if ($cppdebug >= 1);
        }

    elsif ($token eq '{')
        {
        # namespace [name] { .. }
        if (defined $name)
            {
            $name =~ s/\s+/ /g;                 # compress image

            my $autoTopic = NaturalDocs::Parser::ParsedTopic->New(::TOPIC_CLASS(), $name,
                                $self->CurrentScope(), undef, undef, undef, undef, $$lineNumRef);

            # we don't add an auto-topic for namespaces (see above)
            NaturalDocs::Parser->OnClass($autoTopic->Package());

print "cpp: newscope/namespace\n"
    if ($cppdebug >= 2);

            $self->StartScope('}', $lineNum, $autoTopic->Package());
            }
        else
            {                                   # XXX - '__unnamed__' name-space
print "cpp: newscope/namespace\n"
    if ($cppdebug >= 2);

            $self->StartScope('}', $lineNum, undef);
            };

print "cpp: namespace $name { .. }\n"
    if ($cppdebug >= 1);
        }

    else
        {
        return undef;
        };

    $$indexRef = $index;
    $$lineNumRef = $lineNum;

    return 1;
    };


#
#   Function:       TryLinkage
#        Determines whether the position is at a linkage declaration
#
sub TryLinkage #(indexRef, lineNumRef)
    {
    my ($self, $indexRef, $lineNumRef) = @_;
    my $tokens = $self->Tokens();

    my $index = $$indexRef;
    my $lineNum = $$lineNumRef;

    my $name = $self->GetLinkage(\$index, \$lineNum);
    if (! defined $name)
        {  return undef;  };

    if ($tokens->[$index++] ne '{')
        {  return undef;  };

print "cpp: newscope/linkage\n"
    if ($cppdebug >= 2);

    $self->StartScope('}', $lineNum, undef);    # reset scope

    $self->Scope()->SetLinkage($name);

    $$indexRef = $index;
    $$lineNumRef = $lineNum;

    return 1;
    };


#
#   Function:       TryToTypedefs
#       Determines whether the position is at a typedef declaration, and if
#       so, xxxx
#
#   Supported Syntaxes:
#
#       - Typedefs
#
sub TryTypedefs #(indexRef, lineNumRef)
    {
    my ($self, $indexRef, $lineNumRef) = @_;
    my $tokens = $self->Tokens();

    my $index = $$indexRef;
    my $lineNum = $$lineNumRef;

    if ($tokens->[$index++] ne 'typedef')
        {  return undef;  };

    # struct/union
    # enum
    # variables

    $$indexRef = $index;
    $$lineNumRef = $lineNum;

    return 1;
    };


#
#   Function:       TryFriends
#       Determines whether the position is at a friend declaration, and if so skip
#
#   Supported Syntaxes:
#
#       - friend class/function
#
sub TryFriends #(indexRef, lineNumRef)
    {
    my ($self, $indexRef, $lineNumRef) = @_;
    my $tokens = $self->Tokens();

    my $index = $$indexRef;
    my $lineNum = $$lineNumRef;

    if ($tokens->[$index++] ne 'friend')
        {  return undef;  };

    $self->SkipRestOfStatement(\$index, \$lineNum);

    $$indexRef = $index;
    $$lineNumRef = $lineNum;

    return 1;
    };


#
#   Function:       TryClass
#       Determines whether the position is at a class declaration statement,
#       and if so, generates a topic for it, skips it, and returns true.
#
#   Supported Syntaxes:
#
#       - classes
#       - structs
#       - Unions
#
sub TryClass #(indexRef, lineNumRef)
    {
    my ($self, $indexRef, $lineNumRef) = @_;
    my $tokens = $self->Tokens();

    my $index = $$indexRef;
    my $lineNum = $$lineNumRef;

    my @modifiers;

    my $template = $self->GetTemplate(\$index, \$lineNum);
    if (defined $template)
        {  push @modifiers, $template;  }

    while ($tokens->[$index] =~ /^[a-z]/i &&
                exists $classModifiers{$tokens->[$index]} &&
                !exists $classKeywords{$tokens->[$index]})
        {
        push @modifiers, $tokens->[$index++];

        $self->SkipWhitespace(\$index, \$lineNum);
        };

    if (!exists $classKeywords{$tokens->[$index]})
        {  return undef;  };

    my $classKeyword = $tokens->[$index++];

    my $name = $self->GetIdentifier(\$index, \$lineNum);

    if (! defined $name)                        # XXX - unnamed struct/union !!
        {  return undef;  };

    my @parents;

    if ($tokens->[$index] eq ':')
        {
        do {
            $index++;                           # consume ':' or ','

            $self->SkipWhitespace(\$index, \$lineNum);

            my @parentModifiers;

            while ($tokens->[$index] =~ /^[a-z]/i &&
                        exists $classModifiers{$tokens->[$index]})
                {
                push @parentModifiers, $tokens->[$index++];

                $self->SkipWhitespace(\$index, \$lineNum);
                }

            my $parentName = $self->GetIdentifier(\$index, \$lineNum);

            if (defined $parentName)
                {  $parentName = $self->GetTemplate(\$index, \$lineNum, $parentName);  };

            if (! defined $parentName)
                {  return undef;  };

            $parentName = NaturalDocs::SymbolString->FromText($parentName);

            push @parents, $parentName;

            $self->SkipWhitespace(\$index, \$lineNum);
            }
        while ($tokens->[$index] eq ',');
        };

    if ($tokens->[$index] eq ';')               # forward reference, consume
        {
        $index++;

        $$indexRef = $index;
        $$lineNumRef = $lineNum;
        return 1;
        }

    if ($tokens->[$index++] ne '{')
        {  return undef;  };

    # If we made it this far, we have a valid class declaration.
    my $prototype = $self->GetPrototype($$indexRef, $index - 1);

print "cpp: $classKeyword $name\n" .
      "     ==> $prototype\n"
    if ($cppdebug >= 1);

    my @scopeIdentifiers = NaturalDocs::SymbolString->IdentifiersOf($self->CurrentScope());
    $name = join('.', @scopeIdentifiers, $name);

    $name =~ s/\s+/ /g;                         # compress image

    my $autoTopic = NaturalDocs::Parser::ParsedTopic->New(::TOPIC_CLASS(), $name,
                        undef, $self->CurrentUsing(), $prototype, undef, undef, $$lineNumRef);

    if (($classKeywords{$classKeyword} eq 1) && !scalar @parents)
        {                                       # possible struct
        $autoTopic->SetAttribute('struct');
        }

    $self->AddAutoTopic($autoTopic);
    NaturalDocs::Parser->OnClass($autoTopic->Package());

    foreach my $parent (@parents)
        {
print "cpp: ==> parent $parent\n"
    if ($cppdebug >= 1);

        NaturalDocs::Parser->OnClassParent($autoTopic->Package(),
                        $parent, $self->CurrentScope(), undef, ::RESOLVE_RELATIVE());
        };

print "cpp: newscope/class\n"
    if ($cppdebug >= 2);

    $self->StartScope('}', $lineNum, $autoTopic->Package());

    $$indexRef = $index;
    $$lineNumRef = $lineNum;

    return 1;
    };

#
#   Function:       TryScope
#       Determines whether the position is at a class declaration statement,
#       and if so, generates a topic for it, skips it, and returns true.
#
#   Supported Syntaxes:
#
#       - private:
#       - protected:
#       - public:
#
sub TryScope #(indexRef, lineNumRef)
    {
    my ($self, $indexRef, $lineNumRef) = @_;
    my $tokens = $self->Tokens();

    my $index = $$indexRef;
    my $lineNum = $$lineNumRef;

    if ($tokens->[$index] =~ /^[a-z]/i &&
                exists $classScope{$tokens->[$index]})
        {
        my $scope = $tokens->[$index++];

        $self->SkipWhitespace(\$index, \$lineNum);

        if ($tokens->[$index] eq ':')
            {
print "cpp: scope $scope\n"
    if ($cppdebug >= 2);

            #XXX - generate topic!!
            $$indexRef = $index + 1;
            $$lineNumRef = $lineNum;
            return 1;
            }
        }

    return undef;
    };


#
#   Function:       TryFunction
#       Determines if the position is on a function declaration, and if so,
#       generates a topic for it, skips it, and returns true.
#
#   Supported Syntaxes:
#
#       - Functions
#       - Operators
#       - Constructors
#       - Destructors
#
sub TryFunction #(indexRef, lineNumRef)
    {
    my ($self, $indexRef, $lineNumRef) = @_;
    my $tokens = $self->Tokens();

    my $index = $$indexRef;
    my $lineNum = $$lineNumRef;

    my @modifiers;
    my @attributes;

    # Linkage
    my $language = 'C++';                       # XXX - $self->Language()

    my $linkage = $self->GetLinkage(\$index, \$lineNum);

    if ($language eq 'C++')
        {
        my $template = $self->GetTemplate(\$index, \$lineNum);

        push @modifiers, $template
            if (defined $template);
        };

    # Storage Class
    while ($tokens->[$index] =~ /^[a-z_]/i &&
                exists $functionStorageClass{$tokens->[$index]})
        {
        if ($tokens->[$index] eq 'static' && $language eq 'C++')
            {  push @attributes, $tokens->[$index];  }
        else
            {  push @modifiers, $tokens->[$index];  };
        $index++;

        $self->SkipWhitespace(\$index, \$lineNum);

        if ($tokens->[$index] eq '(')           # __attribute__ () and __declspec ()
            {
            $index++;
            $self->SkipTerminator(\$index, \$lineNum, ')');
            $self->SkipWhitespace(\$index, \$lineNum);
            };
        };

    # Type
    my $returnType = $self->TryType(\$index, \$lineNum);

    # Identifier and template arguments
    my $name = $self->GetIdentifier(\$index, \$lineNum);

    if (defined $name)
        {  $name = $self->GetTemplate(\$index, \$lineNum, $name);  };

    # Names can be multiple parts
    $name = $self->GetIdentifier(\$index, \$lineNum, $name);

    if (! defined $name)
        {
        #  Constructors and destructors don't have return types. It's
        #  possible their names were mistaken for the return type.

        if (! defined $returnType)
            {  return undef;  }

        $name = $returnType;
        $returnType = undef;
        };

    $self->SkipWhitespace(\$index, \$lineNum);

    # Operator or Functions, Constructors and Destructors
    my $baseName;

    my @parts = split(/::/, $name);
    my $scope = $self->CurrentScope();

    my $what;

    if ($language eq 'C++' && $tokens->[$index] eq 'operator')
        {
        $index++;
        $self->SkipWhitespace(\$index, \$lineNum);

        $what = 'operator';
        $name = "$what ";

        my $token = $tokens->[$index];
        my $once = 1;

        while ($token =~ /^[\+\-\!\~\*\/\%\&\|\^\<\>\[\]\=\,\)]$/ ||
                    ($once && $token eq '(') || $token eq 'new' || $token eq 'delete')
            {
            $baseName .= $token; $name .= $token;
            $token = $tokens->[++$index];
            $once = 0;
            };
        }
    else
        {
        $what = 'function';

        $name =~ /([a-z0-9_]+)$/i;              # remove leading '~' and class specification
        $baseName = $1;

        if (! defined $returnType)
            {
            # If there's no return type, make sure it's a constructor or destructor by
            # matching agains the current class.

            my @identifiers = NaturalDocs::SymbolString->IdentifiersOf($scope);

            if ($baseName ne $identifiers[-1])
                {
print "cpp: not returnType ($language/$linkage) @modifiers $baseName <@attributes> {@parts}) " .
            " ==> '" . $tokens->[$index] . "', " . ($scope ? $scope : "::") . ")\n"
    if ($cppdebug >= 3);

                return undef;
                };
            }
        else
            {
            # Merge Scope and name (e.g. Class::Class)

            if (scalar @parts > 2 && ($parts[-1] eq $baseName))
                {
                $name = $returnType . ' ' . $name;
                @parts = split(/::/, $name);
                $returnType = undef;
                };
            };

        if (! defined $returnType)
            {  $what = ($name =~ /\~[a-z0-9_]+$/i ? 'destructor' : 'constructor');  };
        };

    # Operator, Functions, Constructors and Destructors
    $self->SkipWhitespace(\$index, \$lineNum);

    if ($tokens->[$index++] ne '(')
        {  return undef;  };                    # missing parameters

    # Parameters
    my $params = $self->GetParameters(\$index, \$lineNum);

    # Attributes
    if ($language eq 'C++')
        {
        $self->SkipWhitespace(\$index, \$lineNum);

        while ($tokens->[$index] =~ /^[a-z_]/i &&
                    exists $functionAttributes{$tokens->[$index]})
            {
            push @attributes, $tokens->[$index++];

            $self->SkipWhitespace(\$index, \$lineNum);

            if ($tokens->[$index] eq '(')       # e.g. throw () and __attribute__ ()
                {
                $index++;
                $self->SkipTerminator(\$index, \$lineNum, ')');
                $self->SkipWhitespace(\$index, \$lineNum);
                };
            };

        if ($tokens->[$index] eq '=')
            {
            $index++;
            $self->SkipWhitespace(\$index, \$lineNum);

            if ($tokens->[$index] eq '0')
                {                               # pure virtual
                push @attributes, 'pure virtual';
                $index++;
                }
        #   else
        #       {  return undef;  }
            };
        };

    # We succeeded if we got this far.
    my $rescoped = $scope;

    if (scalar @parts > 1)
        {                                       # rescope
        $name = pop @parts;
        $rescoped = NaturalDocs::SymbolString->Join($rescoped, @parts);
        };

    my $prototype = $self->GetPrototype($$indexRef, $index);

    if ($rescoped ne $scope)
        {                                       # remove qualifier from name
print "cpp: rescoped $rescoped ne $scope\n"
    if ($cppdebug);

        for (my $start = 0; $start < scalar @parts; $start++)
            {
            my $qualifier;

            for (my $part = $start; $part < scalar @parts; $part++)
                {  $qualifier .= $parts[$part] . '::';  };

            if ($prototype =~ s/\Q$qualifier$name\E/$name/)
                {  last;  };
            };
        };

    if (!$linkage && $language eq 'C++')
        {
        my $scopeRecord = $self->Scope();

        if ($scopeRecord->Linkage() eq 'C')
            {  $prototype = "extern \"C\" $prototype";  };
        };

print "cpp: $what ($language/$linkage) @modifiers $returnType $name [@attributes]".
                " ->" . ($rescoped ? $rescoped : "global"). "\n".
      "     ==> $prototype\n"
    if ($cppdebug >= 1);

    # We succeeded if we got this far.
    if ($cppdebug >= 1 && ref $params)
        {
        foreach my $param (@$params)
            {
            my $t_defn = $param->{DEFN};
            my $t_ident = $param->{IDENT};
            my $t_prototype = $self->GetPrototype(0, 0, $t_defn);

print "     $t_ident ($t_defn)\n".
      "         ==> $t_prototype\n"
    if ($cppdebug);
            };
        };

    my $autoTopic = NaturalDocs::Parser::ParsedTopic->New(::TOPIC_FUNCTION(), $name,
                            $rescoped, undef, $prototype, undef, undef, $$lineNumRef);

    $self->AddAutoTopic($autoTopic);

    $self->SkipRestOfStatement(\$index, \$lineNum);

    $$indexRef = $index;
    $$lineNumRef = $lineNum;

    return 1;
    };


#
#   Function:       TryEnumeration
#       Determines if the position is on an enum declaration statement, and if so,
#       generates a topic for it.
#
sub TryEnumeration #(indexRef, lineNumRef)
{
    my ($self, $indexRef, $lineNumRef) = @_;
    my $tokens = $self->Tokens();

    my $index = $$indexRef;
    my $lineNum = $$lineNumRef;

    # Definition
    #   enum [tag] [: type]
    #       { enum-list }
    #   [declarator];                           // for definition of enumerated type
    #
    my @modifiers;

    while ($tokens->[$index] =~ /^[a-z_]/i &&
                exists $variableStorageClass{$tokens->[$index]} )
        {
        push @modifiers, $tokens->[$index++];

        $self->SkipWhitespace(\$index, \$lineNum);
        };

    if ($tokens->[$index++] ne 'enum')
        {  return undef;  }

    $self->SkipWhitespace(\$index, \$lineNum);

    my $tag = $self->GetIdentifier(\$index, \$lineNum);

    if (! defined $tag)                         # unnamed enum
        {  $tag = 'unnamed';  };

    $self->SkipWhitespace(\$index, \$lineNum);

    my $type;                                   # import but ignore

    if ($tokens->[$index] eq ':')
        {
        $type = $self->TryType(\$index, \$lineNum);
        if ($type)
            {  $self->SkipWhitespace(\$index, \$lineNum);  };
        };

    if ($tokens->[$index++] ne '{')
        {
print "cpp: enum not '{'\n"
    if ($cppdebug >= 3);
        return undef;
        };

    my $endTypeIndex = $index;

    # Values
    my @terminators = (',', '}');
    my $inlineComments = 0;
    my @elements;

    for (;;)
        {
        $self->SkipWhitespace(\$index, \$lineNum);

        if ($tokens->[$index] eq '}')
            {  last;  }                         # done, trailing comma

        my $name;
        my $desc;

        while ($tokens->[$index] =~ /^[a-z_]/i)
            {  $name .= $tokens->[$index++];  };

        if (!$name)
            {
print "cpp: enum missing name ($tokens->[$index])\n"
    if ($cppdebug >= 3);
            return undef;
            };

        my $terminator =
                $self->SkipTerminator(\$index, \$lineNum, \@terminators, \$desc);

        if ($terminator eq ',')
            {   $self->SkipWhitespace(\$index, \$lineNum, \$desc);  }
        elsif ($terminator ne '}')
            {
print "cpp: enum missing terminator\n"
    if ($cppdebug >= 3);
            return;
            };

        $inlineComments++
            if (defined $desc);

        push @elements, {
                NAME    => $name,
                DESC    => $desc
                };

print "cpp: enum ($name=$desc)\n"
    if ($cppdebug >= 2);

        if ($terminator eq '}')
            {  last;  };
        };

    # We succeeded if we got this far.
    my $prototype = $self->GetPrototype($$indexRef, $endTypeIndex);

    my $autoTopic = NaturalDocs::Parser::ParsedTopic->New(::TOPIC_ENUMERATION(), $tag,
                        $self->CurrentScope(), $self->CurrentUsing(), $prototype, undef, undef, $$lineNumRef);

print "cpp: enum $tag ".$autoTopic->Type()."\n\t=$prototype\n"
    if ($cppdebug >= 1);

    if (scalar @elements)
        {
        $autoTopic->SetElements(\@elements);
        }
##      if ($inlineComments);                   # elements plus one or more comments

    $self->AddAutoTopic($autoTopic);

    # Declarators
    if (!$self->TryVariable(\$index, \$lineNum, "enum $tag"))
        {  $self->SkipRestOfStatement(\$index, \$lineNum);  };

    $$indexRef = $index;
    $$lineNumRef = $lineNum;

    return 1;
}


#
#   Function:       TryVariable
#       Determines if the position is on a variable declaration statement,
#       and if so, generates a topic for each variable, skips the statement,
#       and returns true.
#
#   Supported Syntaxes:
#
#       - Variables
#       - Constants
#
sub TryVariable #(indexRef, lineNumRef, defnPrefix)
    {
    my ($self, $indexRef, $lineNumRef, $defnPrefix) = @_;
    my $tokens = $self->Tokens();

    my $index = $$indexRef;
    my $lineNum = $$lineNumRef;

    my $type = ::TOPIC_VARIABLE();

    # Definitions
    if (! defined $defnPrefix)
        {
        my @modifiers;

        while ($tokens->[$index] =~ /^[a-z_]/i &&
                    exists $variableStorageClass{$tokens->[$index]} )
            {
            my $modifier = $tokens->[$index];

            $type = ::TOPIC_CONSTANT()          # XXX - unsure
                if ($modifier eq 'const');

            push @modifiers, $modifier;
            $index++;

            $self->SkipWhitespace(\$index, \$lineNum);
            };

        if (!$self->TryType(\$index, \$lineNum))
            {  return undef;  };

        $defnPrefix = $self->CreateString($$indexRef, $index);
        };

    # Declarations
    my $decls = $self->GetDeclarations(\$index, \$lineNum, $defnPrefix);

    if (! defined $decls)
        {  return undef;  };

    # We succeeded if we got this far.
    foreach my $variable (@$decls)
        {
        my $defn = $variable->{DEFN};
        my $ident = $variable->{IDENT};
        my $prototype = $self->GetPrototype(0, 0, $defn);

print "cpp: $type $ident ($defn)\n".
      "     ==> $prototype\n"
    if ($cppdebug >= 1);

        $self->AddAutoTopic(NaturalDocs::Parser::ParsedTopic->New($type, $ident,
                $self->CurrentScope(), undef, $prototype, undef, $variable->{DESC}, $$lineNumRef));
        };

    $$indexRef = $index;
    $$lineNumRef = $lineNum;

    return 1;
    };


#
#   Function:       TryType
#       Determines if the position is on a type identifier, and if so,
#       consumes it and returns it as a string.
#
#       This function does _not_ allow modifiers nor templates, these are assumed
#       to have been handled prior.
#
sub TryType #(indexRef, lineNumRef)
    {
    my ($self, $indexRef, $lineNumRef) = @_;
    my $tokens = $self->Tokens();

    my $defn = undef;
    my $index = $$indexRef;
    my $lineNum = $$lineNumRef;

    # Type
    if ($tokens->[$index] =~ /^[a-z_]/i)
        {
        my $token = $tokens->[$index];

        # Builtin types
        #
        if (exists $typeBuiltins{$token})
            {
            my $type = $typeBuiltins{$token};

            $defn .= $token;
            $index++;

            while ($type == 2)
                {                               # there maybe more!
                $self->SkipWhitespace(\$index, \$lineNum);
                $token = $tokens->[$index];

                if ($typeBuiltins{$tokens->[$token]})
                    {                           # e.g. 'unsigned long int'
                    $type = $typeBuiltins{$token};
                    $defn .= ' ' . $token;
                    $index++;
                    }
                else
                    {  $type = 0;  };
                };
            }

        # Others,
        #   the following is little hit and miss but works for most cases :)
        #
        elsif (exists $typeKeywords{$token} || ! exists $reservedWords{$token})
            {
            $defn .= $token;
            $index++;

            $defn = $self->GetIdentifier(\$index, \$lineNum, $defn);
            }
        }

    # Template arguments
    if (defined $defn)
        {  $defn = $self->GetTemplate(\$index, \$lineNum, $defn);  };

    # Modifiers/storage-class
    while (exists $variableStorageClass{$tokens->[$index]} ||
                exists $typeModifiers{$tokens->[$index]})
        {
        $defn .= ' ' . $tokens->[$index++];
        $self->SkipWhitespace(\$index, \$lineNum);
        };

    if (! defined $defn)
        {  return undef;  };

print "cpp: type '$defn' ($tokens->[$index])\n"
    if ($cppdebug >= 2);

    $$indexRef = $index;
    $$lineNumRef = $lineNum;

    return $defn;
    };


###############################################################################
#   Group:          Basic Language Constructs
#

#
#   Function:       GetParameters
#       Determines if the position is at the start of parameter list,
#       and if so, consume it and returns as an array as declarations.
#
sub GetParameters #(indexRef, lineNumRef)
    {
    my ($self, $indexRef, $lineNumRef) = @_;
    my $tokens = $self->Tokens();

    my $index = $$indexRef;
    my $lineNum = $$lineNumRef;

print "cpp: GetParameters\n"
    if ($cppdebug >= 2);

    my @decls;

    # Definitions
    while ($index < scalar @$tokens)
        {
        $self->SkipWhitespace(\$index, \$lineNum);

        if ($tokens->[$index] eq ')')
            {
            $index++;
            last;
            };

        # Type
        my $start = $index;
        my @modifiers;

        while ($tokens->[$index] =~ /^[a-z_]/i &&
                    exists $variableStorageClass{$tokens->[$index]} )
            {
            my $modifier = $tokens->[$index];

            push @modifiers, $modifier;
            $index++;

            $self->SkipWhitespace(\$index, \$lineNum);
            };

        if (! $self->TryType(\$index, \$lineNum))
            {
print "     => not type ($tokens->[$index])\n"
    if ($cppdebug >= 3);
            return undef;
            };

        my $defnPrefix = $self->CreateString($start, $index);

        # Declarations
        my $t_decls = $self->GetDeclarations(\$index, \$lineNum, $defnPrefix, ',');

        if (! defined $t_decls)
            {
print "     => not decls ($tokens->[$index])\n"
     if ($cppdebug >= 3);
            return undef;
            };

        foreach (@$t_decls)
            {
            my $defn = $_->{DEFN};
            my $ident = $_->{IDENT};

print "     => param $ident ($defn)\n"
    if ($cppdebug >= 2);
            };

        push @decls, @$t_decls;
        };

    $$indexRef = $index;
    $$lineNumRef = $lineNum;

    return \@decls;
    };


#
#   Function:       GetDeclarations
#       Determines if the position is at the start of declaration list,
#       and if so, consume it and returns as an array as declarations.
#
sub GetDeclarations #(indexRef, lineNumRef, defnPrefix, terminator)
    {
    my ($self, $indexRef, $lineNumRef, $defnPrefix, $terminator) = @_;
    my $tokens = $self->Tokens();

    my $index = $$indexRef;
    my $lineNum = $$lineNumRef;

    my @decls;

print "cpp: GetDeclarations (terminator=$terminator)\n"
    if ($cppdebug >= 3);

    while ($index < scalar @$tokens)
        {
        my $defn;
        my $ident;
        my $level = 0;
        my $desc;

        do {
            $self->SkipWhitespace(\$index, \$lineNum);

            if ($tokens->[$index] eq '(')
                {
                $defn .= $tokens->[$index++];
                $level++;
                }
            elsif ($tokens->[$index] eq ')')
                {
                if ($level--)                   # possible unnamed parameter
                    {  $defn .= $tokens->[$index++];  };
                }
            elsif ($tokens->[$index] eq ';' ||
                        (0 == $level && $tokens->[$index] eq $terminator))
                {
                $level = -1;
                }
            else
                {
                while (exists $variableStorageClass{$tokens->[$index]} ||
                            exists $typeModifiers{$tokens->[$index]})
                    {
                    $defn .= $tokens->[$index++];
                    $self->SkipWhitespace(\$index, \$lineNum);
                    };

                $ident = $self->GetIdentifier(\$index, \$lineNum);
                if (! defined $ident)
                    {  last;  }                 # last identifier

                $defn .= ' ' if ($defn);
                $defn .= $ident;
                };
            }
        while ($level > 0 && $index < scalar @$tokens);

        $self->SkipWhitespace(\$index, \$lineNum, \$desc);

        # Dimensions or function parameters
        if ($tokens->[$index] eq '[')
            {
            $index++;
            $self->SkipTerminator(\$index, \$lineNum, ']');
            $self->SkipWhitespace(\$index, \$lineNum);
            }
        elsif ($tokens->[$index] eq '(')
            {
            $index++;
            $self->SkipTerminator(\$index, \$lineNum, ')');
            $self->SkipWhitespace(\$index, \$lineNum);
            };

        $self->GetAttribute(\$index, \$lineNum);

        # Assignment
        if ($tokens->[$index] eq '=')
            {
            do {
                    $self->SkipGeneric(\$index, \$lineNum);
                } while ($index < scalar @$tokens &&
                            $tokens->[$index] ne ',' && $tokens->[$index] ne ';');
            };

        # Either completion or continuation
        if ($tokens->[$index] eq ';' || $tokens->[$index] eq ')' ||
                    $tokens->[$index] eq $terminator)
            {
            if ($tokens->[$index] ne ')')       # possible unnamed parameter
                {
                $index++;
                $self->SkipWhitespace(\$index, \$lineNum, \$desc);
                };

printf "cpp: decl $defnPrefix $defn ($desc) => $ident\n"
    if ($cppdebug >= 3);

            push @decls, {
                    DEFN    => "$defnPrefix $defn",
                    IDENT   => $ident,
                    DESC    => $desc
                    };

            $$indexRef = $index;
            $$lineNumRef = $lineNum;

            return \@decls;
            }

        elsif ($tokens->[$index] eq ',')
            {
            $index++;
            $self->SkipWhitespace(\$index, \$lineNum, \$desc);

printf "cpp: decl $defnPrefix$defn $ident ($desc)\n"
    if ($cppdebug >= 3);

            push @decls, {
                    DEFN    => "$defnPrefix $defn",
                    IDENT   => $ident,
                    DESC    => $desc
                    };
            }

        else
            {
printf "cpp: !decl $defn (" . $tokens->[$index] . ")\n"
    if ($cppdebug >= 3);
            return undef;
            };
        };
    #NOTREACHED

printf "cpp: !decl end of tokens\n"
    if ($cppdebug >= 3);

    return undef;
    };


#
#   Function:       GetLinkage
#       Determines if the position is at the start of linkage definition,
#       and if so, consume it and returns as a string.
#
sub GetLinkage #(indexRef, lineNumRef)
    {
    my ($self, $indexRef, $lineNumRef) = @_;
    my $tokens = $self->Tokens();

    # Linkage ?
    if ($tokens->[$$indexRef] ne 'extern')
        {  return undef;  };

    my $index = $$indexRef + 1;                 # skip extern
    my $lineNum = $$lineNumRef;

    $self->SkipWhitespace(\$index, \$lineNum);

    # Get linkage specification
    if ($tokens->[$index++] ne '"')
        {  return undef;  };

    my $linkage = '';

    while ($index < scalar @$tokens && $tokens->[$index] ne '"')
        {
        if ($tokens->[$index] eq "\n")          # runaway
            {  return undef;  };

        $linkage .= $tokens->[$index++];
        };

    $index++;   #closing quote

    # Skip linkage
    if ($linkage ne '')
        {
        $self->SkipWhitespace(\$index, \$lineNum);

        $$indexRef = $index;
        $$lineNumRef = $lineNum;
        };

printf "cpp: linkage $linkage\n"
    if ($cppdebug >= 3);

    return $linkage;
    };


#
#   Function:       GetIdentifier
#       Determines if the position is at the start of scoped identifier,
#       and if so, consumes it and returns it as a string.
#
#       An identifier is a sequence of characters used to denote one of the following:
#
#           * Object or variable name
#           * Class, structure, or union name
#           * Enumerated type name
#           * Member of a class, structure, union, or enumeration
#           * Function or class-member function
#           * typedef name
#           * Label name
#           * Macro name
#           * Macro parameter
#
#(start example)
#  |-+-::--+-identifier-----------+------------------------------------------------+-|
#     |    +-operator_function_id-+                                                |
#     |    '-template_id----------'                                                |
#     |        .---------------------------.                                       |
#     |        V                           |                                       |
#     '-+----+---+-----------------------+-+--scope-::-+----------+-unqualified_id-'
#       '-::-'   '-scope-::-+----------+-'             '-template-'
#                           '-template-'
#
#  scope
#
#  >>-+-| class     |---+-----------------------------------------------------------><
#     '-| namespace |---'
#
#  identifier:
#                   .------------.
#                   V            |
#  >>-+-letter-+----+-letter-+-+----------------------------------------------------><
#     '-_------'    +-digit--+
#                  '-_------'
#(end example)
#
sub GetIdentifier #(indexRef, lineNumRef, defn)
    {
    my ($self, $indexRef, $lineNumRef, $defn) = @_;
    my $tokens = $self->Tokens();

    my $index = $$indexRef;
    my $lineNum = $$lineNumRef;

    $self->SkipWhitespace(\$index, \$lineNum);

    my $token = $tokens->[$index];

    if (! defined $defn)
        {
        if ($token eq '~')
            {
            $index++;
            $defn .= '~';

            $self->SkipWhitespace(\$index, \$lineNum);
            $token = $tokens->[$index];
            };

        if ($token =~ /^[a-z_\~]/i &&
                ! exists $reservedWords{$token})
            {
            $defn .= $token;
            $index++;

            $self->SkipWhitespace(\$index, \$lineNum);
            $token = $tokens->[$index];
            };
        };

    while ($token eq ':' && $tokens->[$index+1] eq ':')
        {
        $index += 2;
        $defn .= '::';

        $self->SkipWhitespace(\$index, \$lineNum);
        $token = $tokens->[$index];

        if ($token eq '~')
            {
            $index++;
            $defn .= '~';

            $self->SkipWhitespace(\$index, \$lineNum);
            $token = $tokens->[$index];
            };

        if ($token !~ /^[a-z_]/i ||
                exists $reservedWords{$token})
            {  last;  };

        $index++;
        $defn .= $token;

        $self->SkipWhitespace(\$index, \$lineNum);
        $token = $tokens->[$index];
        };

    $$indexRef = $index;
    $$lineNumRef = $lineNum;

#print "cpp: ident '$defn'\n"
#       if ($defn);

    return $defn;
    };


#
#   Function:       GetTemplate
#       Determines if the position is at the start of template definition,
#       and if so, consumes it and returns it as a string.
#
sub GetTemplate #(indexRef, lineNumRef, defn)
    {
    my ($self, $indexRef, $lineNumRef, $defn) = @_;

    my $tokens = $self->Tokens();

    my $index = $$indexRef;
    my $lineNum = $$lineNumRef;

    # If defn undef when process as a template definition,
    # otherwise as template arguments
    if (! defined $defn)
        {
        $self->SkipWhitespace(\$index, \$lineNum);

        if ($tokens->[$index] eq 'export')
            {                                   # supported by very few, ignore
            $index++;
            $self->SkipWhitespace(\$index, \$lineNum);
            };

        if ($tokens->[$index++] ne 'template')
            {  return undef;  };
        };

    $self->SkipWhitespace(\$index, \$lineNum);

    if ($tokens->[$index++] ne '<')
        {  return $defn;  };

    # Retrieve arguments
    $defn = 'template '                         # opening
        if (! defined $defn);
    $defn .= '<';

    my $nesting = 1;

    while ($nesting > 0 && $index < scalar @$tokens)
        {
        my $string;

        if ($self->SkipWhitespace(\$index, \$lineNum))
            {  $defn .= ' ';  }

        elsif ($self->SkipString(\$index, \$lineNum, \$string, 1))
            {  $defn .= $string;  }

        else
            {
            my $token = $tokens->[$index];

            if ($token eq '<')
                {  $nesting++;  }

            elsif ($token eq '>')
                {  $nesting--;  }

            elsif ($token eq ';')
                {  last;  };                    # runaway

            $defn .= $token;
            $index++;
            };
        };

    $self->SkipWhitespace(\$index, \$lineNum);

    $$indexRef = $index;
    $$lineNumRef = $lineNum;

#print "cpp: template '$defn'\n"
#       if ($defn);

    return $defn;
    };


#
#   Function:       GetAttribute
#       Determines if the position is on a attribute, and if so,
#       consumes it.
#
#   Example:
#       /* send printf-like message to stderr and exit */
#       extern void die(const char *format, ...)
#               __attribute__((noreturn))
#               __attribute__((format(printf, 1, 2)));
#
sub GetAttribute
    {
    my ($self, $indexRef, $lineNumRef) = @_;
    my $tokens = $self->Tokens();

    my $index = $$indexRef;
    my $lineNum = $$lineNumRef;

    $self->SkipWhitespace(\$index, \$lineNum);

    while ($tokens->[$index] eq '__attribute__' || $tokens->[$index] eq '__declspec')
        {
        #
        # Allow:
        #   __attribute__ (xxx)     gcc
        #   __declspec (xxx)        MSVC
        #
        $index++;
        $self->SkipWhitespace(\$index, \$lineNum);

        if ($tokens->[$index] eq '(')
            {
            $index++;
            if (!$self->SkipTerminator(\$index, \$lineNum, ')'))
                {   return undef;  }
            $self->SkipWhitespace(\$index, \$lineNum);
            };
        };

    $$indexRef = $index;
    $$lineNumRef = $lineNum;
    };


#
#   Function:       GetPrototype
#       Retrieve full prototype, removing comments and normalising the output
#       starting at token 'start' and completed at token 'end'.
#
sub GetPrototype
    {
    my ($self, $start, $end, $prototype) = @_;

    # Retrieve
    if ($start < $end)
        {
        my $tokens = $self->Tokens();
        my $lineNum = 0;

        while ($start < $end)
            {
            my $string;

            if ($self->SkipWhitespace(\$start, \$lineNum))
                {  $prototype .= ' ';  }

            elsif ($self->SkipString(\$start, \$lineNum, \$string, 1))
                {  $prototype .= $string;  }

            elsif (! $self->SkipComment(\$start, \$lineNum))
                {  $prototype .= $tokens->[$start++];  };
            };
        };

    # Cleanup and return
    $prototype = $self->NormalizePrototype($prototype);

    $prototype =~ s/\s+/ /g;                    # compress
    $prototype =~ s/\s*::\s*/::/g;              # remove whitespace around "::"
    $prototype =~ s/\s*([\<\(])\s*/$1/g;        # leading whitespace
    $prototype =~ s/\s*([\>\)\&\*\,])\s*/$1 /g; # trailing whitespace

    return $prototype;
    };


###############################################################################
#   Group:          Low Level Parsing Functions

#
#   Function:       SkipGeneric
#       Advances the position one place through general code.
#
#       - If the position is on a string, it will skip it completely.
#
#       - If the position is on an opening symbol, it will skip until the past the
#         closing symbol.
#
#       - If the position is on whitespace(including comments and preprocessing
#         directives), it will skip it completely.
#
#       - Otherwise it skips one token.
#
#   Parameters:
#       indexRef -          A reference to the current index.
#       lineNumRef -        A reference to the current line number.
#
sub SkipGeneric #(indexRef, lineNumRef, commentRef)
    {
    my ($self, $indexRef, $lineNumRef, $commentRef) = @_;
    my $tokens = $self->Tokens();

    # We can ignore the scope stack because we're just skipping everything without parsing, and we need recursion anyway.
    if ($tokens->[$$indexRef] eq '{')
        {
        $$indexRef++;
        $self->SkipTerminator($indexRef, $lineNumRef, '}');
        }
    elsif ($tokens->[$$indexRef] eq '(')
        {
        $$indexRef++;
        $self->SkipTerminator($indexRef, $lineNumRef, ')');
        }
    elsif ($tokens->[$$indexRef] eq '[')
        {
        $$indexRef++;
        $self->SkipTerminator($indexRef, $lineNumRef, ']');
        }
    elsif ($self->SkipWhitespace($indexRef, $lineNumRef, $commentRef) ||
                $self->SkipString($indexRef, $lineNumRef))
        {  }
    else
        {  $$indexRef++;  };
    };


#
#   Function:       SkipTerminator
#       Advances the position via <SkipGeneric()> until one of specified terminator(s)
#       is reached and passed.
#
sub SkipTerminator #(indexRef, lineNumRef, token, commentRef)
    {
    my ($self, $indexRef, $lineNumRef, $token, $commentRef) = @_;
    my $tokens = $self->Tokens();
    my $index;

    if (ref $token)
        {
        while (($index = $$indexRef) < scalar @$tokens)
            {
            foreach (@$token)
                {
                if ($tokens->[$index] eq $_)
                    {  goto LAST;  };
                };
            $self->SkipGeneric($indexRef, $lineNumRef, $commentRef);
            };
LAST:;      # done
        }
    else
        {
        while (($index = $$indexRef) < scalar @$tokens)
            {
            if ($tokens->[$index] eq $token)
                {  last;  };
            $self->SkipGeneric($indexRef, $lineNumRef, $commentRef);
            };
        };

    my $token = $tokens->[$index];

    if (defined $token)
        {
        if ($token eq "\n")
            {  $$lineNumRef++;  };
        $$indexRef++;                           # consume
        };
    return $token;
    };


#
#   Function:       SkipRestOfStatement
#       Advances the position via <SkipGeneric()> until after the end of the
#       current statement, which is defined as a semicolon or a brace group.
#       Of course, either of those appearing inside parenthesis, a nested
#       brace group, etc. don't count.
#
sub SkipRestOfStatement #(indexRef, lineNumRef)
    {
    my ($self, $indexRef, $lineNumRef) = @_;
    my $tokens = $self->Tokens();
    my $index;

    while (($index = $$indexRef) < scalar @$tokens)
        {
        if ($tokens->[$index] eq ';')
            {
            $$indexRef++;
            last;
            }
        elsif ($tokens->[$index] eq '{')
            {
            $self->SkipGeneric($indexRef, $lineNumRef);
            last;
            };
        $self->SkipGeneric($indexRef, $lineNumRef);
        };
    };


#
#   Function:       SkipString
#       If the current position is on a string delimiter, skip past the string and return true.
#
#   Parameters:
#       indexRef -          A reference to the index of the position to start at.
#       lineNumRef -        A reference to the line number of the position.
#       stringRef -         A (optional) reference to the returned string
#
#   Returns:
#       Whether the position was at a string.
#
#   Syntax Support:
#       - Supports quotes and apostrophes.
#
sub SkipString #(indexRef, lineNumRef, stringRef, quoted)
    {
    my ($self, $indexRef, $lineNumRef, $stringRef, $quoted) = @_;

    my $start = $$indexRef;
    my $tokens = $self->Tokens();

    if ($self->SUPER::TryToSkipString($indexRef, $lineNumRef, '\'') ||
            $self->SUPER::TryToSkipString($indexRef, $lineNumRef, '"'))
        {
        if (ref $stringRef)                     # return the string
            {
            if ($quoted)                        # plus quotes
                {  $$stringRef = $self->CreateString($start, $$indexRef);  }
            else
                {  $$stringRef = $self->CreateString($start+1, $$indexRef-1);  }
            };
        return 1;
        };
    return undef;
    };


#
#   Function:       SkipWhitespace
#       If the current position is on a whitespace token, a line break token,
#       a comment, or a preprocessing directive, it skips them and returns
#       true. If there are a number of these in a row, it skips them all.
#
sub SkipWhitespace #(indexRef, lineNumRef, commentRef)
    {
    my ($self, $indexRef, $lineNumRef, $commentRef) = @_;
    my $tokens = $self->Tokens();
    my $index;
    my $result;

    while (($index = $$indexRef) < scalar @$tokens)
        {
        if ($tokens->[$index] =~ /^[ \t]/)
            {
            $$indexRef++;
            $result = 1;
            }
        elsif ($tokens->[$index] eq "\n")
            {
            $$indexRef++;
            $$lineNumRef++;
            $result = 1;
            }
        else
            {
            my $start = $$indexRef;

            if ($self->SkipPreprocessingDirective($indexRef, $lineNumRef))
                {
                $result = 1;
                }
            elsif ($self->SkipComment($indexRef, $lineNumRef))
                {
                # Embedded comment, examples
                #
                #   //*<    /**< ... */
                #   //!<    /*!< ... */
                #   ///<    /*/< ... */
                #
                if (ref $commentRef)
                    {
                    if ($tokens->[$start+3] eq '<' && ($tokens->[$start+2] =~ /^[\*\!\/]/))
                        {
                        my $end = $$indexRef - 1;

                        $end -= 2
                            if ($tokens->[$end] ne "\n");

                        my $comment = $self->CreateString($start+4, $end);
                        $comment =~ s/\s+/ /g;
                        $comment =~ s/^\s+//;
                        $comment =~ s/\s+$//;

                        $$commentRef .= $comment;

print "cpp: embedded '$comment'\n"
    if ($cppdebug >= 2);
                        };
                    };
                $result = 1;
                }
            else
                {  last;  };
            };
        };
    return $result;
    };


#
#   Function:       SkipComment
#       If the current position is on a comment, skip past it and return true.
#
sub SkipComment #(indexRef, lineNumRef)
    {
    my ($self, $indexRef, $lineNumRef) = @_;

    return ($self->SkipLineComment($indexRef, $lineNumRef) ||
                $self->SkipMultilineComment($indexRef, $lineNumRef));
    };


#
#   Function:       SkipLineComment
#       If the current position is on a line comment symbol, skip past it and return true.
#
sub SkipLineComment #(indexRef, lineNumRef)
    {
    my ($self, $indexRef, $lineNumRef) = @_;
    my $tokens = $self->Tokens();

    if ($tokens->[$$indexRef] eq '/' && $tokens->[$$indexRef+1] eq '/')
        {
        $self->SkipRestOfLine($indexRef, $lineNumRef);
        return 1;
        };
    return undef;
    };


#
#   Function:       SkipMultilineComment
#       If the current position is on an opening comment symbol, skip past it
#       and return true.
#
sub SkipMultilineComment #(indexRef, lineNumRef)
    {
    my ($self, $indexRef, $lineNumRef) = @_;
    my $tokens = $self->Tokens();

    if ($tokens->[$$indexRef] eq '/' && $tokens->[$$indexRef+1] eq '*')
        {
        $self->SkipUntilAfter($indexRef, $lineNumRef, '*', '/');
        return 1;
        };
    return undef;
    };


#
#   Function:       SkipPreprocessingDirective
#       If the current position is on a preprocessing directive, skip past it
#       and return true.
#
sub SkipPreprocessingDirective #(indexRef, lineNumRef)
    {
    my ($self, $indexRef, $lineNumRef) = @_;
    my $tokens = $self->Tokens();

    if ($tokens->[$$indexRef] eq '#' && $self->IsFirstLineToken($$indexRef))
        {
        $self->SkipRestOfLine($indexRef, $lineNumRef);
        return 1;
        };
    return undef;
    };

1;



