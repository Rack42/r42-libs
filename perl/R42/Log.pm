# $Id: Log.pm,v 1.13 2010-03-15 14:55:13 dsacchet Exp $
#
#

=head1 Name

 Log.pm - Fonctions pour logguer

=head1 SYNOPSYS
 
 blabla

=head1 DESCRIPTION

 blabla

=cut

package R42::Log;
use strict;
use R42;
use Sys::Hostname;
use Sys::Syslog;
use File::Basename;
use File::Path;
use File::Basename;

=head1 CONSTANTES

 blabla

=cut

#our $TEST = 0;

=head1 VARIABLES

 blabla

=cut

our $nb_errors=0;
my $hostname;
my $script_name;
my $syslog;
my $quiet;
my $debug;

=head1 INIT

 blabla

=cut

INIT {
	$hostname=Sys::Hostname::hostname;
	$script_name = $0;
	$script_name =~ s@.*/@@;
	$syslog=0;
	$debug=0;
	$quiet=0;
}

=head1 FONCTIONS

=cut

=head2 FUNCTION set_logfile()

 blabla

=cut

sub set_logfile($) {
	my($file) = @_;
	if (not $file) {
		R42::Log::log_message("error","R42::Log::set_logfile: a filename must be given in parameter");
		return $R42::exit_error;
	}
	my ($filename,$dirname) = File::Basename::fileparse($file);
	if( -e $dirname && ! -d $dirname ) {
		R42::Log::log_message("error","R42::Log::set_logfile: Destination path ".$dirname." already exist and is not a directory");
		return $R42::exit_error;
	}
	if( ! -e $dirname ) {
		File::Path::mkpath($dirname, { verbose => !$R42::Log::quiet, error => \my $err } );
		if ( $err ) {
			for my $diag (@$err) {
				my ($file, $message ) = each %$diag;
				R42::Log::log_message("error","R42::Log::set_logfile: Unable to create directory ".$file." (".$message.")");
			}
			return $R42::exit_error;
		}
	}

	if (! open R42LOGFILE, '>>', $file) {
		R42::Log::log_message("error","R42::Log::set_logfile: Unable to initialize the file `$file' : ".$!.".");
		return $R42::exit_error;
	}

	# Pas de buffer d'ecriture / hot filehandle
	select((select(R42LOGFILE,), $|=1)[0]);
	return $R42::exit_ok;
}

=head2 FUNCTION set_logsyslog()

 blabla

=cut

sub set_logsyslog($) {
	my($bool) = @_;
	if (@_ != 1) {
		return $R42::exit_error;
	} 
	if($bool) {
		my $err=0;
		Sys::Syslog::openlog($script_name,"nofatal,pid0","local5") or $err=1;
		$syslog=1 if $err eq 0;
		if($err eq 1) {
			log_message("error","R42::Log::set_logsyslog: Error in Sys::Syslog::openlog");
			return $R42::exit_error;
		}
		return $R42::exit_ok;
	} else {
		Sys::Syslog::closelog;
		$syslog=0;
		return $R42::exit_ok;
	}
}

=head2 FUNCTION set_logquiet()

 blabla

=cut
sub set_logquiet($) {
	my($bool) = @_;
	if (@_ != 1) {
		return $R42::exit_error;
	} 
	if($bool) {
		$quiet=1;
		return $R42::exit_ok;
	} else {
		$quiet=0;
		return $R42::exit_ok;
	}
}

=head2 FUNCTION set_logdebug()

 blabla

=cut
sub set_logdebug($) {
	my($bool) = @_;
	if (@_ != 1) {
		return $R42::exit_error;
	} 
	if($bool) {
		$debug=1;
		return $R42::exit_ok;
	} else {
		$debug=0;
		return $R42::exit_ok;
	}
}


=head2 FUNCTION log_date()

 blabla

cut

sub log_date() {
	my @months = qw/Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec/;
	my($sec, $min, $hour, $day, $mon, $year, $wday, $yday, $isdst) = localtime time;
	my $date = sprintf "%s %2d %02d:%02d:%02d", $months[$mon], $day, $hour, $min, $sec;
	return $date;
}

=head2 FUNCTION log_message($type,$message)

 blabla

=cut

sub log_message($$) {
	my($type,$message) = @_;
	if (@_ != 2) {
		return $R42::exit_error;
	} 
	if($type eq "info") {
		if(!$quiet) {
			print $message."\n";
		}
	} elsif($type eq "error") {
		$R42::Log::nb_errors++;
		print STDERR $message."\n";
	} elsif($type eq "debug") {
		if($debug) {
			print $message."\n";
		}
	} else {
		return $R42::exit_ok;
	}
	if($type ne "debug" and fileno R42LOGFILE,) {
		my $date=log_date();
		print R42LOGFILE $date." ".$hostname." ".$script_name."[".$$."]: (".$type.") ".$message."\n";
	}
	if($syslog) {
		if($type eq "error") {
			$type = "err";
		}
		Sys::Syslog::syslog($type,$message);
	}
	return $R42::exit_ok;
}

=head2 FUNCTION log_message_from_file($type,$file)

 blabla

=cut

sub log_message_from_file($$) {
	# TODO
}

1;
