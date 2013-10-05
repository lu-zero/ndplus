###############################################################################
#
#   Class: NaturalDocs::Languages::Advanced::ScopeCpp
#
###############################################################################
#
#   A class used to store a scope level of the Cpp parser.
#
###############################################################################

# This file is part of Natural Docs, which is Copyright (C) 2003-2005 Greg Valure
# This file is part of ND+, which is Copyright (C) 2007-2013 A.Young
# Natural Docs is licensed under the GPL

use strict;
use integer;

package NaturalDocs::Languages::Advanced::ScopeCpp;

use base 'NaturalDocs::Languages::Advanced::Scope';

#
#   Constants:      Implementation
#       The object is implemented as a blessed arrayref. The constants below are used
#       as indexes.
#
#       LINKAGE -           Current linkage, either 'C' or 'C++'.
#
use NaturalDocs::DefineMembers 'LINKAGE', 'NAMESPACE', 'CLASS';


#
#   Function:       New
#       Creates and returns a new object.
#
#   Parameters:
#       closingSymbol -     The closing symbol character of the scope.
#       package -           The package <SymbolString> of the scope.
#       using -             An arrayref of using <SymbolStrings>, or undef if none. The
#                           contents of the array will be duplicated.
#
#       If package is set to undef, it is assumed that it inherits the value of the
#       previous scope on the stack.
#
sub New #(closingSymbol, package, using)
    {
    my ($package, $linkage, $namespace, @parameters) = @_;

###printf "(D) $package->NewScopeCpp($linkage, $namespace, @parameters)\n";
    
    my $object = $package->SUPER::New(@parameters);
    $object->[LINKAGE] = $linkage;
    $object->[NAMESPACE] = $namespace;

    return $object;
    };

#
#   Function:       Linkage
#       Returns the package <SymbolString> of the scope, or undef if none.
#
sub Linkage
    {  return $_[0]->[LINKAGE];  };


#
#   Function:       SetLinkage
#       Sets the package <SymbolString> of the scope.
#
sub SetLinkage #(linkage)
    {  $_[0]->[LINKAGE] = $_[1];  };


#
#   Function:       Namespace
#       Returns the current namespace
#
sub Namespace
    {  return $_[0]->[NAMESPACE];  };

#
#   Function:       SetNamespace
#       Sets the namespace
#
sub SetNamespace
    {  $_[0]->[NAMESPACE] = $_[1];  };


#
#   Function:       Class
#       Returns the current class
#
sub Class
    {  return $_[0]->[CLASS];  };


#
#   Function:       SetClass
#       Sets the class name
#
sub SetClass
    {  $_[0]->[CLASS] = $_[1];  };


#end
1;
