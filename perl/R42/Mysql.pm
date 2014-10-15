# $Id: Mysql.pm,v 1.12 2009-11-24 14:23:00 dsacchet Exp $
#
# Module perl Rack42
#

=head1 NAME

 blabla

=cut

=head1 SYNOPSIS

 blabla

=cut

=head1 DESCRIPTION

 blabla

=cut

package R42::Mysql;
use strict;
use R42;
use R42::Log;
use DBI;
use Config::Std;

=head1 CONSTANTES

 blabla

=cut

#our $EXIT_SUCCESS = 0;

=head1 VARIABLES

=cut

my $test_mode = 0;
my $mysql_default_conf;
if(-f $ENV{"HOME"}."/.r42/mysql.conf") {
	$mysql_default_conf = $ENV{"HOME"}."/.r42/mysql.conf";
} elsif(-f "/etc/r42/mysql.conf" ) {
	$mysql_default_conf = "/etc/r42/mysql.conf";
} else {
	$mysql_default_conf = "";
}
R42::Log::log_message('debug',"R42::Mysql: default configuration file is $mysql_default_conf");

=head1 FONCTIONS

=head2 FUNCTION set_mysqltestmode()

 blabla

=cut
sub set_testmode($) {
	my($bool) = @_;
	if (@_ != 1) {
		return $R42::exit_error;
	} 
	if($bool) {
		$test_mode=1;
		R42::Log::log_message('debug',"R42::Mysql: test mode active");
		return $R42::exit_ok;
	} else {
		$test_mode=0;
		R42::Log::log_message('debug',"R42::Mysql: test mode inactive");
		return $R42::exit_ok;
	}
}

=head2 FUNCTION set_mysqlconfig()

 blabla

=cut
sub set_defaultconf($) {
	my($configfile) = @_;
	if(-f "$configfile" && -r "$configfile") {
		R42::Log::log_message("debug","R42::Mysql::set_defaultconf : Successfully setting New default configuration file $configfile");
		$mysql_default_conf=$configfile;
		return $R42::exit_ok;
	}
	R42::Log::log_message("error","R42::Mysql::set_defaultconf : Error setting new default configuration file $configfile");
	return $R42::exit_error;
}

=head2 FUNCTION get_credentials($host,[$database,[$configfile]])

 Read the default or optional configuration file for a user and pass related to
 a given mysql server and database. If it cannot find a user+pass, this function
 returns an error, else it returns the user and pass found.

 The configuration file is in .ini format

 [host/database]
 user=<user>
 password=<pass>

 [host]
 user=<user>
 password=<pass>

 [default]
 user=<user>
 password=<pass>

=cut

sub get_credentials($;$$) {
	my ($config_file,$host,$database);

	$host="";
	$database="";
	$config_file="";

	if(@_ eq 3) {
		($host,$database,$config_file) = @_;
	} elsif(@_ eq 2) {
		($host,$database) = @_;
	} elsif(@_ eq 1) {
		($host) = @_;
	} else {
		R42::Log::log_message("error","R42::Mysql::get_credentials : not correct number of parameter");
		return $R42::exit_error;
	}
	my ($user,$password);
	if($config_file eq "" && $mysql_default_conf) {
		$config_file=$mysql_default_conf;
	}
	if(! -f $config_file) {
		R42::Log::log_message("error","R42::Mysql::get_credentials : Configuration file $config_file doesn't exist");
		return $R42::exit_error;
	}
	if(! -r $config_file) {
		R42::Log::log_message("error","R42::Mysql::get_credentials : Configuration file $config_file is not readable");
		return $R42::exit_error;
	}
	read_config $config_file => my %config;

	if($database ne "" && ($config{$host."/".$database}{user} || $config{$host."/".$database}{password})) {
		R42::Log::log_message("debug","R42::Mysql::get_credentials: We are using ".$host."/".$database." section");
		if(!$config{$host."/".$database}{user}) {
			R42::Log::log_message("error","R42::Mysql::get_credentials: ".$host."/".$database." section doesn't have user definition");
			$user = undef;
		} else {
			$user=$config{$host."/".$database}{user}
		}
		if(!$config{$host."/".$database}{password}) {
			R42::Log::log_message("error","R42::Mysql::get_credentials: ".$host."/".$database." section doesn't have password definition");
			$password = undef;
		} else {
			$password=$config{$host."/".$database}{password}
		}
	} elsif($config{$host}{user} || $config{$host}{password}) {
		R42::Log::log_message("debug","R42::Mysql::get_credentials: We are using ".$host." section");
		if(!$config{$host}{user}) {
			R42::Log::log_message("error","R42::Mysql::get_credentials: ".$host." section doesn't have user definition");
			$user = undef;
		} else {
			$user=$config{$host}{user}
		}
		if(!$config{$host}{password}) {
			R42::Log::log_message("error","R42::Mysql::get_credentials: ".$host." section doesn't have password definition");
			$password = undef;
		} else {
			$password=$config{$host}{password}
		}
	} elsif($config{default}{user} || $config{default}{password}) {
		R42::Log::log_message("debug","R42::Mysql::get_credentials: We are using default section");
		if(!$config{default}{user}) {
			R42::Log::log_message("error","R42::Mysql::get_credentials: Default section doesn't have user definition");
			$user = undef;
		} else {
			$user=$config{default}{user}
		}
		if(!$config{default}{password}) {
			R42::Log::log_message("error","R42::Mysql::get_credentials: Default section doesn't have password definition");
			$password = undef;
		} else {
			$password=$config{default}{password}
		}
	} else {
		R42::Log::log_message("error","R42::Mysql::get_credentials: No usable information found");
		$user = undef;
		$password = undef;
	}
	if(!$user || !$password) {
		return (undef,undef);
	} else {
		return($user,$password);
	}
	
}

=head2 FUNCTION dbconnect($host,$database,[$config_file]);

        Se connecte � la BDD donn�e en param�tre et renvoie le handler de la connexion
        Par d�faut se connecte � la database "cotations" avec le user "dbuser"
        En cas de probl�me de connection, renvoie "undef"

=cut

# Connection BDD : dbconnect($host,$database,[$config_file]);
sub connect($;$$) {
	my ($config_file,$host,$database,$user,$password);

	$host="";
	$database="";
	$config_file="";

	if(@_ eq 3) {
		($host,$database,$config_file) = @_;
		($user,$password)=get_credentials($host,$database,$config_file);
	} elsif(@_ eq 2) {
		($host,$database) = @_;
		($user,$password)=get_credentials($host,$database);
	} elsif(@_ eq 1) {
		($host) = @_;
		($user,$password)=get_credentials($host);
	} else {
		R42::Log::log_message("error","R42::Mysql::connect : not correct number of parameter");
		return $R42::exit_error;
	}

	if(!$user && !$password) {
		R42::Log::log_message("error","R42::Mysql::connect: unable to get user and password");
		return $R42::exit_error;
	}
	my $counter = 0;
	my $source;
	my $d;

	$source = "dbi:mysql:$database;host=";

	R42::Log::log_message("debug","R42::Mysql::connect: Connexion a (host)'$host', (database)'$database', (user)'$user'");

	while ($counter < 5) {
		$d = DBI->connect($source.$host,$user,$password);
		$counter++;
		if (!$d) {
			R42::Log::log_message("error","R42::Mysql::connect: Try $counter/5, unable to connect to database : $DBI::errstr");
		} else {
			last;
		}
	}
	return $d;
}



=head2 FUNCTION select($dbh, $requete, [ $format ] )

 	Ex�cute la requ�te $requete sur le handler mysql $dbh et renvoie la liste des r�sultat en return_code au format $format.
	$format peut �tre soit "array", soit "hash", par d�faut, c'est "array".

	Le return_code dans le cas du format array est de la forme :

	@array = (
		   [
		     '1',
		     'Debian',
		     '4.0',
		     'i386',
		     '10.30.2.9'
		   ],
		   [
		     '2',
		     'Debian',
		     '4.0',
		     'amd64',
		     '10.30.2.11'
		   ]
		 );

	Pour traiter cette liste donn�e en return_code :
	for my $i (0 .. scalar(@result) - 1) {
		print "Champs 1 $result[$i][0]\n";
		print "Champs 2 $result[$i][1]\n";
		print "Champs 3 $result[$i][2]\n";
		# ...
	}

	Et le return_code dans le cas du format hash est de la forme :

	@hash = (
		  {
		    'distrib_archi' => 'i386',
		    'distrib_name' => 'Debian',
		    'ip' => '10.30.2.9',
		    'distrib_version' => '4.0',
		    'distrib_id' => '1'
		  },
		  {
		    'distrib_archi' => 'amd64',
		    'distrib_name' => 'Debian',
		    'ip' => '10.30.2.11',
		    'distrib_version' => '4.0',
		    'distrib_id' => '2'
		  }
		);

	Pour traiter cette liste donn�e en return_code :
	for my $i (0 .. scalar(@result) - 1) {
		print "Champs 1 $result[$i]{libelle_champs_1}\n";
		print "Champs 2 $result[$i]{libelle_champs_2}\n";
		print "Champs 3 $result[$i]{libelle_champs_3}\n";
		# ...
	}

	Et le return_code dans le cas du format pointer est :

	@array = ( $sth )

	En cas de probl�me, return_codene 'undef', sinon return_codene le tableau des r�sultats au format souhait�

=cut

sub select($$;$) {
	my ($dbh, $r, $format) = @_;
	my ($sth,$rv);
	my $row;
	my @result;

	$format = "array" if (! $format);

	R42::Log::log_message("debug","R42::Mysql::select: MYSQL SELECT : $r");
	$sth = $dbh->prepare($r);
	if(!$sth) {
		R42::Log::log_message("error","R42::Mysql::select: Error while preparing query $r : ".$sth->errstr);
		return undef;
	}
	$rv = $sth->execute();
	if(! $rv) {
		R42::Log::log_message("error","R42::Mysql::select: Error while executing query $r : ".$sth->errstr);
		return undef;
	}
	if($format eq "array") {
		while($row=$sth->fetchrow_arrayref) {
			push @result, [ @$row ];
		}
	} elsif($format eq "hash") {
		while($row=$sth->fetchrow_hashref) {
			push @result, { %$row };
		}
	} elsif($format eq "pointer") {
		push @result, $sth;
	} else {
		R42::Log::log_message("error","R42::Mysql::select: Format must be one of 'array', 'hash' or 'pointer'");
		return undef;
	}
	if($sth->err) {
		R42::Log::log_message("error","R42::Mysql::select: Error not catched before for query $r : ".$DBI::errstr);
		return undef;
	}
	return @result;
}

=head2 FUNCTION do($dbh, $requete[, 1])

	Ex�cute la requ�te sur le handler mysql $dbh et renvoie le nombre de lignes affect�es en return_code
	Si le 3�me param�tre (optionnel) est � 1, on ignore le mode de test (variable test_mode)
	Si une erreur est survenue : renvoie -2
	Si un nombre de lignes n'est pas applicable � la requ�te : renvoie -1

=cut

# Fonction de modif mysql : do($dbh, "ma requ�te", notest?)
# renvoie le nombre de lignes modifi�es :
# 	- si nb_lignes = -1 : le nombre de lignes n'est pas applicable � la requ�te
# 	- si nb_lignes = -2 : erreur dans la requ�te
sub do($$;$) {
	my ($dbh, $r, $notest) = @_;
	my ($sth, $nb_rows);
	my $return_code = 0;
	my $test_str = "";
	my $nb_retry = 15;

	$test_str = "[TEST : Not really executed] " if ($test_mode && !$notest);
	R42::Log::log_message("debug","R42::Mysql::do: $test_str$r");

	if (! $test_mode || $notest) {
		$sth = $dbh->do($r) or $return_code = -2;
		if ($return_code == -2) {
			R42::Log::log_message("error","R42::Mysql::do: Error during query $r : ".$dbh->err.", ".$dbh->errstr);

			# In case of deadlock or lock_wait, we will retry $nb_deadlock_restart_transaction
			while (($dbh->err == 1213 || $dbh->err == 1205) && $nb_retry != 0) {
				$nb_retry--;
				R42::Log::log_message("info","R42::Mysql::do: retry, $nb_retry more to come");
				$sth = $dbh->do($r);
				if (!$sth) {
					R42::Log::log_message("error","R42::Mysql::do: Error during query $r : ".$dbh->err.", ".$dbh->errstr);
				} else {
					R42::Log::log_message("info","R42::Mysql::do: Query executed successfully");
					$return_code = $sth;
					last;
				}
			}
		} else {
			$return_code = $sth;
		}
	}
	return $return_code;
}

=head2 FUNCTION disconnect($dbh);

	Disconnect and free ressources

=cut

sub disconnect($) {
	my ($dbh) = @_;
	$dbh->disconnect();
	return 0;
}

=head1 EXAMPLES

=head2 BLABLA

 blabla

=cut

1;

