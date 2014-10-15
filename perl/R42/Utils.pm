# $Id: Utils.pm,v 1.4 2008-11-12 15:22:49 dsacchet Exp $

=head1 Name

 Utils.pm - Quelques fonctions utiles

=head1 SYNOPSYS
 
 blabla

=head1 DESCRIPTION

 blabla

=cut

package R42::Utils;
use strict;
use R42;


=head1 VARIABLES

 blabla

=cut

our %benchmarks;

=head1 FONCTIONS

=cut

=head2 FUNCTION benchmark_start($id)

 Cette fonction initialise une variable globale avec la date courante
 Il est possible d'avoir plusieurs compteurs en spécifiant un id
 différent

=cut

sub benchmark_start($) {
	my ($id) = @_;
	$R42::Utils::benchmarks{$id} = time();
}


=head2 FUNCTION benchmark_tick($id)

 Cette fonction retourne le temps écoulé depuis le dernier appel à la fonction
 benchmark_start

=cut

sub benchmark_tick($) {
	my ($id) = @_;
	if($R42::Utils::benchmarks{$id}) {
		return time()-$R42::Utils::benchmarks{$id};
	} else {
		return 0;
	}
}


1;
