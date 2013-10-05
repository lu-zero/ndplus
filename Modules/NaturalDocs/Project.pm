# -*- mode: perl; indent-width: 4; -*-
###############################################################################
#
#   Package: NaturalDocs::Project
#
###############################################################################
#
#   A package that manages information about the files in the source tree, as well as the list of files that have to be parsed
#   and built.
#
#   Usage and Dependencies:
#
#       - All the <Config and Data File Functions> are available immediately, except for the status functions.
#
#       - <ReparseEverything()> and <RebuildEverything()> are available immediately, because they may need to be called
#         after <LoadConfigFileInfo()> but before <LoadSourceFileInfo()>.
#
#       - Prior to <LoadConfigFileInfo()>, <NaturalDocs::Settings> must be initialized.
#
#       - After <LoadConfigFileInfo()>, the status <Config and Data File Functions> are available as well.
#
#       - Prior to <LoadSourceFileInfo()>, <NaturalDocs::Settings> and <NaturalDocs::Languages> must be initialized.
#
#       - After <LoadSourceFileInfo()>, the rest of the <Source File Functions> are available.
#
###############################################################################

# This file is part of Natural Docs, which is Copyright (C) 2003-2008 Greg Valure
# Natural Docs is licensed under the GPL

use NaturalDocs::Project::SourceFile;
use NaturalDocs::Project::ImageFile;
use NaturalDocs::Project::AuxFile;                      #ND+, package

use strict;
use integer;

use NaturalDocs::Topics;                                #ND+, package
use NaturalDocs::Parser;
use NaturalDocs::StatusMessage;

package NaturalDocs::Project;


###############################################################################
# Group: File Handles

#
#   handle: FH_FILEINFO
#
#   The file handle for the file information file, <FileInfo.nd>.
#

#
#   handle: FH_CONFIGFILEINFO
#
#   The file handle for the config file information file, <ConfigFileInfo.nd>.
#

#
#   handle: FH_IMAGEFILE
#
#   The file handle for determining the dimensions of image files.
#



###############################################################################
# Group: Source File Variables


#
#   hash: supportedFiles
#
#       A hash of all the supported files in the input directory.  The keys are the 
#       <FileNames>, and the values are <NaturalDocs::Project::SourceFile> objects.
#
my %supportedFiles;

#ND+, package
#   hash: auxiliaryFiles
#
#       A hash of all the aux files in the output tree.  The keys are the <FileNames>, and the
#       values are <NaturalDocs::Project::AuxFile> objects.
#
my %auxiliaryFiles;

#
#   hash: filesToParse
#
#       An existence hash of all the <FileNames> that need to be parsed.
#
my %filesToParse;

#ND+, package
#   hash: filesToRebuild
#
#       An existence hash of all the <FileNames> that need to be reparsed.
#
my %filesToRebuild;

#ND+, package
#   hash: groupActive
#
#       A hash of all the files that active,
#
my %groupsActive;

#ND+, package
#   hash: groupsToPurge
#
#       An existence hash of the file groups that have been reparsed, hence any
#       auxiliary files must be also be purged.
#
my %groupsToPurge;

#
#   hash: filesToBuild
#
#       An existence hash of all the <FileNames> that have Natural Docs content
#       and need to be built.
#
my %filesToBuild;

#
#   hash: filesToPurge
#
#       An existence hash of the <FileNames> that had Natural Docs content last
#       time, but now either don't exist or no longer have content.
#
my %filesToPurge;

#
#   hash: unbuiltFilesWithContent
#
#       An existence hash of all the <FileNames> that have Natural Docs content
#       but are not part of <filesToBuild>.
#
my %unbuiltFilesWithContent;


# bool: reparseEverything
# Whether all the source files need to be reparsed.
my $reparseEverything;

# bool: rebuildEverything
# Whether all the source files need to be rebuilt.
my $rebuildEverything;

# hash: mostUsedLanguage
# The name of the most used language.  Doesn't include text files.
my $mostUsedLanguage;



###############################################################################
# Group: Configuration File Variables


#
#   hash: mainConfigFile
#
#   A hash mapping all the main configuration file names without paths to their <FileStatus>.  Prior to <LoadConfigFileInfo()>,
#   it serves as an existence hashref of the file names.
#
my %mainConfigFiles = ( 'Topics.txt' => 1, 'Languages.txt' => 1 );

#
#   hash: userConfigFiles
#
#   A hash mapping all the user configuration file names without paths to their <FileStatus>.  Prior to <LoadConfigFileInfo()>,
#   it serves as an existence hashref of the file names.
#
my %userConfigFiles = ( 'Topics.txt' => 1, 'Languages.txt' => 1, 'Menu.txt' => 1 );




###############################################################################
# Group: Image File Variables


#
#   hash: imageFileExtensions
#
#   An existence hash of all the file extensions for images.  Extensions are in all lowercase.
#
my %imageFileExtensions = ( 'jpg' => 1, 'jpeg' => 1, 'gif' => 1, 'png' => 1, 'bmp' => 1 );


#
#   hash: imageFiles
#
#   A hash of all the image files in the project.  The keys are the <FileNames> and the values are
#   <NaturalDocs::Project::ImageFiles>.
#
my %imageFiles;


#
#   hash: imageFilesToUpdate
#
#   An existence hash of all the image <FileNames> that need to be updated, either because they changed or they're new to the
#   project.
#
my %imageFilesToUpdate;


#
#   hash: imageFilesToPurge
#
#   An existence hash of all the image <FileNames> that need to be purged, either because the files no longer exist or because
#   they are no longer used.
#
my %imageFilesToPurge;


#
#   hash: insensitiveImageFiles
#
#   A hash that maps all lowercase image <FileNames> to their proper case as it would appear in <imageFiles>.  Used for
#   case insensitivity, obviously.
#
#   You can't just use all lowercase in <imageFiles> because both Linux and HTTP are case sensitive, so the original case must
#   be preserved.  We also want to allow separate entries for files that differ based only on case, so it goes to <imageFiles> first
#   where they can be distinguished and here only if there's no match.  Ties are broken by whichever is lower with cmp, because
#   it has to resolve consistently on all runs of the program.
#
my %insensitiveImageFiles;



###############################################################################
# Group: Files


#
#   File: FileInfo.nd
#
#   An index of the state of the files as of the last parse.  Used to determine if files were added, deleted, or changed.
#
#   Format:
#
#       The format is a text file.
#
#       > [VersionInt: app version]
#
#       The beginning of the file is the <VersionInt> it was generated with.
#
#       > [most used language name]
#
#       Next is the name of the most used language in the source tree.  Does not include text files.
#
#       Each following line is
#
#       > [file name] tab [last modification time] tab [has ND content (0 or 1)] tab [default menu title] \n
#
#   Revisions:
#
#       1.3:
#
#           - The line following the <VersionInt>, which was previously the last modification time of <Menu.txt>, was changed to
#             the name of the most used language.
#
#       1.16:
#
#           - File names are now absolute.  Prior to 1.16, they were relative to the input directory since only one was allowed.
#
#       1.14:
#
#           - The file was renamed from NaturalDocs.files to FileInfo.nd and moved into the Data subdirectory.
#
#       0.95:
#
#           - The file version was changed to match the program version.  Prior to 0.95, the version line was 1.  Test for "1" instead
#             of "1.0" to distinguish.
#


#
#   File: ConfigFileInfo.nd
#
#   An index of the state of the config files as of the last parse.
#
#   Format:
#
#       > [BINARY_FORMAT]
#       > [VersionInt: app version]
#
#       First is the standard <BINARY_FORMAT> <VersionInt> header.
#
#       > [UInt32: last modification time of menu]
#       > [UInt32: last modification of main topics file]
#       > [UInt32: last modification of user topics file]
#       > [UInt32: last modification of main languages file]
#       > [UInt32: last modification of user languages file]
#
#       Next are the last modification times of various configuration files as UInt32s in the standard Unix format.
#
#
#   Revisions:
#
#       1.3:
#
#           - The file was added to Natural Docs.  Previously the last modification of <Menu.txt> was stored in <FileInfo.nd>, and
#             <Topics.txt> and <Languages.txt> didn't exist.
#


#
#   File: ImageFileInfo.nd
#
#   An index of the state of the image files as of the last parse.
#
#   Format:
#
#       > [Standard Binary Header]
#
#       First is the standard binary file header as defined by <NaturalDocs::BinaryFile>.
#
#       > [AString16: file name or undef]
#       > [UInt32: last modification time]
#       > [UInt8: was used]
#
#       This section is repeated until the file name is null.  The last modification times are UInt32s in the standard Unix format.
#
#
#   Revisions:
#
#       1.4:
#
#           - The file was added to Natural Docs.
#

###############################################################################
# Group: File Functions

#
#   Function: LoadSourceFileInfo
#
#   Loads the project file from disk and compares it against the files in the input directory.  Project is loaded from
#   <FileInfo.nd>.  New and changed files will be added to <FilesToParse()>, and if they have content,
#   <FilesToBuild()>.
#
#   Will call <NaturalDocs::Languages->OnMostUsedLanguageKnown()> if <MostUsedLanguage()> changes.
#
#   Returns:
#
#       Returns whether the project was changed in any way.
#
sub LoadSourceFileInfo
    {
    my ($self) = @_;

    $self->GetAllSupportedFiles();
    NaturalDocs::Languages->OnMostUsedLanguageKnown();

    my $fileIsOkay;
    my $version;
    my $hasChanged;

    if (open(FH_FILEINFO, '<' . $self->DataFile('FileInfo.nd')))
        {
        # Check if the file is in the right format.
        $version = NaturalDocs::Version->FromTextFile(\*FH_FILEINFO);

        # The project file need to be rebuilt for 1.16.  The source files need to be reparsed and the output files rebuilt for 1.35.
        # We'll tolerate the difference between 1.16 and 1.3 in the loader.

        if (NaturalDocs::Version->CheckFileFormat( $version, NaturalDocs::Version->FromString('1.16') ))
            {
            $fileIsOkay = 1;

            if (!NaturalDocs::Version->CheckFileFormat( $version, NaturalDocs::Version->FromString('1.35') ))
                {
                $reparseEverything = 1;
                $rebuildEverything = 1;
                $hasChanged = 1;
                };
            }
        else
            {
            close(FH_FILEINFO);
            $hasChanged = 1;
            };
        };


    if ($fileIsOkay)
        {
        my %indexedFiles;

        my $line = <FH_FILEINFO>;
        ::XChomp(\$line);

        # Prior to 1.3 it was the last modification time of Menu.txt, which we ignore and treat as though the most used language
        # changed.  Prior to 1.32 the settings didn't transfer over correctly to Menu.txt so we need to behave that way again.
        if ($version < NaturalDocs::Version->FromString('1.32') || lc($mostUsedLanguage) ne lc($line))
            {
            $reparseEverything = 1;
            NaturalDocs::SymbolTable->RebuildAllIndexes();
            };

        # Parse the rest of the file.
        while ($line = <FH_FILEINFO>)
            {
            ::XChomp(\$line);                           #ND+, package
            my ($file, $modification, $hasContent, $menuTitle, $group, @packages) = split(/\t/, $line);

            # Group management                          #ND+, package
            $group = 0 if (!defined($group));
            if ($group)
                {  $groupsActive{$group} = 1;  }

            # Filter out aux files                      #ND+, package
            if ($hasContent < 0)
                {
                $self->Debug("AUX:  $file($group), " . ($hasContent == ::AUX_IMAGE() ? "img" : "frag"));

                my $aux = NaturalDocs::Project::AuxFile->New();
                $auxiliaryFiles{$file} = $aux;
                $aux->SetHasContent($hasContent);
                $aux->SetDefaultMenuTitle($menuTitle);
                $aux->SetGroup($group);
                next;
                }

            $self->Debug("FILE: $file($group), $hasContent, @packages");

            # If the file no longer exists...
            if (!exists $supportedFiles{$file})
                {
                if ($hasContent)
                    {  $filesToPurge{$file} = 1;  };

                if ($group)
                    {  $groupsToPurge{$group} = 1;  }   #ND+, package

                $hasChanged = 1;
                }

            # If the file still exists...
            else
                {
                $indexedFiles{$file} = 1;

                # If the file changed...
                if ($supportedFiles{$file}->LastModified() != $modification)
                    {
                    $supportedFiles{$file}->SetStatus(::FILE_CHANGED());
                    $filesToParse{$file} = 1;

                    # If the file loses its content, this will be removed by SetHasContent().
                    if ($hasContent)
                        {  $filesToBuild{$file} = 1;  };

                    $hasChanged = 1;
                    }

                # If the file has not changed...
                else
                    {
                    my $status;

                    if ($rebuildEverything && $hasContent)
                        {
                        $status = ::FILE_CHANGED();

                        # If the file loses its content, this will be removed by SetHasContent().
                        $filesToBuild{$file} = 1;
                        $hasChanged = 1;
                        }
                    else
                        {
                        $status = ::FILE_SAME();

                        if ($hasContent)
                            {  $unbuiltFilesWithContent{$file} = 1;  };
                        };

                    if ($reparseEverything)
                        {
                        $status = ::FILE_CHANGED();

                        $filesToParse{$file} = 1;
                        $hasChanged = 1;
                        };

                    $supportedFiles{$file}->SetStatus($status);
                    };

                $supportedFiles{$file}->SetHasContent($hasContent);
                $supportedFiles{$file}->SetDefaultMenuTitle($menuTitle);
                $supportedFiles{$file}->SetGroup($group); #ND+, package
                $supportedFiles{$file}->SetPackages(\@packages);
                };
            };

        close(FH_FILEINFO);


        # Check for added files.

        if (scalar keys %supportedFiles > scalar keys %indexedFiles)
            {
            foreach my $file (keys %supportedFiles)
                {
                if (!exists $indexedFiles{$file})
                    {
                    $supportedFiles{$file}->SetStatus(::FILE_NEW());
                    $supportedFiles{$file}->SetDefaultMenuTitle($file);
                    $supportedFiles{$file}->SetHasContent(undef);
                    $supportedFiles{$file}->SetGroup(0); #ND+, package

                    $filesToParse{$file} = 1;
                    # It will be added to filesToBuild if HasContent gets set to true when it's parsed.
                    $hasChanged = 1;
                    };
                };
            };
        }

    # If something's wrong with FileInfo.nd, everything is new.
    else
        {
        foreach my $file (keys %supportedFiles)
            {
            $supportedFiles{$file}->SetStatus(::FILE_NEW());
            $supportedFiles{$file}->SetDefaultMenuTitle($file);
            $supportedFiles{$file}->SetHasContent(undef);
            $supportedFiles{$file}->SetGroup(0);        #ND+, package

            $filesToParse{$file} = 1;
            # It will be added to filesToBuild if HasContent gets set to true when it's parsed.
            };

        $hasChanged = 1;
        };


    # There are other side effects, so we need to call this.
    if ($rebuildEverything)
        {  $self->RebuildEverything();  };


    return $hasChanged;
    };


#
#   Function: SaveSourceFileInfo
#
#   Saves the source file info to disk.  Everything is saved in <FileInfo.nd>.
#
sub SaveSourceFileInfo
    {
    my ($self) = @_;

    open(FH_FILEINFO, '>' . $self->DataFile('FileInfo.nd'))
        or die "Couldn't save project file " . $self->DataFile('FileInfo.nd') . "\n";

    NaturalDocs::Version->ToTextFile(\*FH_FILEINFO, NaturalDocs::Settings->AppVersion());

    print FH_FILEINFO $mostUsedLanguage . "\n";

    while (my ($fileName, $file) = each %supportedFiles)
        {
        my $packages = $file->Packages();

        print FH_FILEINFO $fileName . "\t"
                        . $file->LastModified() . "\t"
                        . ($file->HasContent() || '0') . "\t"
                        . $file->DefaultMenuTitle() . "\t"
                        . $file->Group() . "\t"         #ND+, package
                        . ($packages ? join("\t", @$packages) : "") . "\n";
        };

    while (my ($fileName, $file) = each %auxiliaryFiles)
        {                                               #ND+, package
        print FH_FILEINFO $fileName . "\t"
                        . "0" . "\t"
                        . $file->HasContent() . "\t"
                        . $file->DefaultMenuTitle() . "\t"
                        . $file->Group() . "\t"
                        . "" . "\n";
        };

    close(FH_FILEINFO);
    };


#
#   Function: LoadConfigFileInfo
#
#   Loads the config file info from disk.
#
sub LoadConfigFileInfo
    {
    my ($self) = @_;

    my $fileIsOkay;
    my $version;
    my $fileName = NaturalDocs::Project->DataFile('ConfigFileInfo.nd');

    if (open(FH_CONFIGFILEINFO, '<' . $fileName))
        {
        # See if it's binary.
        binmode(FH_CONFIGFILEINFO);

        my $firstChar;
        read(FH_CONFIGFILEINFO, $firstChar, 1);

        if ($firstChar == ::BINARY_FORMAT())
            {
            $version = NaturalDocs::Version->FromBinaryFile(\*FH_CONFIGFILEINFO);

            # It hasn't changed since being introduced.

            if (NaturalDocs::Version->CheckFileFormat($version))
                {  $fileIsOkay = 1;  }
            else
                {  close(FH_CONFIGFILEINFO);  };
            }

        else # it's not in binary
            {  close(FH_CONFIGFILEINFO);  };
        };

    my @configFiles = ( $self->UserConfigFile('Menu.txt'), \$userConfigFiles{'Menu.txt'},
                                 $self->MainConfigFile('Topics.txt'), \$mainConfigFiles{'Topics.txt'},
                                 $self->UserConfigFile('Topics.txt'), \$userConfigFiles{'Topics.txt'},
                                 $self->MainConfigFile('Languages.txt'), \$mainConfigFiles{'Languages.txt'},
                                 $self->UserConfigFile('Languages.txt'), \$userConfigFiles{'Languages.txt'} );

    if ($fileIsOkay)
        {
        my $raw;

        read(FH_CONFIGFILEINFO, $raw, 20);
        my @configFileDates = unpack('NNNNN', $raw);

        while (scalar @configFiles)
            {
            my $file = shift @configFiles;
            my $fileStatus = shift @configFiles;
            my $fileDate = shift @configFileDates;

            if (-e $file)
                {
                if ($fileDate == (stat($file))[9])
                    {  $$fileStatus = ::FILE_SAME();  }
                else
                    {  $$fileStatus = ::FILE_CHANGED();  };
                }
            else
                {  $$fileStatus = ::FILE_DOESNTEXIST();  };
            };

        close(FH_CONFIGFILEINFO);
        }
    else # !$fileIsOkay
        {
        while (scalar @configFiles)
            {
            my $file = shift @configFiles;
            my $fileStatus = shift @configFiles;

            if (-e $file)
                {  $$fileStatus = ::FILE_CHANGED();  }
            else
                {  $$fileStatus = ::FILE_DOESNTEXIST();  };
            };
        };

    if ($userConfigFiles{'Menu.txt'} == ::FILE_SAME() && $rebuildEverything)
        {  $userConfigFiles{'Menu.txt'} = ::FILE_CHANGED();  };
    };


#
#   Function: SaveConfigFileInfo
#
#   Saves the config file info to disk.  You *must* save all other config files first, such as <Menu.txt> and <Topics.txt>.
#
sub SaveConfigFileInfo
    {
    my ($self) = @_;

    open (FH_CONFIGFILEINFO, '>' . NaturalDocs::Project->DataFile('ConfigFileInfo.nd'))
        or die "Couldn't save " . NaturalDocs::Project->DataFile('ConfigFileInfo.nd') . ".\n";

    binmode(FH_CONFIGFILEINFO);

    print FH_CONFIGFILEINFO '' . ::BINARY_FORMAT();

    NaturalDocs::Version->ToBinaryFile(\*FH_CONFIGFILEINFO, NaturalDocs::Settings->AppVersion());

    print FH_CONFIGFILEINFO pack('NNNNN', (stat($self->UserConfigFile('Menu.txt')))[9],
                                                                (stat($self->MainConfigFile('Topics.txt')))[9],
                                                                (stat($self->UserConfigFile('Topics.txt')))[9],
                                                                (stat($self->MainConfigFile('Languages.txt')))[9],
                                                                (stat($self->UserConfigFile('Languages.txt')))[9] );

    close(FH_CONFIGFILEINFO);
    };


#
#   Function: LoadImageFileInfo
#
#   Loads the image file info from disk.
#
sub LoadImageFileInfo
    {
    my ($self) = @_;

    my $version = NaturalDocs::BinaryFile->OpenForReading( NaturalDocs::Project->DataFile('ImageFileInfo.nd') );
    my $fileIsOkay;

    if (defined $version)
        {
        # It hasn't changed since being introduced.

        if (NaturalDocs::Version->CheckFileFormat($version))
            {  $fileIsOkay = 1;  }
        else
            {  NaturalDocs::BinaryFile->Close();  };
        };

    if ($fileIsOkay)
        {
        # [AString16: file name or undef]

        while (my $imageFile = NaturalDocs::BinaryFile->GetAString16())
            {
            # [UInt32: last modified]
            # [UInt8: was used]

            my $lastModified = NaturalDocs::BinaryFile->GetUInt32();
            my $wasUsed = NaturalDocs::BinaryFile->GetUInt8();

            my $imageFileObject = $imageFiles{$imageFile};

            # If there's an image file in ImageFileInfo.nd that no longer exists...
            if (!$imageFileObject)
                {
                $imageFileObject = NaturalDocs::Project::ImageFile->New($lastModified, ::FILE_DOESNTEXIST(), $wasUsed);
                $imageFiles{$imageFile} = $imageFileObject;

                if ($wasUsed)
                    {  $imageFilesToPurge{$imageFile} = 1;  };
                }
            else
                {
                $imageFileObject->SetWasUsed($wasUsed);

                # This will be removed if it gets any references.
                if ($wasUsed)
                    {  $imageFilesToPurge{$imageFile} = 1;  };

                if ($imageFileObject->LastModified() == $lastModified && !$rebuildEverything)
                    {  $imageFileObject->SetStatus(::FILE_SAME());  }
                else
                    {  $imageFileObject->SetStatus(::FILE_CHANGED());  };
                };
            };

        NaturalDocs::BinaryFile->Close();
        }

    else # !$fileIsOkay
        {
        $self->RebuildEverything();
        };
    };


#
#   Function: SaveImageFileInfo
#
#   Saves the image file info to disk.
#
sub SaveImageFileInfo
    {
    my $self = shift;

    NaturalDocs::BinaryFile->OpenForWriting( NaturalDocs::Project->DataFile('ImageFileInfo.nd') );

    while (my ($imageFile, $imageFileInfo) = each %imageFiles)
        {
        if ($imageFileInfo->Status() != ::FILE_DOESNTEXIST())
            {
            # [AString16: file name or undef]
            # [UInt32: last modification time]
            # [UInt8: was used]

            NaturalDocs::BinaryFile->WriteAString16($imageFile);
            NaturalDocs::BinaryFile->WriteUInt32($imageFileInfo->LastModified());
            NaturalDocs::BinaryFile->WriteUInt8( ($imageFileInfo->ReferenceCount() > 0 ? 1 : 0) );
            };
        };

    NaturalDocs::BinaryFile->WriteAString16(undef);
    NaturalDocs::BinaryFile->Close();
    };


#
#   Function: MigrateOldFiles
#
#   If the project uses the old file names used prior to 1.14, it converts them to the new file names.
#
sub MigrateOldFiles
    {
    my ($self) = @_;

    my $projectDirectory = NaturalDocs::Settings->ProjectDirectory();

    # We use the menu file as a test to see if we're using the new format.
    if (-e NaturalDocs::File->JoinPaths($projectDirectory, 'NaturalDocs_Menu.txt'))
        {
        # The Data subdirectory would have been created by NaturalDocs::Settings.

        rename( NaturalDocs::File->JoinPaths($projectDirectory, 'NaturalDocs_Menu.txt'), $self->UserConfigFile('Menu.txt') );

        if (-e NaturalDocs::File->JoinPaths($projectDirectory, 'NaturalDocs.sym'))
            {  rename( NaturalDocs::File->JoinPaths($projectDirectory, 'NaturalDocs.sym'), $self->DataFile('SymbolTable.nd') );  };

        if (-e NaturalDocs::File->JoinPaths($projectDirectory, 'NaturalDocs.files'))
            {  rename( NaturalDocs::File->JoinPaths($projectDirectory, 'NaturalDocs.files'), $self->DataFile('FileInfo.nd') );  };

        if (-e NaturalDocs::File->JoinPaths($projectDirectory, 'NaturalDocs.m'))
            {  rename( NaturalDocs::File->JoinPaths($projectDirectory, 'NaturalDocs.m'), $self->DataFile('PreviousMenuState.nd') );  };
        };
    };



###############################################################################
# Group: Config and Data File Functions


#
#   Function: MainConfigFile
#
#   Returns the full path to the passed main configuration file.  Pass the file name only.
#
sub MainConfigFile #(string file)
    {
    my ($self, $file) = @_;
    return NaturalDocs::File->JoinPaths( NaturalDocs::Settings->ConfigDirectory(), $file );
    };

#
#   Function: MainConfigFileStatus
#
#   Returns the <FileStatus> of the passed main configuration file.  Pass the file name only.
#
sub MainConfigFileStatus #(string file)
    {
    my ($self, $file) = @_;
    return $mainConfigFiles{$file};
    };

#
#   Function: UserConfigFile
#
#   Returns the full path to the passed user configuration file.  Pass the file name only.
#
sub UserConfigFile #(string file)
    {
    my ($self, $file) = @_;
    return NaturalDocs::File->JoinPaths( NaturalDocs::Settings->ProjectDirectory(), $file );
    };

#
#   Function: UserConfigFileStatus
#
#   Returns the <FileStatus> of the passed user configuration file.  Pass the file name only.
#
sub UserConfigFileStatus #(string file)
    {
    my ($self, $file) = @_;
    return $userConfigFiles{$file};
    };

#
#   Function: DataFile
#
#   Returns the full path to the passed data file.  Pass the file name only.
#
sub DataFile #(string file)
    {
    my ($self, $file) = @_;
    return NaturalDocs::File->JoinPaths( NaturalDocs::Settings->ProjectDataDirectory(), $file );
    };




###############################################################################
# Group: Source File Functions


# Function: FilesToParse
# Returns an existence hashref of the <FileNames> to parse.  This is not a copy of the data, so don't change it.
sub FilesToParse
    {  return \%filesToParse;  };

# Function: FilesToBuild
# Returns an existence hashref of the <FileNames> to build.  This is not a copy of the data, so don't change it.
sub FilesToBuild
    {  return \%filesToBuild;  };

# Function: FilesToPurge
# Returns an existence hashref of the <FileNames> that had content last time, but now either don't anymore or were deleted.
# This is not a copy of the data, so don't change it.
sub FilesToPurge
    {  return \%filesToPurge;  };

#
#   Function: RebuildFile
#
#   Adds the file to the list of files to build.  This function will automatically filter out files that don't have Natural Docs content and
#   files that are part of <FilesToPurge()>.  If this gets called on a file and that file later gets Natural Docs content, it will be added.
#
#   Parameters:
#
#       file - The <FileName> to build or rebuild.
#
sub RebuildFile #(file)
    {
    my ($self, $file) = @_;

    # We don't want to add it to the build list if it doesn't exist, doesn't have Natural Docs content, or it's going to be purged.
    # If it wasn't parsed yet and will later be found to have ND content, it will be added by SetHasContent().
    if (exists $supportedFiles{$file} && !exists $filesToPurge{$file} && $supportedFiles{$file}->HasContent())
        {
        $filesToBuild{$file} = 1;

        if (exists $unbuiltFilesWithContent{$file})
            {  delete $unbuiltFilesWithContent{$file};  };
        };
    };


#
#   Function: ReparseEverything
#
#       Adds all supported files to the list of files to parse.  This does not necessarily mean
#       these diles are going to be rebuilt.
#
sub ReparseEverything
    {
    my ($self) = @_;

    if (!$reparseEverything)
        {
        $self->Debug("ReparseEverything()");

        foreach my $file (keys %supportedFiles)
            {
            $filesToParse{$file} = 1;
            };

        $reparseEverything = 1;
        };
    };


#
#   Function: RebuildEverything
#
#       Adds all supported files to the list of files to build.  This does not necessarily
#       mean these files are going to be reparsed.
#
sub RebuildEverything
    {
    my ($self) = @_;

    $self->Debug("RebuildEverything()");

    foreach my $file (keys %unbuiltFilesWithContent)
        {
        $filesToBuild{$file} = 1;
        };

    %unbuiltFilesWithContent = ( );
    $rebuildEverything = 1;

    NaturalDocs::SymbolTable->RebuildAllIndexes();

    if ($userConfigFiles{'Menu.txt'} == ::FILE_SAME())
        {  $userConfigFiles{'Menu.txt'} = ::FILE_CHANGED();  };

    while (my ($imageFile, $imageObject) = each %imageFiles)
        {
        if ($imageObject->ReferenceCount())
            {  $imageFilesToUpdate{$imageFile} = 1;  };
        };
    };


#
#   Function: UnbuiltFilesWithContent
#
#       Returns an existence hashref of the <FileNames> that have Natural Docs content
#       but are not part of <FilesToBuild()>.  This is not a copy of the data so
#       don't change it.
#
sub UnbuiltFilesWithContent
    {  return \%unbuiltFilesWithContent;  };


#
#   Function: FilesWithContent
#
#       Returns and existence hashref of the <FileNames> that have Natural Docs content.
#
sub FilesWithContent
    {
    # Don't keep this one internally, but there's an easy way to make it.
    return { %filesToBuild, %unbuiltFilesWithContent };
    };


#
#   Function: HasContent
#
#       Returns whether the <FileName> contains Natural Docs content.
#
sub HasContent #(file)
    {
    my ($self, $file) = @_;

    if (exists $supportedFiles{$file})
        {  return $supportedFiles{$file}->HasContent();  }
    else
        {  return undef;  };
    };


#
#   Function: SetHasContent
#
#       Sets whether the <FileName> has Natural Docs content or not.
#
sub SetHasContent #(file, hasContent)
    {
    my ($self, $file, $hasContent) = @_;

    $self->Debug("SetHasContent($file," . ($hasContent ? "yes" : "no"));

    if (exists $supportedFiles{$file} && $supportedFiles{$file}->HasContent() != $hasContent)
        {
        # If the file now has content...
        if ($hasContent)
            {
            $self->Debug("\trebuilding");
            $filesToBuild{$file} = 1;
            delete $filesToPurge{$file};                # may not be there
            }

        # If the file's content has been removed...
        else
            {
            $self->Debug("\tpurging");
            delete $filesToBuild{$file};                # may not be there
            $filesToPurge{$file} = 1;
            }

        $supportedFiles{$file}->SetHasContent($hasContent);
        }

    elsif (exists $auxiliaryFiles{$file})               #ND+, package
        {
        $self->Debug("\tauxiliary, building");
        if ($hasContent)
            {  $filesToBuild{$file} = 1;  }
        };
    };


#
#   Function: StatusOf
#
#       Returns the <FileStatus> of the passed <FileName>.
#
sub StatusOf #(file)
    {
    my ($self, $file) = @_;

    if (exists $supportedFiles{$file})
        {  return $supportedFiles{$file}->Status();  }
    else
        {  return ::FILE_DOESNTEXIST();  };
    };


#
#   Function: DefaultMenuTitleOf
#
#       Returns the default menu title of the <FileName>.  If one isn't specified,
#       it returns the <FileName>.
#
sub DefaultMenuTitleOf #(file)
    {
    my ($self, $file) = @_;

    if (exists $supportedFiles{$file})
        {  return $supportedFiles{$file}->DefaultMenuTitle();  }

    elsif (exists $auxiliaryFiles{$file})               #ND+, package
        {  return $auxiliaryFiles{$file}->DefaultMenuTitle();  }

    else
        {  return $file;  };
    };


#
#   Function: SetDefaultMenuTitle
#
#       Sets the <FileName's> default menu title.
#
sub SetDefaultMenuTitle #(filename, menuTitle)
    {
    my ($self, $filename, $menuTitle) = @_;
    my $file = undef;                                   #ND+, package

    if (exists $supportedFiles{$filename})
        {  $file = $supportedFiles{$filename};  }

    elsif (exists $auxiliaryFiles{$filename})
        {  $file = $auxiliaryFiles{$filename};  }

    if (defined $file && $file->DefaultMenuTitle() ne $menuTitle)
        {
        $file->SetDefaultMenuTitle($menuTitle);
        NaturalDocs::Menu->OnDefaultTitleChange($file);
        }
    };


#
#   Function: MostUsedLanguage
#
#       Returns the name of the most used language in the source trees.  Does not
#       include text files.
#
sub MostUsedLanguage
    {  return $mostUsedLanguage;  };




###############################################################################
# Group: Image File Functions


#
#   Function: ImageFileExists
#   Returns whether the passed image file exists.
#
sub ImageFileExists #(FileName file) => bool
    {
    my ($self, $file) = @_;

    if (!exists $imageFiles{$file})
        {  $file = $insensitiveImageFiles{lc($file)};  };

    return (exists $imageFiles{$file} && $imageFiles{$file}->Status() != ::FILE_DOESNTEXIST());
    };


#
#   Function: ImageFileDimensions
#   Returns the dimensions of the passed image file as the array ( width, height ).  Returns them both as undef if it cannot be
#   determined.
#
sub ImageFileDimensions #(FileName file) => (int, int)
    {
    my ($self, $file) = @_;

    if (!exists $imageFiles{$file})
        {  $file = $insensitiveImageFiles{lc($file)};  };

    my $object = $imageFiles{$file};
    if (!$object)
        {  die "Tried to get the dimensions of an image that doesn't exist.";  };

    if ($object->Width() == -1)
        {  $self->DetermineImageDimensions($file);  };

    return ($object->Width(), $object->Height());
    };


#
#   Function: ImageFileCapitalization
#   Returns the properly capitalized version of the passed image <FileName>.  Image file paths are treated as case insensitive
#   regardless of whether the underlying operating system is or not, so we have to make sure the final version matches the
#   capitalization of the actual file.
#
sub ImageFileCapitalization #(FileName file) => FileName
    {
    my ($self, $file) = @_;

    if (exists $imageFiles{$file})
        {  return $file;  }
    elsif (exists $insensitiveImageFiles{lc($file)})
        {  return $insensitiveImageFiles{lc($file)};  }
    else
        {  die "Tried to get the capitalization of an image file that doesn't exist.";  };
    };


#
#   Function: AddImageFileReference
#   Adds a reference to the passed image <FileName>.
#
sub AddImageFileReference #(FileName imageFile)
    {
    my ($self, $imageFile) = @_;

    if (!exists $imageFiles{$imageFile})
        {  $imageFile = $insensitiveImageFiles{lc($imageFile)};  };

    my $imageFileInfo = $imageFiles{$imageFile};

    if ($imageFileInfo == undef || $imageFileInfo->Status() == ::FILE_DOESNTEXIST())
        {  die "Tried to add a reference to a non-existant image file.";  };

    if ($imageFileInfo->AddReference() == 1)
        {
        delete $imageFilesToPurge{$imageFile};

        if (!$imageFileInfo->WasUsed() ||
            $imageFileInfo->Status() == ::FILE_NEW() ||
            $imageFileInfo->Status() == ::FILE_CHANGED())
            {  $imageFilesToUpdate{$imageFile} = 1;  };
        };
    };


#
#   Function: DeleteImageFileReference
#   Deletes a reference from the passed image <FileName>.
#
sub DeleteImageFileReference #(FileName imageFile)
    {
    my ($self, $imageFile) = @_;

    if (!exists $imageFiles{$imageFile})
        {  $imageFile = $insensitiveImageFiles{lc($imageFile)};  };

    if (!exists $imageFiles{$imageFile})
        {  die "Tried to delete a reference to a non-existant image file.";  };

    if ($imageFiles{$imageFile}->DeleteReference() == 0)
        {
        delete $imageFilesToUpdate{$imageFile};

        if ($imageFiles{$imageFile}->WasUsed())
            {  $imageFilesToPurge{$imageFile} = 1;  };
        };
    };


#
#   Function: ImageFilesToUpdate
#   Returns an existence hashref of image <FileNames> that need to be updated.  *Do not change.*
#
sub ImageFilesToUpdate
    {  return \%imageFilesToUpdate;  };


#
#   Function: ImageFilesToPurge
#   Returns an existence hashref of image <FileNames> that need to be updated.  *Do not change.*
#
sub ImageFilesToPurge
    {  return \%imageFilesToPurge;  };



#
#   Function: GetAllSupportedFiles
#
#       Gets all the supported files in the passed directory and its subdirectories
#       and puts them into <supportedFiles>.  The only attribute that will be set
#       is <NaturalDocs::Project::File->LastModified()>.  Also sets <mostUsedLanguage>.
#
sub GetAllSupportedFiles
    {
    my ($self) = @_;

    my @directories = @{NaturalDocs::Settings->InputDirectories()};
    my $isCaseSensitive = NaturalDocs::File->IsCaseSensitive();

    # Keys are language names, values are counts.
    my %languageCounts;


    # Make an existence hash of excluded directories.

    my %excludedDirectories;
    my $excludedDirectoryArrayRef = NaturalDocs::Settings->ExcludedInputDirectories();

    foreach my $excludedDirectory (@$excludedDirectoryArrayRef)
        {
        if ($isCaseSensitive)
            {  $excludedDirectories{$excludedDirectory} = 1;  }
        else
            {  $excludedDirectories{lc($excludedDirectory)} = 1;  };
        };


    my $imagesOnly;
    my $language;

    while (scalar @directories)
        {
        my $directory = pop @directories;

        opendir DIRECTORYHANDLE, $directory;
        my @entries = readdir DIRECTORYHANDLE;
        closedir DIRECTORYHANDLE;

        @entries = NaturalDocs::File->NoUpwards(@entries);

        foreach my $entry (@entries)
            {
            my $fullEntry = NaturalDocs::File->JoinPaths($directory, $entry);

            # If an entry is a directory, recurse.
            if (-d $fullEntry)
                {
                # Join again with the noFile flag set in case the platform handles them differently.
                $fullEntry = NaturalDocs::File->JoinPaths($directory, $entry, 1);

                if ($isCaseSensitive)
                    {
                    if (!exists $excludedDirectories{$fullEntry})
                        {  push @directories, $fullEntry;  };
                    }
                else
                    {
                    if (!exists $excludedDirectories{lc($fullEntry)})
                        {  push @directories, $fullEntry;  };
                    };
                }

            # Otherwise add it if it's a supported extension.
            else
                {
                my $extension = NaturalDocs::File->ExtensionOf($entry);

                if (exists $imageFileExtensions{lc($extension)})
                    {
                    my $fileObject = NaturalDocs::Project::ImageFile->New( (stat($fullEntry))[9], ::FILE_NEW(), 0 );
                    $imageFiles{$fullEntry} = $fileObject;

                    my $lcFullEntry = lc($fullEntry);

                    if (!exists $insensitiveImageFiles{$lcFullEntry} ||
                        ($fullEntry cmp $insensitiveImageFiles{$lcFullEntry}) < 0)
                        {
                        $insensitiveImageFiles{$lcFullEntry} = $fullEntry;
                        };
                    }
                elsif (!$imagesOnly && ($language = NaturalDocs::Languages->LanguageOf($fullEntry)) )
                    {
                    my $fileObject = NaturalDocs::Project::SourceFile->New();
                    $fileObject->SetLastModified(( stat($fullEntry))[9] );
                    $supportedFiles{$fullEntry} = $fileObject;
                    $languageCounts{$language->Name()}++;
                    };
                };
            };


        # After we run out of source directories, add the image directories.

        if (scalar @directories == 0 && !$imagesOnly)
            {
            $imagesOnly = 1;
            @directories = @{NaturalDocs::Settings->ImageDirectories()};
            };
        };


    my $topCount = 0;

    while (my ($language, $count) = each %languageCounts)
        {
        if ($count > $topCount && $language ne 'Text File')
            {
            $topCount = $count;
            $mostUsedLanguage = $language;
            };
        };
    };


#
#   Function: DetermineImageDimensions
#
#   Attempts to determine the dimensions of the passed image and apply them to their object in <imageFiles>.  Will set them to
#   undef if they can't be determined.
#
sub DetermineImageDimensions #(FileName imageFile)
    {
    my ($self, $imageFile) = @_;

    my $imageFileObject = $imageFiles{$imageFile};
    if (!defined $imageFileObject)
        {  die "Tried to determine image dimensions of a file with no object.";  };

    my $extension = lc( NaturalDocs::File->ExtensionOf($imageFile) );
    my ($width, $height);

    if ($imageFileExtensions{$extension})
        {
        open(FH_IMAGEFILE, '<' . $imageFile)
            or die 'Could not open ' . $imageFile . "\n";
        binmode(FH_IMAGEFILE);

        my $raw;

        if ($extension eq 'gif')
            {
            read(FH_IMAGEFILE, $raw, 6);

            if ($raw eq 'GIF87a' || $raw eq 'GIF89a')
                {
                read(FH_IMAGEFILE, $raw, 4);
                ($width, $height) = unpack('vv', $raw);
                };
            }

        elsif ($extension eq 'png')
            {
            read(FH_IMAGEFILE, $raw, 8);

            if ($raw eq "\x89PNG\x0D\x0A\x1A\x0A")
                {
                seek(FH_IMAGEFILE, 4, 1);
                read(FH_IMAGEFILE, $raw, 4);

                if ($raw eq 'IHDR')
                    {
                    read(FH_IMAGEFILE, $raw, 8);
                    ($width, $height) = unpack('NN', $raw);
                    };
                };
            }

        elsif ($extension eq 'bmp')
            {
            read(FH_IMAGEFILE, $raw, 2);

            if ($raw eq 'BM')
                {
                seek(FH_IMAGEFILE, 16, 1);
                read(FH_IMAGEFILE, $raw, 8);

                ($width, $height) = unpack('VV', $raw);
                };
            }

        elsif ($extension eq 'jpg' || $extension eq 'jpeg')
            {
            read(FH_IMAGEFILE, $raw, 2);
            my $isOkay = ($raw eq "\xFF\xD8");

            while ($isOkay)
                {
                read(FH_IMAGEFILE, $raw, 4);
                my ($marker, $code, $length) = unpack('CCn', $raw);

                $isOkay = ($marker eq 0xFF);

                if ($isOkay)
                    {
                    if ($code >= 0xC0 && $code <= 0xC3)
                        {
                        read(FH_IMAGEFILE, $raw, 5);
                        ($height, $width) = unpack('xnn', $raw);
                        last;
                        }

                    else
                        {
                        $isOkay = seek(FH_IMAGEFILE, $length - 2, 1);
                        };
                    };
                };
            };

        close(FH_IMAGEFILE);
        };


    # Sanity check the values.  Although images can theoretically be bigger than 5000, most won't.  The worst that happens in this
    # case is just that they don't get length and width values in the output anyway.
    if ($width > 0 && $width < 5000 && $height > 0 && $height < 5000)
        {  $imageFileObject->SetDimensions($width, $height);  }
    else
        {  $imageFileObject->SetDimensions(undef, undef);  };
    };


#ND+, package
#
#   Function: NewGroup
#
#       Returns a unique group identifier
#
sub NewGroup #(filename)
    {
    my ($self, $filename) = @_;

    my $group = 1;
    foreach my $t_group (sort keys %groupsActive)
        {
        last if ($t_group > $group);                    # hole in sequence
        $group++;                                       # otherwise, test next
        }

    $groupsActive{$group} = 1;
    $supportedFiles{$filename}->SetGroup($group);

    return $group;
    };


#ND+, package
#
#   Function: ResetGroup
#
#       Reset a the files group identifier.
#
sub ResetGroup #(filename)
    {
    my ($self, $filename) = @_;

    if ((my $oldgroup = $supportedFiles{$filename}->Group()) > 0)
        {                                                   # release old group
        $groupsToPurge{$oldgroup} = 1;

        # The group shall still be considered active for this run.
        }

    $supportedFiles{$filename}->SetGroup(0);
    };


#ND+, package
#
#   Function: PackageMembers
#
#       Returns the list of members within a specified package group
#
sub PackageMembers #(package)
    {
    my ($self, $package) = @_;
    my @members = ();

    foreach my $filename (keys %supportedFiles)
        {
        my $packages = $supportedFiles{$filename}->Packages();

        if (defined $packages)
            {
            foreach my $pkg (@$packages)
                {
                if ($package eq $pkg)
                    {
                    push @members, $filename;
                    last;
                    }
                }
            }
        }
    return (@members);
    };


#ND+, package
#
#   Function: RelateAuxiliary
#
#       Returns the list of members within a specified package group
#
sub RelateAuxiliary #(file, child, content)
    {
    my ($self, $file, $child, $content) = @_;
    my $group;

    if (exists $supportedFiles{$file})
        {  $group = $supportedFiles{$file}->Group();  }

    elsif (exists $auxiliaryFiles{$file})
        {  $group = $auxiliaryFiles{$file}->Group();  }

    else
        {  die "Internal: Relating to unknown file '$file'.";  }

    if ($content >= 0)
        {  die "Internal: Related content $content unknown.";  }

    if ($group == 0)
        {  $group = $self->NewGroup($file);  }

    my $aux = NaturalDocs::Project::AuxFile->New();
    $auxiliaryFiles{$child} = $aux;
    $aux->SetHasContent($content);
    $aux->SetGroup($group);
    }


###############################################################################
# Group:    Project Loader
#



#ND+, package
#
#   Function: ParseSupported
#
#       Parse all the supported files which are new/require parsing, performing
#       the following actions;
#
#       o Build a list of packages, recursive reparsing any package components.
#       o Merge (if required) package components.
#       o Split (if required) package components.
#       o Update the symbol table for each file to be built.
#       o Update the <filesToBuild> with the resulting processing.
#       o Manage auxiliary files related with each package.
#
sub ParseSupported
    {
    my ($self) = @_;

    # Must reparse any image contained within filesToBuild which belongs to a
    # package set containing more then one member.
    foreach my $filename (keys %filesToBuild)
        {
        if (! exists $filesToParse{$filename})
            {
            my @packages = $supportedFiles{$filename}->Packages();

            foreach my $package (@packages)
                {
                if (scalar NaturalDocs::Project->PackageMembers($package) > 1)
                    {
                    $filesToParse{$filename} = 1;
                    delete $unbuiltFilesWithContent{$filename};
                    last;
                    }
                }
            }
        }

    # XXX - place within a loop (phase 1..x)
    #
    #   while ((filesToRebuild = filesToParse())
    #       filesToRebuild = ();
    #
    #       if (Scan)
    #           Merge and/or Split
    #
    #       foreach file (filesToParse)
    #           Update symbols
    #           filesParsed{file) = 1;                  <= new symbol
    #   EndIf
    #
    #   RebuildFile
    #       if (!filesParsed)
    #           filesToRebuild = 1;
    #   Endif
    #

    # Build symbol table and update project on the file's characteristics.
    if (scalar %filesToParse)
        {
        # Process packages
        if ((my $package_components = $self->PackageScan("Parsing", \%filesToParse)))
            {
            $self->PackageMerge($package_components);
            $self->PackageSplit($package_components);
            }

        # Update symbols
        $self->Message("Updating symbol table...");

        foreach my $file (keys %filesToParse)
            {
            $self->Verbose("\t$file");

            # Parse symbols,
            #   - Updates the symbol table, which thru <RebuildFile> forces the
            #     regeneration of any referenced definitions.
            #   - Via SetHasContents() informs the project of the file status.
            #   - If it has contents, also updates the default menu title.
            #
            NaturalDocs::Parser->ParseSymbols($file);
            }
        }

    # Parse any additional files
    if (scalar %filesToRebuild)
        {
        if ((my $package_components = $self->PackageScan("Reparsing", \%filesToRebuild)))
            {
            $self->PackageMerge($package_components);
            $self->PackageSplit($package_components);
            }
        }

    # Inform parser of our intent to rebuild without parsing for symbols.
    #
    # FIXME - The only advantage toward differing between reparse and rebuild is 
    #               under low memory conditions, this is an issue today ?  
    #
    #   Try running 
    #       ND on the current linux/BSD kernel source tree as a test.
    #
    foreach my $filename (keys %filesToBuild)
        {
        if (! exists $filesToParse{$filename})
            {
            my $file = NaturalDocs::Parser->ParsedFile($filename);

            $file->SetTopics([]);
            $file->SetObjects([]);
            }
        }

    # Purge related auxiliary files to groups being purged
    foreach my $group (keys %groupsToPurge)
        {
        foreach my $aux (keys %auxiliaryFiles)
            {
            if ($group == $auxiliaryFiles{$aux}->Group())
                {
                if ($auxiliaryFiles{$aux}->HasContent() == ::AUX_IMAGE())
                    {  unlink $aux;  }                  # remove imported image

                elsif (! exists $filesToBuild{$aux} )
                    {  $filesToPurge{$aux} = 1;  }      # no longer required

                delete $auxiliaryFiles{$aux};
                }
            }
        }

    # Add remaining split package fragments to unbuild file list, as a
    # complete list of output images is required by the menu processing module.
    foreach my $aux (keys %auxiliaryFiles)
        {
        if ($auxiliaryFiles{$aux}->HasContent() == ::AUX_FRAGMENT())
            {  $unbuiltFilesWithContent{$aux} = 1;  }
        }
    }


#ND+, package
#
#   Function: RebuildFile
#
#       Intended to be invoked during <Parser::ParseSymbols>.  Touchs the input stream,
#       adding the file to the list of files that need to rebuilt.
#
#       This function will automatically filter out files that don't have Natural Docs
#       content and files that are part of <FilesToPurge()>.
#
#   Parameters:
#
#       filename - The <FileName> to build or rebuild.
#
sub RebuildFile #(file)
    {
    my ($self, $filename) = @_;
    my ($aux) = 0;

    # If an auxiliary file, must rebuild the parent
    if (exists $auxiliaryFiles{$filename})
        {
        my $group = $auxiliaryFiles{$filename}->Group();

        $self->Debug("RebuildAux($group)");
        $aux = 1;
        $filename = undef;
        foreach my $t_filename (keys %supportedFiles)
            {
            if ($supportedFiles{$t_filename}->Group() == $group)
                {
                $filename = $t_filename;
                last;
                }
            }
        }

    # Rebuild specified file
    if ($filename)
        {
        if (defined (my $file = $supportedFiles{$filename}))
            {
            if (!exists $filesToParse{$filename} && !exists $filesToPurge{$filename} &&
                    (scalar $file->Packages() || $file->HasContent()))
                {
                $self->Debug(("->"*$aux), "RebuildFile($filename)");
                $filesToRebuild{$filename} = 1;
                delete $unbuiltFilesWithContent{$filename};
                }
            }
        }
    };


#ND+, package
#
#   Function: PackageScan
#
#       Scan supported file images determining package components.
#
sub PackageScan #($desc, $parselist)
    {
    my ($self, $desc, $parseList) = @_;
    my @parseList = ();

    return if (! scalar %$parseList);

    # Build initial load list
    foreach my $filename (keys %$parseList)
        {  push @parseList, $filename;  }

    # Categorise each input file
    my ($index, $count) = (-1, scalar @parseList);
    my %package_components;

    while (scalar @parseList)
        {
        # Load file
        if ($index <= 0)
            {
            NaturalDocs::StatusMessage->Start($desc . ($index == -1 ? " " : " additional ") .
                    $count . ' file' . ($count > 1 ? 's' : '') . '...', $count);

            # Sorting the parse list should result in better usage of disk caching 
            # as a result of sequential file access.

            @parseList = sort {$b cmp $a} @parseList;   # reverse sort as we pop

            $index = $count;
            $count = 0;
            }

        my $filename = pop @parseList;                  # file to parse.

        $self->Verbose("\t$filename");

        my $topics = NaturalDocs::Parser->Load($filename)->Topics();

        # Walk the topic list
        my @packages = ();                              # encountered packages

        for (my $tidx = 0; $tidx < scalar @$topics; $tidx++)
            {
            my $topic = $topics->[$tidx];
            my $typeinfo = NaturalDocs::Topics->TypeInfo($topic->Type());

            # New scope
            if ($typeinfo->Scope() != ::SCOPE_START || ! $topic->Package())
                {  next;  }

            my $package = $topic->Package();            # current package
            my $method = $typeinfo->Multiple();

            # New shareholder
            my $grep_safe = quotemeta($package);

            if (! grep /^$grep_safe$/, @packages )
                {
                if ($method)                            # package restructure may have occurred.
                    {
                    # Load missing package components (if any)
                    my (@members) = NaturalDocs::Project->PackageMembers($package);

                    foreach my $member (@members)
                        {
                        if (exists $supportedFiles{$member} && ! exists $filesToParse{$member} &&
                                ! exists $$parseList{$member} )
                            {                           # additional files to parse
                            push @parseList, $member;

                            $filesToParse{$member} = 1;
                            delete $unbuiltFilesWithContent{$member};

                            $count++;
                            }
                        }
                    }

                push @packages, $package;
                }

            # New component
            my $primary = ($topic->Body() ? 1 : 0);     # TODO || $topic->IsDefinition()
            my $new = 1;

            $self->Debug("\t Body => ".$topic->Body()."\n");

            if (exists $package_components{$package})
                {
                my $components = $package_components{$package};

                for (my $cidx = 0; $cidx < scalar @$components; $cidx++)
                    {                                   # already exists?
                    my $component = @$components[$cidx];

                    if ($component->{FILE} eq $filename)
                        {
                        if (! $primary || $component->{PRIMARY})
                            {  $new = 0;  }             # existing higher priority
                        else                            # must upgrade status
                            {  splice @$components, $cidx, 1;  }
                        last;
                        }
                    }
                }

            if ($new)                                   # New/update component record
                {
                my $component = {
                        FILE    => $filename,
                        PRIMARY => $primary,
                        INDEX   => $tidx,
                        METHOD  => $method
                        };

                if ($primary)
                    {  unshift @{$package_components{$package}}, $component;  }
                else
                    {  push @{$package_components{$package}}, $component;  }
                }
            }

        foreach my $pkg (@packages)
            {
            my $components = $package_components{$pkg};

            for (my $cidx = 0; $cidx < scalar @$components; $cidx++)
                {
                if ((my $r = @$components[$cidx])->{FILE} eq $filename)
                    {
                    $self->Debug("\t => ".$self->PrtPkg($pkg).",".$r->{PRIMARY}.",".$r->{INDEX}.",". $r->{METHOD});
                    }
                }
            }

        # Reset the file group, purging any related auxiliary files.
        $self->ResetGroup($filename);

        # Drop topics of non-packaged source images
        if (! scalar @packages)
#TODO       if (NaturalDocs::Settings->IsMemory())      # memory vs speed optimisation
                {
                NaturalDocs::Parser->Drop($filename);
                }

        # Assign ownership
        $supportedFiles{$filename}->SetPackages(\@packages);

        NaturalDocs::StatusMessage->CompletedItem();    # update status

        $index--;
        }

    # Deal with package structure errors
    foreach my $package (keys %package_components)
        {
        my $components = $package_components{$package};
        my (@members) = NaturalDocs::Project->PackageMembers($package);

        if (! @$components[0]->{PRIMARY})
            {
            $self->Warning("No definition for package '".$self->PrtPkg($package)."'");

            @$components[0]->{METHOD} = undef;
            }

        elsif (scalar @$components >= 2 && @$components[1]->{PRIMARY})
            {
            $self->Warning("Multiple definitions for package '".$self->PrtPkg($package)."'");

            for (my $pidx = 0; $pidx < scalar @$components; $pidx++)
                {
                last if (! @$components[$pidx]->{PRIMARY});

                $self->Message("\t@$components[$pidx]->{FILE}");
                }

            @$components[0]->{METHOD} = undef;
            }
        }

    return \%package_components;
    }


#ND+, package
#
#   Function: PackageMerge
#
#       Merge package components, by one of the following methods;
#
#       o Relocating package topics into the primary image, or
#       o Generate a compound summary within the primary image.
#
sub PackageMerge #(package_components)
    {
    my ($self, $package_components) = @_;

    $self->Debug("==> PackageMerge()");

    foreach my $package (keys %$package_components)
        {
        my $components = @$package_components{$package};

        next if (scalar @$components <= 1);             # single package

        next if (! defined @$components[0]->{METHOD});  # merge method undefined

        my $summaries = (@$components[0]->{METHOD} == ::MULTIPLE_SUMMARIES() ? 1 : 0);
        my $pfilename = @$components[0]->{FILE};
        my $pstart = @$components[0]->{INDEX};          # start of package
        my $lang = NaturalDocs::Parser->Language($pfilename);

        $self->Message(($summaries ? "  Summarising " : "  Merging ") . $self->PrtPkg($package, $lang));

        $self->Verbose("\t$pfilename");

        my $ptopics = NaturalDocs::Parser->Topics($pfilename);
        my $pinsert = -1;                               # insert location

        # Walk components list
        for (my $cidx = 1; $cidx < scalar @$components; $cidx++)
            {
            my $filename = @$components[$cidx]->{FILE};
            my $topics = NaturalDocs::Parser->Topics($filename);
            my $insidepkg = 0;
            my $mixed = 0;

            $self->Debug("\t+ $filename");

            # Walk topics
            for (my $tidx = 0; $tidx < scalar @$topics; $tidx++)
                {
                my $topic = $topics->[$tidx];
                my $type = $topic->Type();
                my $scope = NaturalDocs::Topics->TypeInfo($type)->Scope();

                if ($scope == ::SCOPE_START())
                    {                                   # package start
                    $self->Debug("\t\tSection ($tidx) " . $self->PrtPkg($topic->Package(), $lang));

                    $insidepkg = ($topic->Package() eq $package);
                    $mixed++ if (! $insidepkg);
                    }

                elsif ($scope == ::SCOPE_END())
                    {                                   # global start
                    $self->Debug("\t\tSection ($tidx) GLOBAL");

                    $insidepkg = 0;
                    $mixed++;
                    }

                elsif ($insidepkg)
                    {                                   # mergable topic
                    if ($type eq ::TOPIC_GROUP())
                        {
                        my $title = $topic->Title();
                        my $pidx = $pstart+1;           # insert position

                        $self->Debug("\t\t\tGroup ($tidx) $title");

                        for ($pinsert = -1; $pidx < scalar @$ptopics; $pidx++)
                            {                           # matching group?
                            my $ptopic = $ptopics->[$pidx];
                            my $ptype = $ptopic->Type();
                            my $pscope = NaturalDocs::Topics->TypeInfo($ptype)->Scope();

                            if ($pscope == ::SCOPE_START() || $pscope == ::SCOPE_END())
                                {  last;  }             # end of package

                            elsif ($ptype eq ::TOPIC_GROUP())
                                {                       # match group
                                if ($ptopic->Title() eq $title)
                                    {  $pinsert = $pidx+1;  }
                                elsif ($pinsert != -1)
                                    {  last;  }         # end of previous group
                                }
                            elsif ($pinsert != -1)
                                {  $pinsert = $pidx+1;  }
                            }

                        if ($pinsert == -1)             # new group required ?
                            {
                            $pinsert = $pidx;           # end of current section
                            if ($summaries)
                                {                       # summary group
                                $topic = NaturalDocs::Parser::ParsedTopic->New( $type,
                                            $topic->Title(), $topic->Package(), $topic->Using(),
                                            $topic->Prototype(), $topic->Summary(),
                                            undef, undef, undef, ::SUMMARIES_ONLY());
                                }
                            splice(@$ptopics, $pinsert++, 0, $topic);

                            $self->Debug("\t\t\t.. new group ($pinsert)");
                            }
                        else
                            {
                            $self->Debug("\t\t\t.. existing group ($pinsert)");
                            }
                        }
                    elsif ($pinsert >= 0)
                        {
                        $self->Debug("\t\t\t.. merging topic ($tidx -> $pinsert)");

                        if ($summaries)
                            {                           # summary topic
                            $topic = NaturalDocs::Parser::ParsedTopic->New( $type,
                                        $topic->Title(), $topic->Package(), $topic->Using(),
                                        $topic->Prototype(), $topic->Summary(),
                                        undef, undef, undef, ::SUMMARIES_ONLY());
                           }
                        else
                            {                           # copy the topic
                            $topic = NaturalDocs::Parser->CopyTopic($topic, $filename, $pfilename);
                            }

                        splice(@$ptopics, $pinsert++, 0, $topic);
                        }
                    else
                        {
                        $self->Debug("\t\t\t.. untouched topic ($tidx, $type)");
                        }
                    }

                if ($insidepkg && ! $summaries)
                    {  splice(@$topics, $tidx--, 1);  } # remove from source
                }

            # remove knownledge of source
            if (! $mixed && ! $summaries)
                {                                       
                $self->Debug("\t\tRemoving image");

                delete $filesToParse{$filename};        # .. dont parse further
                $filesToPurge{$filename} = 1;           # .. remove old image

                NaturalDocs::Parser->Unload($filename); # .. unload topics

                                                        # no longer has content
                $supportedFiles{$filename}->SetHasContent(0);
                }
            }

        # Rebuild primary
        $supportedFiles{$pfilename}->SetHasContent(1);
        $filesToBuild{$pfilename} = 1;
        }
    };


#ND+, package
#
#   Function: PackageSplit
#
#       Push splittable topics into thier own file image.
#
sub PackageSplit #(package_components)
    {
    my ($self, $package_components) = @_;

    $self->Debug("==> PackageSplit()");

    foreach my $package (keys %$package_components)
        {
        my $components = @$package_components{$package};

        next if (@$components[0]->{METHOD} != ::MULTIPLE_SPLIT());

        my @packageparts = NaturalDocs::SymbolString->IdentifiersOf($package);

        my $filename = @$components[0]->{FILE};
        my $topics   = NaturalDocs::Parser->Topics($filename);
        my $language = NaturalDocs::Parser->Language($filename);

        my $section = undef;                            # active section (if any)
        my $group = undef;                              # current group
        my $split = 0;                                  # number of split operations

        $self->Debug("Splitting $filename");

        # Walk topics of primary/merged image
        for (my $tidx = 0; $tidx < scalar @$topics; $tidx++)
            {
            my $topic = $topics->[$tidx];
            my $type = $topic->Type();
            my $typeinfo = NaturalDocs::Topics->TypeInfo($type);
            my $scope = $typeinfo->Scope();

            $self->DebugTopic($topic, "\t  ", "Topic ($tidx) ");

            if ($scope == ::SCOPE_START())
                {                                       # section
                if ($section && $group)
                    {  $group->SetSummaries(::SUMMARIES_ONLY());  }

                $section = ($topic->Package eq $package ? $topic : undef);
                $group = undef;

                $self->Debug("\tSection ($tidx) " . $topic->Title()) if ($section);
                }

            elsif ($scope == ::SCOPE_END())
                {                                       # global section
                if ($section && $group)
                    {  $group->SetSummaries(::SUMMARIES_ONLY());  }

                $section = undef;
                }

            elsif ($section)
                {                                       # active section
                if ($type eq ::TOPIC_GROUP())
                    {
                    $self->Debug("\t\tGroup ($tidx) " . $topic->Title());

                    if ($group)
                        {  $group->SetSummaries(::SUMMARIES_ONLY());  }
                    $group = $topic;
                    }

                elsif ($typeinfo->Splittable())
                    {
                    if ($split++ == 0)
                        {
                        $self->Message("  Splitting " . $self->PrtPkg($package, $language));
                        $self->Verbose("\t$filename");
                        }

                    # replace topic (summary only)

                    $topics->[$tidx] = NaturalDocs::Parser::ParsedTopic->New($type,
                                $topic->Title(), $package, $topic->Using(), $topic->Prototype(),
                                $topic->Summary(), undef, undef, undef, ::SUMMARIES_ONLY());

                    # Build auxiliary image

                    my ($vol, $dir, $file) = NaturalDocs::File->SplitPath($filename);

                                                        # derive filename
                    $file = join('_', @packageparts) . '_' . $topic->Title() . '.' .
                                    NaturalDocs::File->ExtensionOf($file);

                    my $t_filename = NaturalDocs::File->JoinPath($vol, $dir, $file);

                    my $t_title = join($language->PackageSeparator(), @packageparts) .
                                            $language->PackageSeparator() . $topic->Title();

                    $self->Debug("\t\t.. splitting topic ($tidx) -> $t_filename");
                    $self->Debug("\t\t.. @$topic");
                                                                            
                                                        # initialise the new stream
                    my $file = NaturalDocs::Parser->ParsedFile($t_filename);
                    my @newTopics = ();

                    $file->SetLanguage($language);
                    $file->SetDefaultMenuTitle($t_title);
                    $file->SetTopics(\@newTopics);

                                                        # ... summary topic
                    push @newTopics, NaturalDocs::Parser::ParsedTopic->New( 
                                                $section->Type(), $section->Title());

                                                        # ... clone topic
                    push @newTopics, NaturalDocs::Parser->CopyTopic($topic, $filename, $t_filename);

                                                        # relate new stream to parent
                    $self->RelateAuxiliary($filename, $t_filename, ::AUX_FRAGMENT());

                    $filesToParse{$t_filename} = 1;     # parse auxiliary
                    }
                else
                    {
                    $group = undef;                     # group isnt empty
                    }
                }
            }

        if ($section && $group)
            {  $group->SetSummaries(::SUMMARIES_ONLY());  }
        }
    };


#ND+, package
sub PrtPkg
    {
    my ($self, $package, $lang) =  @_;

    my @packageparts = NaturalDocs::SymbolString->IdentifiersOf($package);
    my $separator = ($lang ? $lang->PackageSeparator() : '.');

    return join($separator, @packageparts);
    }


#ND+, package   #FIXME, global?
sub Message
    {
    my ($self) = shift @_;

    return if (NaturalDocs::Settings->IsQuiet());
    print "@_\n";
    };


#ND+, package   #FIXME, global?
sub Warning
    {
    my ($self) = shift @_;

    return if (NaturalDocs::Settings->IsQuiet());
    print "NaturalDocs: warning: @_\n";
    };


#ND+, package   #FIXME, global?
sub Verbose
    {
    my ($self) = shift @_;

    ##FIXME
    ##  return if (!NaturalDocs::Settings->IsVerbose());
    ##  print "(V) @_\n";
    };


#ND+, package   #FIXME, global?
sub Debug
    {
    my ($self) = shift @_;

    ##FIXME
    ##  return if (!NaturalDocs::Settings->IsDebug());       
    ##  print "(D) @_\n";
    };


#ND+, package   #FIXME, topic?
sub DebugTopic
    {
    my ($self, $topic, $delim, @msg) = @_;

    ##FIXME
    ##  return if (!NaturalDocs::Settings->IsDebug());       
    ##
    ##  my $typeinfo = NaturalDocs::Topics->TypeInfo($topic->Type());
    ##
    ##  $delim = " " if (! $delim);
    ##  $delim = "(D)$delim";
    ##
    ##  print $delim . "@msg\n" if (scalar @msg);
    ##  print $delim . "  Type      = " . $topic->Type() . "\n";
    ##  print $delim . "    Scope   = " . $typeinfo->Scope() . "\n";
    ##  print $delim . "    Hier    = " . $typeinfo->ClassHierarchy() . "\n";
    ##  print $delim . "  Title     = " . $topic->Title() . "\n";
    ##  print $delim . "  Package   = " . $topic->Package() . "\n";
    ##  print $delim . "  Summaries = " . $topic->Summaries() . "\n";
    };

1;
