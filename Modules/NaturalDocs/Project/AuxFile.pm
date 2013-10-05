###############################################################################
#
#   Class:      NaturalDocs::Project::AuxFile
#
###############################################################################
#
#   A simple information class about support files.
#
###############################################################################

# This file is part of Natural Docs, which is Copyright (C) 2003-2005 Greg Valure
# Author A.Young
# Natural Docs is licensed under the GPL

use strict;
use integer;

package NaturalDocs::Project::AuxFile;


###############################################################################
# Group: Implementation

#
#   Constants:  Members
#
#   The class is implemented as a blessed arrayref.  The following constants are 
#   used as indexes.
#
#       HAS_CONTENT         - Whether the file contains Natural Docs content or not.
#       DEFAULT_MENU_TITLE  - The file's default title in the menu.
#

# DEPENDENCY: New() depends on its parameter list being in the same order as these
#   constants.  If the order changes, New() needs to be changed.
#
use NaturalDocs::DefineMembers 'HAS_CONTENT', 'DEFAULT_MENU_TITLE', 'GROUP';


###############################################################################
# Group: Functions

#
#   Function:   New
#
#       Creates and returns a new aux file object.
#
#   Parameters:
#
#       hasContent          - Whether the file contains Natural Docs content or not.
#       defaultMenuTitle    - The file's title in the menu.
#
#   Returns:
#
#       A reference to the new object.
#
sub New #(hasContent, defaultMenuTitle)
    {
    # DEPENDENCY: This function depends on its parameter list being in the same order as
    #   the member constants.  If either order changes, this function needs to be changed.
    #
    my $package = shift;

    my $object = [ @_ ];
    bless $object, $package;

    return $object;
    };


# Function: HasContent
# Returns whether the file contains Natural Docs content or not.
sub HasContent
    {  return $_[0]->[HAS_CONTENT];  };


# Function: SetHasContent
# Sets whether the file contains Natural Docs content or not.
sub SetHasContent #(hasContent)
    {  $_[0]->[HAS_CONTENT] = $_[1];  };


# Function: DefaultMenuTitle
# Returns the file's default title on the menu.
sub DefaultMenuTitle
    {  return $_[0]->[DEFAULT_MENU_TITLE];  };


# Function: SetDefaultMenuTitle
# Sets the file's default title on the menu.
sub SetDefaultMenuTitle #(menuTitle)
    {  $_[0]->[DEFAULT_MENU_TITLE] = $_[1];  };


# Function: DefaultMenuTitle
# Returns the file's default title on the menu.
sub Group
    {  return $_[0]->[GROUP];  };


# Function: SetGroup
# Sets the file's default title on the menu.
sub SetGroup #(group)
    {  $_[0]->[GROUP] = $_[1];  };

1;
