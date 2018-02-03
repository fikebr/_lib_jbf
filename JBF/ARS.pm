package JBF::ARS;
use strict;
use Carp;
use Data::Dump qw(dump);
use ARS;
use Date::Parse;

sub new {
    my $proto = shift;
    my %params = @_;
    my $class = ref($proto) || $proto;
    my $self  = {};

    $self->{SERVER} = $params{SERVER} || undef;
    $self->{USER} = $params{USER} || undef;
    $self->{PASS} = $params{PASS} || undef;
    $self->{PORT} = $params{PORT} || undef;

    $self->{DEBUG} = $params{DEBUG} || 0;

    $self->{VERSION} = "0.0.5";

    $self->{C} = ars_Login($self->{SERVER}, $self->{USER}, $self->{PASS}, "", "", $self->{PORT})
        || croak "JBF::ARS::login: $self->{SERVER} $ars_errstr";

    bless ($self, $class);
    return $self;
}

##########################################################

sub server {
    my $self = shift;
    if ($self->{DEBUG} == 1) {print "Debug->", join("|", (caller(0))[3,2], @_), "\n";}

    return $self->{SERVER};
}

sub version {
    my $self = shift;
    if ($self->{DEBUG} == 1) {print "Debug->", join("|", (caller(0))[3,2], @_), "\n";}

    return $self->{VERSION};
}

sub user {
    my $self = shift;
    if ($self->{DEBUG} == 1) {print "Debug->", join("|", (caller(0))[3,2], @_), "\n";}

    return $self->{USER};
}

sub pass {
    my $self = shift;
    if ($self->{DEBUG} == 1) {print "Debug->", join("|", (caller(0))[3,2], @_), "\n";}

    return $self->{PASS};
}

sub port {
    my $self = shift;
    if ($self->{DEBUG} == 1) {print "Debug->", join("|", (caller(0))[3,2], @_), "\n";}

    return $self->{PORT};
}

sub c {
    my $self = shift;
    if ($self->{DEBUG} == 1) {print "Debug->", join("|", (caller(0))[3,2], @_), "\n";}

    return $self->{C};
}

##########################################################
# Methods for manipulating data

sub query {
    # returns an array of hashes.
    my $self = shift;
    if ($self->{DEBUG} == 1) {print "Debug->", join("|", (caller(0))[3,2], @_), "\n";}

    my $form = shift;
    my $query = shift;
    my @field_names = @_;


    #for the given list of field_names get a list of field ids.
    my @field_ids = $self->field_ids($form, @field_names);

    #get a qual structure based on the given query
    my $qual = ars_LoadQualifier($self->{C}, $form, $query) ||
        carp("query:ars_LoadQualifier: $ars_errstr");

    #run the query and get back a hash of record id\short descriptions
    #then build an array with just the record ids.
    my %entries;
    eval {
        (%entries = ars_GetListEntry($self->{C}, $form, $qual, 0, 0));
            if ($ars_errstr) { carp("query:ars_GetListEntry: $ars_errstr"); }
    };
    my @requestids = keys %entries;

    #for each record id returned above, get the values of the given fields
    my @return_vals;
    foreach my $id (@requestids) {
        my @vals = $self->record_Values($form, $id, @field_ids);

        my %v;
        my @tmp_names = @field_names;

        foreach my $f (@vals) {
            my $key = shift(@tmp_names);
            $v{$key} = $f;
        }

        push @return_vals, \%v;
    }

    return @return_vals;

}

sub query_request_ids {
    # returns an array of hashes.
    my $self = shift;
    if ($self->{DEBUG} == 1) {print "Debug->", join("|", (caller(0))[3,2], @_), "\n";}

    my $form = shift;
    my $query = shift;

    #get a qual structure based on the given query
    my $qual = ars_LoadQualifier($self->{C}, $form, $query) ||
        carp("query:ars_LoadQualifier: $ars_errstr");

    #run the query and get back a hash of record id\short descriptions
    #then build an array with just the record ids.
    my %entries;
    eval {
        (%entries = ars_GetListEntry($self->{C}, $form, $qual, 0, 0));
            if ($ars_errstr) { carp("query:ars_GetListEntry: $ars_errstr"); }
    };
    my @requestids = keys %entries;

    return @requestids;
}

sub record_SaveAttachment {
    my $self = shift;
    if ($self->{DEBUG} == 1) {print "Debug->", join("|", (caller(0))[3,2], @_), "\n";}

    my $form = shift;
    my $recordid = shift;
    my $field = shift;
    my $directory = shift;
    my $filename = shift || "";

    if ($field !~ m/^\d+$/) {
        $field = ($self->field_ids($form, $field))[0];
    }

    my $field_type = $self->field_Type($form, $field);
    if ( $field_type ne "attach") {
        croak("$field: $field_type is not an attachment field.");
    }

    if ($filename eq "") {
        my @q = $self->query($form, qq['1' = "$recordid"], $field);

        $q[0]->{$field}->{name} =~ m~.*[\\|/](.+)$~;
        $filename = $1;
    }

    my $file = "$directory/$filename";

    ars_GetEntryBLOB(
        $self->{C},
        $form,
        $recordid,
        $field,
        ARS::AR_LOC_FILENAME,
        $file) ||
        croak ("ars_GetEntryBLOB: $ars_errstr");

    if (-e $file) {
        return 1;
    } else {
        return undef;
    }

}


sub record_Values {
    my $self = shift;
    if ($self->{DEBUG} == 1) {print "Debug->", join("|", (caller(0))[3,2], @_), "\n";}

    my $form = shift;
    my $recordid = shift;
    my @field_ids = @_;


    my @return_vals;

    # for a given record get the value of every field in a
    # field_id=>value hash.
    my %vals;
    (%vals = ars_GetEntry($self->{C}, $form, $recordid)) || carp $ars_errstr;

    # for each given field_id get the value of the field from the above hash
    # also convert specific data types into readable values.
    foreach my $fieldid (@field_ids) {

        #get the field type of the requested field
        my $fieldtype = $self->field_Type($form, $fieldid);

        #if the field is a selection field then convert the numeric value that
        #is stored in the database into it's string value.
        if ($fieldtype eq "enum") {
            unless ($vals{$fieldid} eq undef) {
                $vals{$fieldid} = $self->value_Enum_Int2Str($form, $fieldid, $vals{$fieldid});
            }
        }

        #if the field is a date\time field then convert the numeric value that
        #is stored in the database into a string value.
        elsif ($fieldtype eq "time") {
            unless ($vals{$fieldid} eq undef) {
                $vals{$fieldid} = $self->value_Time2Str($vals{$fieldid});
            }
        }

        #if the field is a date\time field then convert the numeric value that
        #is stored in the database into a string value.
        elsif ($fieldtype eq "date") {
            unless ($vals{$fieldid} eq undef) {
                $vals{$fieldid} = $self->value_Date2Str($vals{$fieldid});
            }
        }

        push(@return_vals, $vals{$fieldid});
    }

    return @return_vals;
}

sub merge {
    my $self = shift;
    if ($self->{DEBUG} == 1) {print "Debug->", join("|", (caller(0))[3,2], @_), "\n";}

    my $form = shift;
    my $type = shift || 2;
    my %f_vals = @_;

    # MERGE TYPES
    # Type:  Meaning
    # 1:  Generate an error
    # 2:  Create a new entry with the new entry id
    # 3:  Delete the existing entry and create a new on in its place
    # 4:  Update fields specified in the fieldlist in existing entry
    # 1024+num above:  Allow NULL in required fields (not for Submitter, Status or Short-Description)
    # 2048+num above:  Skip field pattern checking

    my @field_names = keys %f_vals;
    my @field_vals  = values %f_vals;
    my @field_ids = $self->field_ids($form, @field_names);
    my @field_id_vals;

    for (my $i = 0; $i < @field_ids; $i++) {
        push @field_id_vals, $field_ids[$i];

        my $field_type = $self->field_Type($form, $field_ids[$i]);

        if ($field_type eq "attach") {
            if (-e $field_vals[$i]) {
                push @field_id_vals, { file => "$field_vals[$i]", size => (stat($field_vals[$i]))[7] }
            } else {
                croak("merge: file [$field_vals[$i]] does not exist.");
            }
        }
        elsif ($field_type eq "enum") {
            if ($field_vals[$i] !~ /^\d+$/) {
                my $str_2_int = $self->value_Enum_Str2Int($form, $field_ids[$i], $field_vals[$i]);
                if ($str_2_int ne undef) {
                    push @field_id_vals, $str_2_int;
                } else {
                    push @field_id_vals, $field_vals[$i];
                }
            } else {
                push @field_id_vals, $field_vals[$i];
            }
        }
        elsif ($field_type eq "date") {
            if ($field_vals[$i] !~ /^\d+$/) {
                my $str_2_date = $self->value_Str2Date($field_vals[$i]);
                if ($str_2_date) {
                    push @field_id_vals, $str_2_date;
                } else {
                    push @field_id_vals, $field_vals[$i];
                }
            } else {
                push @field_id_vals, $field_vals[$i];
            }
        }
        elsif ($field_type eq "time") {
            if ($field_vals[$i] !~ /^\d+$/) {
                my $str_2_time = $self->value_Str2Time($field_vals[$i]);
                if ($str_2_time) {
                    push @field_id_vals, $str_2_time;
                } else {
                    push @field_id_vals, $field_vals[$i];
                }
            } else {
                push @field_id_vals, $field_vals[$i];
            }
        }
        else {
            push @field_id_vals, $field_vals[$i];
        }
    }

    #print dump(@field_id_vals), "\n";

    my $a = ars_MergeEntry($self->{C}, $form, $type, @field_id_vals);
    my $result = "";

    if    (($a ne "") && ($ars_errstr eq "")) { $result = "SUBMIT - $a"; }
    elsif (($a eq "") && ($ars_errstr eq "")) { $result = "MODIFIED"; }
    else  { $result = "$ars_errstr"; }

    return $result;
}

sub modify {
    my $self = shift;
    if ($self->{DEBUG} == 1) {print "Debug->", join("|", (caller(0))[3,2], @_), "\n";}

    my $form = shift;
    my $recordid = shift;
    my %f_vals = @_;

    my @field_names = keys %f_vals;
    my @field_vals  = values %f_vals;
    my @field_ids = $self->field_ids($form, @field_names);
    my @field_id_vals;

    for (my $i = 0; $i < @field_ids; $i++) {
        push @field_id_vals, $field_ids[$i];

        my $field_type = $self->field_Type($form, $field_ids[$i]);

        if ($field_type eq "attach") {
            if (-e $field_vals[$i]) {
                push @field_id_vals, { file => "$field_vals[$i]", size => (stat($field_vals[$i]))[7] }
            } else {
                croak("merge: file [$field_vals[$i]] does not exist.");
            }
        }
        elsif ($field_type eq "enum") {
            if ($field_vals[$i] !~ /^\d+$/) {
                my $str_2_int = $self->value_Enum_Str2Int($form, $field_ids[$i], $field_vals[$i]);
                if ($str_2_int ne undef) {
                    push @field_id_vals, $str_2_int;
                } else {
                    push @field_id_vals, $field_vals[$i];
                }
            } else {
                push @field_id_vals, $field_vals[$i];
            }
        }
        elsif ($field_type eq "date") {
            if ($field_vals[$i] !~ /^\d+$/) {
                my $str_2_date = $self->value_Str2Date($field_vals[$i]);
                if ($str_2_date) {
                    push @field_id_vals, $str_2_date;
                } else {
                    push @field_id_vals, $field_vals[$i];
                }
            } else {
                push @field_id_vals, $field_vals[$i];
            }
        }
        elsif ($field_type eq "time") {
            if ($field_vals[$i] !~ /^\d+$/) {
                my $str_2_time = $self->value_Str2Time($field_vals[$i]);
                if ($str_2_time) {
                    push @field_id_vals, $str_2_time;
                } else {
                    push @field_id_vals, $field_vals[$i];
                }
            } else {
                push @field_id_vals, $field_vals[$i];
            }
        }
        else {
            push @field_id_vals, $field_vals[$i];
        }
    }

    #print dump(@field_id_vals), "\n";

    my $a = ars_SetEntry($self->{C}, $form, $recordid, 0, @field_id_vals);

    my $result = "";

    if ($a) { $result = "MODIFIED"; }
    else  { $result = "$ars_errstr"; }

    return $result;
}

sub create {
    my $self = shift;
    if ($self->{DEBUG} == 1) {print "Debug->", join("|", (caller(0))[3,2], @_), "\n";}

    my $form = shift;
    my %f_vals = @_;

    my @field_names = keys %f_vals;
    my @field_vals  = values %f_vals;
    my @field_ids = $self->field_ids($form, @field_names);
    my @field_id_vals;

    for (my $i = 0; $i < @field_ids; $i++) {
        push @field_id_vals, $field_ids[$i];

        my $field_type = $self->field_Type($form, $field_ids[$i]);

        if ($field_type eq "attach") {
            if (-e $field_vals[$i]) {
                push @field_id_vals, { file => "$field_vals[$i]", size => (stat($field_vals[$i]))[7] }
            } else {
                croak("submit: file [$field_vals[$i]] does not exist.");
            }
        }
        elsif ($field_type eq "enum") {
            if ($field_vals[$i] !~ /^\d+$/) {
                my $str_2_int = $self->value_Enum_Str2Int($form, $field_ids[$i], $field_vals[$i]);
                if ($str_2_int ne undef) {
                    push @field_id_vals, $str_2_int;
                } else {
                    push @field_id_vals, $field_vals[$i];
                }
            } else {
                push @field_id_vals, $field_vals[$i];
            }
        }
        elsif ($field_type eq "date") {
            if ($field_vals[$i] !~ /^\d+$/) {
                my $str_2_date = $self->value_Str2Date($field_vals[$i]);
                if ($str_2_date) {
                    push @field_id_vals, $str_2_date;
                } else {
                    push @field_id_vals, $field_vals[$i];
                }
            } else {
                push @field_id_vals, $field_vals[$i];
            }
        }
        elsif ($field_type eq "time") {
            if ($field_vals[$i] !~ /^\d+$/) {
                my $str_2_time = $self->value_Str2Time($field_vals[$i]);
                if ($str_2_time) {
                    push @field_id_vals, $str_2_time;
                } else {
                    push @field_id_vals, $field_vals[$i];
                }
            } else {
                push @field_id_vals, $field_vals[$i];
            }
        }
        else {
            push @field_id_vals, $field_vals[$i];
        }
    }

    #print dump(@field_id_vals), "\n";

    my $a = ars_CreateEntry($self->{C}, $form, @field_id_vals);
    my $result = "";

    if ($ars_errstr) { $result = "$ars_errstr"; }
    else {
        if ($a) { $result = "SUBMIT - $a"; }
        else { $result = "SUBMIT - UKN"; }
    }

    return $result;
}

sub sql {
    my $self = shift;
    if ($self->{DEBUG} == 1) {print "Debug->", join("|", (caller(0))[3,2], @_), "\n";}

    my $sql = shift;
    my $a;

    ($a = ars_GetListSQL($self->{C}, $sql)) ||
        croak "sql: $ars_errstr";

    return ($a->{numMatches}, $a->{rows});

}

##########################################################
# Helper functions.

sub value_Time2Str {
    my $self = shift;
    if ($self->{DEBUG} == 1) {print "Debug->", join("|", (caller(0))[3,2], @_), "\n";}

    my $tstamp = shift;
    my ($secs, $min, $hour, $day, $month, $year, $ampm, $y2k_year);

    if ( defined($tstamp) ) {
        if ($tstamp eq ' ') { return "0"; }
    } else {
        return "0";
    }

    ($secs, $min, $hour, $day, $month, $year) = localtime($tstamp);

    $y2k_year = 1900 + $year;

    $month++;

    if ($hour > 12) {
        $hour = $hour - 12;
        $ampm = "PM";
    } else {
        $ampm = "AM";
    }

    if ($month < 10) { $month = '0' . $month; }
    if ($day < 10)   { $day = '0' . $day; }
    if ($hour < 10)  { $hour = '0' . $hour; }
    if ($min < 10)   { $min = '0' . $min; }
    if ($secs < 10)  { $secs = '0' . $secs; }

    return "$month/$day/$y2k_year $hour:$min:$secs $ampm";

}

sub value_Date2Str {
    my $self = shift;
    if ($self->{DEBUG} == 1) {print "Debug->", join("|", (caller(0))[3,2], @_), "\n";}
    my $date = "";


    if (defined($_[0])) {
        my($jd) = @_;
        my($jdate_tmp,$m,$d,$y);

        $jdate_tmp = $jd - 1721119;
        $y = (4 * $jdate_tmp - 1) / 146097;
        $jdate_tmp = 4 * $jdate_tmp - 1 - 146097 * $y;
        $d = $jdate_tmp/4;
        $jdate_tmp = (4 * $d + 3)/1461;
        $d = 4 * $d + 3 - 1461 * $jdate_tmp;
        $d = ($d + 4)/4;
        $m = (5 * $d - 3) / 153;
        $d = 5 * $d - 3 - 153 * $m;
        $d = ($d + 5) / 5;
        $y = 100 * $y + $jdate_tmp;

        if ($m < 10) {
            $m += 3;
        } else {
            $m -= 9;
            ++$y;
        }
        $date = "$m/$d/$y";
    } else {
        $date = "";
    }
    #print "$date\n";
    return $date;
}

sub value_Str2Date {
    my $self = shift;
    if ($self->{DEBUG} == 1) {print "Debug->", join("|", (caller(0))[3,2], @_), "\n";}
    my $date = shift;

    my $out = "";

    if ($date eq "NOW") {
        $out = time();
    } else {
        $out = str2time($date);
    }

    if ($out) { $out = int( $out / 86400 ) + 2440588; }

    return $out;

}

sub value_Str2Time {
    my $self = shift;
    if ($self->{DEBUG} == 1) {print "Debug->", join("|", (caller(0))[3,2], @_), "\n";}
    my $date = shift;

    my $out = "";

    if ($date eq "NOW") {
        $out = time();
    } else {
        $out = str2time($date);
    }

    return $out;

}

sub value_Enum_Int2Str {
    my $self = shift;
    if ($self->{DEBUG} == 1) {print "Debug->", join("|", (caller(0))[3,2], @_), "\n";}

    my $form = shift;
    my $fieldid = shift;
    my $int = shift;

    my $fieldinfo = $self->field($form, $fieldid);

    if ($fieldinfo->{limit}{enumLimits}{regularList}) {

        my @regularListValues = @{$fieldinfo->{limit}{enumLimits}{regularList}};
        return $regularListValues[$int];
    }

    if ($fieldinfo->{limit}{enumLimits}{customList}) {

        my %customListValues = map {$_->{itemNumber} => $_->{itemName}}
            @{$fieldinfo->{limit}{enumLimits}{customList}};
        return $customListValues{$int};
    }

}

sub value_Enum_Str2Int {
    my $self = shift;
    if ($self->{DEBUG} == 1) {print "Debug->", join("|", (caller(0))[3,2], @_), "\n";}

    my $form = shift;
    my $fieldid = shift;
    my $value = shift;
    my $return = undef;

    my $fieldinfo = $self->field($form, $fieldid);

    if ($fieldinfo->{limit}{enumLimits}{regularList}) {

        my @regularListValues = @{$fieldinfo->{limit}{enumLimits}{regularList}};

        my $i = 0;
        foreach my $n (@regularListValues) {
            if ($n eq $value) {
                $return = $i;
                last;
            }
            $i++;
        }
    }

    if ($fieldinfo->{limit}{enumLimits}{customList}) {

        my %customListValues = map {$_->{itemNumber} => $_->{itemName}}
            @{$fieldinfo->{limit}{enumLimits}{customList}};

        foreach my $n (keys %customListValues) {
            if ($customListValues{$n} eq $value) {
                $return = $n;
                last;
            }
        }
    }

    return $return;
}



##########################################################
# methods concerning remedy definition structure.

sub field {
    my $self = shift;
    if ($self->{DEBUG} == 1) {print "Debug->", join("|", (caller(0))[3,2], @_), "\n";}

    my $form = shift;
    my $fieldid = shift;

    my $field = ars_GetField($self->{C}, $form, $fieldid) ||
        carp("field: $ars_errstr");

    return $field;
}

sub field_Table {
    my $self = shift;
    if ($self->{DEBUG} == 1) {print "Debug->", join("|", (caller(0))[3,2], @_), "\n";}

    my $form = shift;

    my %table;
    (%table = ars_GetFieldTable($self->{C}, $form)) ||
        carp "field_Table: $ars_errstr";

    return %table;
}

#given a list of field names provide a list of field_ids
sub field_ids {
    my $self = shift;
    if ($self->{DEBUG} == 1) {print "Debug->", join("|", (caller(0))[3,2], @_), "\n";}

    my $form = shift;
    my @field_names = @_;
    my @field_ids;

    #get a field table for form
    my %field_table = $self->field_Table($form);

    #fill the field_ids array from the field_table based
    #on the given field names
    foreach my $name (@field_names) {
        if (exists $field_table{$name}) {
            push @field_ids, $field_table{$name};
        }
        elsif ($name =~ /^\d+$/) {
            push @field_ids, $name;
        }
        else { croak "field_ids: Field [$name] does not exist on form [$form]"; }
    }

    return @field_ids;

}


sub field_Type {
    my $self = shift;
    if ($self->{DEBUG} == 1) {print "Debug->", join("|", (caller(0))[3,2], @_), "\n";}

    my $form = shift;
    my $fieldid = shift;

    my $field = $self->field($form, $fieldid) ||
        carp("field_Type: $ars_errstr");

    return $field->{dataType};
}

sub field_Delete {
    my $self = shift;
    if ($self->{DEBUG} == 1) {print "Debug->", join("|", (caller(0))[3,2], @_), "\n";}

    my $form = shift;
    my $fieldid = shift;

    my $result = ars_DeleteField($self->{C}, $form, $fieldid);

    if ($result == 0) {
        $result = $ars_errstr;
    }

    return $result;
}

# sub fields_list {
#     my $self = shift;
#     if ($self->{DEBUG} == 1) {print "Debug->", join("|", (caller(0))[3,2], @_), "\n";}
#
#     my $form = shift;

sub test_Connection {
    my $self = shift;
    if ($self->{DEBUG} == 1) {print "Debug->", join("|", (caller(0))[3,2], @_), "\n";}

    my $form = 'User';
    my $fieldid = 1;

    my $field = ars_GetField($self->{C}, $form, $fieldid);
    my $err = 'Cannot establish a network connection';

    #print "$ars_errstr\n";
    if ($ars_errstr =~ m/$err/ ) {
        return 0;
    } else {
        return 1;
    }

}

##########################################################

sub DESTROY {
    my ($self) = @_;
    ars_Logoff($self->{C});
}

##########################################################
# TODO: implement an $errstr and @errors system.



1;