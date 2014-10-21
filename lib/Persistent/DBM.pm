########################################################################
# File:     DBM.pm
# Author:   David Winters <winters@bigsnow.org>
# RCS:      $Id: DBM.pm,v 1.6 2000/02/08 02:35:02 winters Exp $
#
# An abstract class that implements object persistence using a DBM file.
# This class inherits from other persistent classes.
#
# This file contains POD documentation that may be viewed with the
# perldoc, pod2man, or pod2html utilities.
#
# Copyright (c) 1998-2000 David Winters.  All rights reserved.
# This program is free software; you can redistribute it
# and/or modify it under the same terms as Perl itself.
########################################################################

package Persistent::DBM;
require 5.004;

use strict;
use vars qw(@ISA $VERSION $REVISION);

use Carp;
use English;
use Fcntl ':flock';                        # import LOCK_* constants
use POSIX;

### we are a subclass of the all-powerful Persistent::Memory class ###
use Persistent::Memory;
@ISA = qw(Persistent::Memory);

### copy version number from superclass ###
$VERSION = $Persistent::Memory::VERSION;
$REVISION = (qw$Revision: 1.6 $)[1];

=head1 NAME

Persistent::DBM - A Persistent Class implemented using a DBM File

=head1 SYNOPSIS

  use Persistent::DBM;
  use English;  # import readable variable names like $EVAL_ERROR

  eval {  ### in case an exception is thrown ###

    ### allocate a persistent object ###
    my $person = new Persistent::DBM('people.dbm');

    ### define attributes of the object ###
    $person->add_attribute('firstname', 'ID', 'VarChar', undef, 10);
    $person->add_attribute('lastname',  'ID', 'VarChar', undef, 20);
    $person->add_attribute('telnum', 'Persistent',
                           'VarChar', undef, 15);
    $person->add_attribute('bday', 'Persistent', 'DateTime', undef);
    $person->add_attribute('age', 'Transient', 'Number', undef, 2);

    ### query the datastore for some objects ###
    $person->restore_where(qq{
                              lastname = 'Flintstone' and
                              telnum =~ /^[(]?650/
                             });
    while ($person->restore_next()) {
      printf "name = %s, tel# = %s\n",
             $person->firstname . ' ' . $person->lastname,
             $person->telnum;
    }
  };

  if ($EVAL_ERROR) {  ### catch those exceptions! ###
    print "An error occurred: $EVAL_ERROR\n";
  }

=head1 ABSTRACT

This is a Persistent class that uses DBM files to store and retrieve
objects.  This class can be instantiated directly or subclassed.  The
methods described below are unique to this class, and all other
methods that are provided by this class are documented in the
L<Persistent> documentation.  The L<Persistent> documentation has a
very thorough introduction to using the Persistent framework of
classes.

This class is part of the Persistent base package which is available
from:

  http://www.bigsnow.org/persistent
  ftp://ftp.bigsnow.org/pub/persistent

=head1 DESCRIPTION

Before we get started describing the methods in detail, it should be
noted that all error handling in this class is done with exceptions.
So you should wrap an eval block around all of your code.  Please see
the L<Persistent> documentation for more information on exception
handling in Perl.

=head1 METHODS

=cut

########################################################################
#
# -----------------------------------------------------------
# PUBLIC METHODS OVERRIDDEN (REDEFINED) FROM THE PARENT CLASS
# -----------------------------------------------------------
#
########################################################################

########################################################################
# initialize
########################################################################

=head2 new -- Object Constructor

  use Persistent::DBM;

  eval {
    my $obj = new Persistent::DBM($file, $field_delimiter, $type);
  };
  croak "Exception caught: $@" if $@;

Allocates an object.  This method throws Perl execeptions so use it
with an eval block.

Parameters:

=over 4

=item These are the same as for the I<datastore> method below.

=back

=cut

########################################################################
# datastore
########################################################################

=head2 datastore -- Sets/Returns the Data Store Parameters

  eval {
    ### set the data store ###
    $obj->datastore($file, $field_delimiter, $type);

    ### get the data store ###
    $file = $obj->datastore();
  };
  croak "Exception caught: $@" if $@;

Returns (and optionally sets) the data store of the object.  This
method throws Perl execeptions so use it with an eval block.

Parameters:

=over 4

=item I<$file>

File to use as the data store.

=item I<$field_delimiter>

Delimiter used to separate the attributes of the object in the data
store.  This argument is optional and will be initialized to the value
of the special Perl variable I<$;> (or I<$SUBSCRIPT_SEPARATOR> if you
are using the English module) as a default or if set to undef.

=item I<$type>

Type of DBM file to use.  This is probably one of these: NDBM_File,
DB_File, GDBM_File, SDBM_File, or ODBM_File.  This argument is
optional and will default to C<AnyDBM_File>.  See the C<AnyDBM_File>
documentation for more information.

=back

Returns:

=over 4

=item I<$file>

File used as the data store.

=back

=cut

sub datastore {
  (@_ > 0) or croak 'Usage: $obj->datastore([$file], [$delimiter], [$type])';
  my $this = shift;
  ref($this) or croak "$this is not an object";

  $this->_trace();

  ### set it ###
  $this->{DataStore}->{File} = shift if @_;  ## file name ###
  $this->field_delimiter(shift) if @_;  ### field delimiter ###
  if (@_) {  ### DBM type ###
    $this->{DataStore}->{Module} = shift || 'AnyDBM_File';
  } else {
    $this->{DataStore}->{Module} = 'AnyDBM_File';
  }
  eval "require $this->{DataStore}->{Module}";

  ### return it ###
  $this->{DataStore}->{File};
}

########################################################################
# insert
########################################################################

=head2 insert -- Insert an Object into the Data Store

  eval {
    $obj->insert();
  };
  croak "Exception caught: $@" if $@;

Inserts an object into the data store.  This method throws Perl
execeptions so use it with an eval block.

Parameters:

=over 4

=item None.

=back

Returns:

=over 4

=item None.

=back

See the L<Persistent> documentation for more information.

=cut

########################################################################
# update
########################################################################

=head2 update -- Update an Object in the Data Store

  eval {
    $obj->update();
  };
  croak "Exception caught: $@" if $@;

Updates an object in the data store.  This method throws Perl
execeptions so use it with an eval block.

Parameters:

=over 4

=item I<@id>

Values of the Identity attributes of the object.  This argument is
optional and will default to the Identifier values of the object as
the default.

This argument is useful if you are updating the Identity attributes of
the object and you already have all of the attribute values so you do
not need to restore the object (like a CGI request with hidden fields,
maybe).  So you can just set the Identity attributes of the object to
the new values and then pass the old Identity values as arguments to
the I<update> method.  For example, if Pebbles Flintstone married Bam
Bam Rubble, then you could update her last name like this:

  ### Pebbles already exists in the data store, but we don't ###
  ### want to do an extra restore because we already have    ###
  ### all of the attribute values ###

  $person->lastname('Rubble');
  $person->firstname('Pebbles');
  ### set the rest of the attributes ... ###

  $person->update('Flintstone', 'Pebbles');

Or, if don't want to set all of the object's attributes, you can just
restore it and then update it like this:

  ### restore object from data store ###
  if ($person->restore('Flintstone', 'Pebbles')) {
    $person->lastname('Rubble');
    $person->update();
  }

=back

Returns:

=over 4

=item I<$flag>

A true value if the object previously existed in the data store (it
was updated), and a false value if not (it was inserted).

=back

See the L<Persistent> documentation for more information.

=cut

########################################################################
# save
########################################################################

=head2 save -- Save an Object to the Data Store

  eval {
    $person->save();
  };
  croak "Exception caught: $@" if $@;

Saves an object to the data store.  The object is inserted if it does
not already exist in the data store, otherwise, it is updated.  This
method throws Perl execeptions so use it with an eval block.

Parameters:

=over 4

=item None.

=back

Returns:

=over 4

=item I<$flag>

A true value if the object previously existed in the data store (it
was updated), and a false value if not (it was inserted).

=back

See the L<Persistent> documentation for more information.

=cut

########################################################################
# delete
########################################################################

=head2 delete -- Delete an Object from the Data Store

  eval {
    $obj->delete();
    ### or ###
    $obj->delete(@id);
  };
  croak "Exception caught: $@" if $@;

Deletes an object from the data store.  This method throws Perl
execeptions so use it with an eval block.

Parameters:

=over 4

=item I<@id>

Values of the Identity attributes of the object.  This argument is
optional and will default to the Identifier values of the object as
the default.

=back

Returns:

=over 4

=item I<$flag>

A true value if the object previously existed in the data store (it
was deleted), and a false value if not (nothing to delete).

=back

See the L<Persistent> documentation for more information.

=cut

########################################################################
# restore
########################################################################

=head2 restore -- Restore an Object from the Data Store

  eval {
    $obj->restore(@id);
  };
  croak "Exception caught: $@" if $@;

Restores an object from the data store.  This method throws Perl
execeptions so use it with an eval block.

Parameters:

=over 4

=item I<@id>

Values of the Identity attributes of the object.  This method throws
Perl execeptions so use it with an eval block.

=back

Returns:

=over 4

=item I<$flag>

A true value if the object previously existed in the data store (it
was restored), and a false value if not (nothing to restore).

=back

See the L<Persistent> documentation for more information.

=cut

########################################################################
# restore_where
########################################################################

=head2 restore_where -- Conditionally Restoring Objects

  use Persistent::DBM;

  eval {
    my $person = new Persistent::DBM('people.dbm', '|', 'NDBM_File');
    $person->restore_where(
      "lastname = 'Flintstone' and telnum =~ /^[(]?650/",
      "lastname, firstname, telnum DESC"
    );
    while ($person->restore_next()) {
      print "Restored: ";  print_person($person);
    }
  };
  croak "Exception caught: $@" if $@;

Restores objects from the data store that meet the specified
conditions.  The objects are returned one at a time by using the
I<restore_next> method and in a sorted order if specified.  This
method throws Perl execeptions so use it with an eval block.

Since this is a Perl based Persistent class, the I<restore_where>
method expects the I<$where> argument to use Perl expressions.

Parameters:

=over 4

=item I<$where>

Conditional expression for the requested objects.  The format of this
expression is similar to a SQL WHERE clause.  This argument is
optional.

=item I<$order_by>

Sort expression for the requested objects.  The format of this
expression is similar to a SQL ORDER BY clause.  This argument is
optional.

=back

Returns:

=over 4

=item I<$num_of_objs>

The number of objects that match the conditions.

=back

See the L<Persistent> documentation for more information.

=cut

########################################################################
#
# ---------------
# PRIVATE METHODS
# ---------------
#
########################################################################

########################################################################
# Function:    _load_datastore
# Description: Loads the datastore into a hash and returns
#              a reference to it.
#              In this case, the DBM file is tied to a hash.
# Parameters:  None.
# Returns:     $store = reference to the datstore
########################################################################

sub _load_datastore {
  (@_ > 0) or croak 'Usage: $obj->_load_datastore()';
  my $this = shift;
  ref($this) or croak "$this is not an object";

  $this->_trace();

  ### get the DBM file info ###
  my $file = $this->{DataStore}->{File};
  my $delimiter = $this->field_delimiter();

  ### tie the DBM file to a hash ###
  my $href = {};
  tie(%$href, $this->{DataStore}->{Module}, $file, O_CREAT|O_RDWR, 0644) or
    croak "Can't open (tie) $file: $!";

  ### save the hash ref ###
  $this->{DataStore}->{Hash} = $href;
}

########################################################################
# Function:    _flush_datastore
# Description: Flushes the hash containing the data back to the datastore.
#              In this case, the DBM file is untied (closed).
# Parameters:  None.
# Returns:     None.
########################################################################

sub _flush_datastore {
  (@_ > 0) or croak 'Usage: $obj->_flush_datastore()';
  my $this = shift;
  ref($this) or croak "$this is not an object";

  $this->_trace();

  $this->_close_datastore(@_);
}

########################################################################
# Function:    _close_datastore
# Description: Closes the datastore.
#              In this case, the DBM file is untied (closed).
# Parameters:  None.
# Returns:     None.
########################################################################

sub _close_datastore {
  (@_ > 0) or croak 'Usage: $obj->_close_datastore()';
  my $this = shift;
  ref($this) or croak "$this is not an object";

  $this->_trace();

  ### close the DBM file ###
  if (defined $this->{DataStore}->{Hash}) {

    ### untie the DBM file and clear out ref to hash ###
    untie(%{$this->{DataStore}->{Hash}});
    delete $this->{DataStore}->{Hash};
  } else {
    croak "No hash to untie from DBM file";
  }
}

########################################################################
# Function:    _lock_datastore
# Description: Locks the datastore for query or update.
#              For datastore query, use a 'SHARED' lock.
#              For datastore update, use a 'MUTEX' lock.
# Parameters:  $lock_type = 'SHARED' or 'MUTEX'
#              'SHARED' is for read-only.
#              'MUTEX' is for read/write.
# Returns:     None.
########################################################################

sub _lock_datastore {
  (@_ > 0) or croak 'Usage: $obj->_lock_datastore($lock_type)';
  my($this, $lock_type) = @_;
  ref($this) or croak "$this is not an object";

  $this->_trace();

  ### set the flock and open types ###
  my $flock_type = LOCK_SH;
  my $open_type  = '<';
  if ($lock_type =~ /ex/i) {
    $flock_type = LOCK_EX;
    $open_type  = '>';
  }

  ### get the file info ###
  my $file = $this->{DataStore}->{File};

  ### create the file if it does not exist ###
  if (! -e "$file.lock") {
    open(LOCK_FH, ">$file.lock") or croak "Can't create $file.lock: $!";
    close(LOCK_FH);
  }

  ### lock the file ###
  open(LOCK_FH, "${open_type}$file.lock") or croak "Can't open $file.lock: $!";
  flock(LOCK_FH, $flock_type) or
    croak "Can't lock ($lock_type, $open_type) $file.lock: $!";
}

########################################################################
# Function:    _unlock_datastore
# Description: Unlocks the datastore.
#              Unlocks both types of locks, 'SHARED' and 'MUTEX'.
# Parameters:  None.
# Returns:     None.
########################################################################

sub _unlock_datastore {
  (@_ > 0) or croak 'Usage: $obj->_unlock_datastore()';
  my $this = shift;
  ref($this) or croak "$this is not an object";

  $this->_trace();

  ### unlock the file ###
  flock(LOCK_FH, LOCK_UN);
  close(LOCK_FH);
}

### end of library ###
1;
__END__

=head1 SEE ALSO

L<Persistent>, L<Persistent::Base>, L<Persistent::File>,
L<Persistent::Memory>

=head1 NOTES

You may notice some lock files (with a '.lock' extension) in the same
directory as your data files.  These are used to control access to the
data files.

=head1 BUGS

This software is definitely a work in progress.  So if you find any
bugs please email them to me with a subject of 'Persistent Bug' at:

  winters@bigsnow.org

And you know, include the regular stuff, OS, Perl version, snippet of
code, etc.

=head1 AUTHORS

  David Winters <winters@bigsnow.org>

=head1 COPYRIGHT

Copyright (c) 1998-2000 David Winters.  All rights reserved. This program
is free software; you can redistribute it and/or modify it under the
same terms as Perl itself.

=cut
