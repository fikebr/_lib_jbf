package JBF;
use strict;
use warnings;
use Exporter qw(import);
our @ISA =   qw(Exporter);
our @EXPORT = qw(datestr say read_file $LOGFILE $DEBUG $VERSION $NOPAUSE);

use vars '$VERSION';
$VERSION = 1.1.0;
# 2017-05-27 : 1.0.0 : Initial file
# 2017-08-12 : 1.0.1 : pausing feature in say
# 2017-09-10 : 1.0.2 : $LOGFILE
# 2018-01-02 : 1.0.3 : $NOPAUSE
# 2018-01-30 : 1.1.0 : added read_file

# common header in the script.
# $DEBUG = 0;
# $NOPAUSE = 1; #this turns off pausing.
# if ($0 =~ m/^(.+)\..+/) { $LOGFILE = "$1.log"; }


our $LOGFILE = "";
our $DEBUG = 0;
our $NOPAUSE = 0;


sub say {
	# options: i, p, d
	# i = print caller information
	# p = pause the script and wait for a keystroke (if "x" then exit)
	# d = this is a debug msg. if $DEBUG = 0 then this will be skipped.
	# $LOGFILE = if this is not null then the msg will also be written to the file.
	
	my $msg = shift;
	my $opts = shift || "";

	if (! $msg) { return(); }
	
	# indent multi line messages.
	my $indent = ' ' x 20;
	$msg =~ s/\n/\n$indent/g;
	
	# test for the options.
	my $info  = index($opts, "i") + 1;
	my $pause = index($opts, "p") + 1;
	my $debug = index($opts, "d") + 1;
	
	# if this is a debug msg and the debug flag is off then exit now.
	if ($debug && !$DEBUG) { return(); }
	if ($debug) { $msg = '[DEBUG] ' . $msg; }

	# add caller info to the msg
	if ($info) {
		my @caller = caller(1);
		my $line;
		my $file;
		my $sub;
		
		if ($caller[0]) {
			$line = $caller[2];
			$file = $caller[1];
			$sub  = $caller[3];
		}
		else {
			@caller = caller();
			$line = $caller[2];
			$file = $caller[1];
			$sub  = $caller[0];
		}

		$msg = "[$file::$sub::$line] $msg";
	}
	
	# add timestamp to the msg
	$msg = datestr("yy-m-d h:n:s") . " > $msg";
	
	# print to STDOUT;
	print $msg, "\n";
	
	# print message to log file
    if ($LOGFILE) {
        open(FH, ">>$LOGFILE");
        print FH $msg, "\n";
        close(FH);
    }

	
	# pause if the pause option is set
	if ($pause && !$NOPAUSE) {
		print "pause > ";
		my $input = <STDIN>;
		chomp($input);
		if ($input eq "x") { exit; }
	}
}

sub read_file {
    my $file = shift;

    open(MYFILE, "<$file");
    my(@lines) = <MYFILE>;
    close(MYFILE);


    my $out = join("\n", @lines);

    return $out;
}


sub datestr{
# converts the current datetime to a string using a given format
# s = seconds
# n = minutes
# h = hours
# d = day
# m = month (number)
# M = month (string)
# y = year
# yy = year (2-digit)
# w = day of week (string)
# default string: 11/27/2014 09:58:23

    #my $format  = shift || "";
    #my $timestamp = shift || ""; #epoch time
	my ($format, $timestamp) = @_;
    my $out = "";


	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst);
    if ($timestamp) {
		($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($timestamp);
	}
	else {
		($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime();
	}

    $year += 1900;

    my @months = qw( Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec );
    my $month = $months[$mon];
    $mon++;

    my @days = qw( Sun Mon Tue Wed Thu Fri Sat );
    my $day = $days[$wday];
    $wday++;

    my $yy = substr($year, -2);

    if ($mon < 10){ $mon = "0$mon"; }
    if ($mday < 10){ $mday = "0$mday"; }
    if ($hour < 10){ $hour = "0$hour"; }
    if ($min < 10){ $min = "0$min"; }
    if ($sec < 10){ $sec = "0$sec"; }


    if ($format eq "") {
        $out = "$mon/$mday/$year $hour:$min:$sec"
    } else {
        $out = $format;
        $out =~ s/s/$sec/g;
        $out =~ s/n/$min/g;
        $out =~ s/h/$hour/g;
        $out =~ s/d/$mday/g;
        $out =~ s/m/$mon/g;
        $out =~ s/M/$month/g;
        $out =~ s/yy/$yy/g;
        $out =~ s/y/$year/g;
        $out =~ s/w/$day/g;
    }

    return $out;

}

1;
