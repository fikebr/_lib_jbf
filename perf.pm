use strict;

package perf;

my $level = 1;
my $str = "....";
my %timers;
my @report;

##########################################################

sub start {
    my $timer = shift;
    my $tag = shift;

    if (exists $timers{$timer}) { $timers{$timer}; }

    $timers{$timer}->{timer} = $timer;
    $timers{$timer}->{tag} = $tag;
    $timers{$timer}->{ts} = ts();
    $timers{$timer}->{level} = $level;
    $timers{$timer}->{t1} = time();

    my $rpt = $timers{$timer}->{ts};
    $rpt .= " start";
    $rpt .= $str x $timers{$timer}->{level};
    $rpt .= "$timers{$timer}->{timer} $timers{$timer}->{tag}";

    push(@report, $rpt);

    $level++;
}

sub stop {
    my $timer = shift;
    my $tag = shift;
    my $rpt = "";

    if (exists $timers{$timer}) {

        $timers{$timer}->{t2} = time();
        $timers{$timer}->{duration} = duration($timers{$timer}->{t1}, $timers{$timer}->{t2});

        $rpt .= $timers{$timer}->{ts};
        $rpt .= "  stop";
        $rpt .= $str x $timers{$timer}->{level};
        $rpt .= "$timers{$timer}->{timer} $timers{$timer}->{tag}";
        $rpt .= " (duration: $timers{$timer}->{duration})";

    } else {

        $timers{$timer}->{timer} = $timer;
        $timers{$timer}->{tag} = $tag;
        $timers{$timer}->{ts} = ts();
        $timers{$timer}->{t2} = time();

        $rpt .= $timers{$timer}->{ts};
        $rpt .= "  stop";
        $rpt .= $str x $timers{$timer}->{level};
        $rpt .= "$timers{$timer}->{timer} $timers{$timer}->{tag}";

    }

    push(@report, $rpt);

    $timers{$timer};
    $level--;
}

sub report {
    my $report = join("\n", @report);
    my $filename = pfile();

    open my $file_handle, '>', "$filename"
        or die "Could not open the file: $!";
    print {$file_handle} "$report";
    close($file_handle);

    clear();

    return $report;
}

sub clear {
    $level = 1;
    %timers = ( );
    @report = ( );
}


##########################################################

sub duration {
    my $t1 = shift;
    my $t2 = shift;

    my $hours = 0;
    my $mins = 0;
    my $secs = 0;

    my $diff = $t2 - $t1;

    if ($diff >= 3600) {
        $hours = int($diff/3600);
        $diff = $diff % 3600;
    }

    if ($diff >= 60) {
        $mins = int($diff/60);
        $diff = $diff % 60;
    }

    if ($diff < 60) {
        $secs = $diff;
    }

    my $dur = "";
    if ($hours > 0) { $dur .= "$hours" . "h "; }
    if ($mins  > 0) { $dur .= "$mins" . "m "; }
    if ($secs  > 0) { $dur .= "$secs" . "s"; }
    if ($dur eq "") { $dur = "0s"; }

    return $dur;
}



sub pfile {
    my $filename = "";
    if ($0 =~ m/^(.+)\..+/) {
        my $f = $1;
        $filename = "$f." . ts_filename() . ".perf";
    }
    return $filename;
}

sub ts {

    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);

    $mon++;
    if ($mon < 10){ $mon = "0$mon"; }
    if ($mday < 10){ $mday = "0$mday"; }
    if ($hour < 10){ $hour = "0$hour"; }
    if ($min < 10){ $min = "0$min"; }
    if ($sec < 10){ $sec = "0$sec"; }
    $year += 1900;

    return ("$year$mon$mday $hour:$min:$sec");

}

sub ts_filename {

    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);

    $mon++;
    if ($mon < 10){ $mon = "0$mon"; }
    if ($mday < 10){ $mday = "0$mday"; }
    if ($hour < 10){ $hour = "0$hour"; }
    if ($min < 10){ $min = "0$min"; }
    if ($sec < 10){ $sec = "0$sec"; }
    $year += 1900;

    return ("$year$mon$mday$hour$min$sec");

}

1;

