=head1 Name

 Ssh.pm - Fonctions sur SSH

=head1 SYNOPSYS
 
 blabla

=head1 DESCRIPTION

 blabla

=cut

package R42::Ssh;

use strict;
use Net::SSH;

use R42::Log;

=head1 CONSTANTES

 blabla

=cut

=head1 VARIABLES

 blabla

=cut

=head1 FONCTIONS

=cut

=head2 FUNCTION run_cmd_on_machine($ip, $user, $cmd)

 Execute une commande sur une machine distante en utilisant SSH

=cut

sub run_cmd_on_machine
{
    my ($ip, $user, $cmd) = @_;
    my $retour = 0;
    
    Net::SSH::sshopen2("$user\@$ip", *READER, *WRITER, "$cmd") or $retour = $!;
    
    if($retour != 0) {
	R42::Log::log_message("error","R42::Ssh::run_cmd_on_machine: Connexion SSH � $ip avec l'utilisateur $user impossible : $retour");
	return undef;
    } else {
	R42::Log::log_message("debug","R42::Ssh::run_cmd_on_machine: Connexion SSH � $ip avec l'utilisateur $user reussie");
    }
    
     $retour = "";
    while(<READER>) {
	$retour .= $_;
    }
    close(READER);
    close(WRITER);
    
    chomp($retour);
    return $retour;
}

1;
