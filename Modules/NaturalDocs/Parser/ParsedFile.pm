# -*- mode: perl; indent-width: 4; -*-
###############################################################################
#
#   Package: NaturalDocs::Parser::ParsedFile
#
###############################################################################
#
#   Parsed file container
#
###############################################################################

# This file is part of Natural Docs++, Author Adam Young
# Natural Docs is licensed under the GPL

use strict;
use integer;

package NaturalDocs::Parser::ParsedFile;

use NaturalDocs::DefineMembers
        'SOURCE',       'Source()',             'SetSource()',
        'TOPICS',       'Topics()',             'SetTopics()',
        'OBJECTS',      'Objects()',            'SetObjects()',
        'DEFMENUTITLE', 'DefaultMenuTitle()',   'SetDefaultMenuTitle()',
        'LANGUAGE',     'Language()',           'SetLanguage()',
        'HIERARCHY',    'Hierarchy()',          'SetHierarchy()',
        'PARSEDFILE',   'ParsedFile()',         'SetParsedFile()',
        'MODELINES',    'Modelines()',          'SetModelines()';


###############################################################################
#   Group:      Interface Functions
#

#
#   array: langageModes
#
#       Language to base name map.
#

my @languageModes = (
        'applescript'                           ,
        'actionscript3,as3'                     ,
        'bash,shell,sh,ksh,csh,shebangscript'   ,
        'coldfusion,cf'                         ,
        'cpp,c,c++,c/c++'                       ,
        'c#,c-sharp,csharp'                     ,
        'css'                                   ,
        'delphi,pascal'                         ,
        'diff,patch,pas'                        ,
        'erl,erlang'                            ,
        'groovy'                                ,
        'java'                                  ,
        'jfx,javafx'                            ,
        'js,jscript,javascript'                 ,
        'perl,pl,pm'                            ,
        'php'                                   ,
        'text,plain,textfile'                   ,
        'py,python'                             ,
        'ruby,rails,ror,rb'                     ,
        'sass,scs,s'                            ,
        'scala'                                 ,
        'sql'                                   ,
        'vb,vbnet,visualbasic'                  ,
        'xml,xhtml,xslt,html'
        );

#   Function:   New
#
#       Create and initialise a parsed file class.
#
#   Parameters:
#
#       source - Optional source file.
#
sub New #(source)
    {
    my $package = shift;
    my $object = [ @_ ];
    my @topics = ();

    bless $object, $package;
    return $object;
    }


#
#   Function: ParseModelines
#
#       Parse the specifies file for mode-lines.
#
#   Parameters:
#
#       linesRef - The source file lines.
#       plaintext - Plain text source flag, when *true* modelines shall be consumed.
#
#   Returns:
#
#       nothing
#                                               #ND+, modeline
sub ParseModeLines($) #(linesRef, [plaintext])
{
    my ($self, $linesRef, $plaintext) = @_;
    my %modeline;

    # Process embedded Modelines (if any)

    $self->[MODELINES] = \%modeline;            # results

    $plaintext =                                # default, not plaintext
        (defined $plaintext && $plaintext ? 1 : 0);

    # Header, first 5 lines

    my $lineCount = scalar @$linesRef;
    my $lineIndex = 0;

    for (my $limit = 5; $lineIndex < scalar @$linesRef && $lineIndex < $limit;)
        {                                       # first 5 lines
        if ($self->ParseModeLine(@$linesRef[$lineIndex], \%modeline, $plaintext))
            {
            if ($plaintext)
                {
                @$linesRef[$lineIndex] = '';    # consume
                }
            $limit++;                           # modeline encountered, extend search
            }
        $lineIndex++;
        };

    # Tail, last 25 lines

    $lineIndex = (scalar $lineCount - 25)
        if ($lineIndex < ($lineCount - 25));

    while ($lineIndex < $lineCount)
        {                                       # last 25 lines
        if ($self->ParseModeLine(@$linesRef[$lineIndex], \%modeline, $plaintext))
            {
            if ($plaintext)
                {
                @$linesRef[$lineIndex] = '';    # consume
                }
            }
        $lineIndex++;
        };

    $self->[MODELINES] = undef
        if (! scalar keys %modeline);
}


#
#   Function: Modeline
#
#       Retrieve the associated value of the specified modeline.
#
#   Parameters:
#
#       key - Modeline key.
#       defaukt - Default value upon undefined.
#
#   Returns:
#
#       Value, otherwise undef.
#                                               #ND+, modeline
sub Modeline #(key, [default])
{
    my ($self, $key, $default) = @_;
    my $modeline;

    return $default
        if (! defined ($modeline = $self->[MODELINES]));

    return $default
        if (! exists $$modeline{$key});

    return $$modeline{$key};
}


#
#   Function: ParseModeline
#
#       Parse a modeline specific
#
#   Parameters:
#
#       line - Line to be processed.
#       plaintext - Plain text source flag.
#
#   Returns:
#       *true* if the line contained a mode-line specification, otherwise *false*.
#
#                                               #ND+, modeline
sub ParseModeLine #(line, plaintext)
{
    my ($self, $line, $plaintext) = @_;

    if ($plaintext)
        {                                       # only allow trailing/leading whitespace
        if ($line =~ /^\s*\-ND\-(.+)\-ND\-\s*$/)
            {                                   # ND+ style
            $self->ParseModeLineSwitch(0, split(/\s*,\s*/, $1));
            return 1;
            }
        elsif ($line =~ /^\s*\-\*\-(.+)\-\*\-\s*$/)
            {                                   # Emacs style, ignore unknown
            $self->ParseModeLineSwitch(1, split(/\s*;\s*/, $1));
            return 1;
            }
        }
    else 
        {
        if ($line =~ /\-ND\-(.+)\-ND\-/)
            {                                   # ND+ style
            $self->ParseModeLineSwitch(0, split(/\s*,\s*/, $1));
            return 1;
            }
        elsif ($line =~ /\-\*\-(.+)\-\*\-/)
            {                                   # Emacs style, ignore unknown
            $self->ParseModeLineSwitch(1, split(/\s*;\s*/, $1));
            return 1;
            }
        }
    return 0;
}


#
#   Function: ParseModeLineSwitch
#
#       Parse a modeline switch
#
#   Parameters:
#
#       quiet - Quiet on unknown tags
#       tags - Tagged values
#
#   Returns:
#
#       nothing
#                                               #ND+, modeline
sub ParseModeLineSwitch #(quiet, tags)
    {
    my $self = shift;
    my $quiet = shift;
    my $modelineRef = $self->[MODELINES];

    foreach (@_)
        {
        s/^\s+//g;
        s/\s+$//g;

        my ($key, $value) = split /\s*[=:]\s*/, $_, 2;

        if (! defined $value)
            {
            $self->SetLanguageMode($key, $quiet);
            }
        else
            {
            $key =~ s/\s+$//g;
            $value =~ s/^\s+//g;

            if ($key eq 'nd' ||                 # yes|no - Enable/disable NaturalDoc++.
                    $key eq 'naturaldocs')
                {
                $self->ModeYesNo('nd', $value, 1);
                }
            
            elsif ($key eq 'admon' ||           # yes|no - Enable/disable admonition's
                    $key eq 'admonitions')
                {
                $self->ModeYesNo('admon', $value);
                }
            
            elsif ($key eq 'proto' ||           # yes|no - Enable/disable inlined prototypes.
                    $key eq 'prototypes')
                {
                $self->ModeYesNo('proto', $value);
                }

            
            elsif ($key eq 'numlists' ||        # yes|no - Enable/disable numeric lists.
                    $key eq 'numericlists')
                {
                $self->ModeYesNo('numlists', $value);
                }
            
            elsif ($key eq 'bullists' ||        # yes|no - Enable/disable bullet lists.
                    $key eq 'bulletlists')
                {
                $self->ModeYesNo('bullists', $value);
                }
            
            elsif ($key eq 'bulchar' ||         # <set>  - Bullet list leading characters.
                    $key eq 'bulletchar')
                {
                #TODO
                }
            
            elsif ($key eq 'deflists' ||        # yes|no - Enable/disable definition lists.
                    $key eq 'definitionlists')
                {
                $self->ModeYesNo('deflists', $value);
                }
            
            elsif ($key eq 'lvl' ||             # yes|no - Enable/disable leveling.
                    $key eq 'leveling')
                {
                $self->ModeYesNo('lvl', $value);
                }

            elsif ($key eq 'code')              # strict|yes|no - Code snippets
                {
                if ($value =~ /^strict$/i)
                    {
                    $$modelineRef{'code'} = 2;
                    }
                else 
                    {
                    $self->ModeYesNo('code', $value);
                    }
                }
            
            elsif ($key eq 'indent' ||          # <num>  - Set the indentation value.
                        $key eq 'indent-width' ||
                        $key eq 'indent-offset')
                {
                if ($value =~ /^\d+$/)
                    {
                    $$modelineRef{'indent'} = int($value);
                    }
                }
            
            elsif ($key eq 'lang' ||            # <lang> - Language mode.
                        $key eq 'language' ||
                        $key eq 'mode')
                {
                $self->SetLanguageMode($value, $quiet);
                }

            elsif ($key eq 'auto')              # yes|no - Auto publish topics.
                {
                $self->ModeYesNo('auto', $value);
                }

            else
                {
                print "WARNING - unknown modeline option '$key=$value', ignored (" . $self->Source() . ")\n"
                    if (! $quiet);
                };
            };
        };
    }


#
#   Function: SetLanguageMode
#
#       Language mode parser.
#
#   Parameters:
#
#       mode - Mode specification.
#       quiet - Quiet flag.
#
#   Returns:
#
#       nothing
#                                               #ND+, modeline
sub SetLanguageMode #(mode, [quiet])
    {
    my ($self, $mode, $quiet) = @_;

    foreach (@languageModes)
        {
        if (/(^|,)\Q${mode}\E(,|$)/i)
            {
            my $modelineRef = $self->[MODELINES];
            my ($name) = split(/[,]/);

            $$modelineRef{'lang'} = $name;
            return;
            }
        }

    print "WARNING - unknown modeline mode '$mode', ignored (" . $self->Source() . ")\n"
        if (! $quiet);
    }


#
#   Function: ModeYesNo
#
#       Mode line boolean parser.
#
#   Parameters:
#
#       key - Option key.
#       value - Associated option value.
#       default - Default value, if any.
#       quiet - Quiet flag.
#
#   Returns:
#
#       nothing
#                                               #ND+, modeline
sub ModeYesNo #(key, value, default, quiet)
    {
    my ($self, $key, $value, $default, $quiet) = @_;
    my $modelineRef = $self->[MODELINES];

    if ($value =~ /^(y|yes|true|1)$/i)          # y|yes|true|1
        {
        $$modelineRef{$key} = 1
            if ($key);
        return 1;
        }
    elsif ($value =~ /^(n|no|false|0)$/i)       # n|no|false|0
        {
        $$modelineRef{$key} = 0
            if ($key);
        return 0;
        }

    if ($key && defined $default)
        {
        if (! exists $$modelineRef{$key})
            {
            $$modelineRef{$key} = $default;
            };
        };

    print "WARNING - unsupported modeline '$key' option '$value', ignored (" . $self->Source() . ")\n"
        if (! $quiet);

    return -1;
    }

1;
