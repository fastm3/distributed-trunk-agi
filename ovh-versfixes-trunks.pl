#!/usr/bin/perl -w
#!/usr/bin/perl

# Script distribution des ovh trunks
# > repartition des appels sur tous les trunks
# > appel d'un numero toujours sur le meme trunk

# à utiliser avec freebpx
# copyright 2009 infimo sarl 
#
#  Usage:
#
# > rajouter dans [from-internal-custom] 
# include => ovh-versfixes-trunks 
# ou mieux declarer custom trunk as Local/$OUTNUM$@ovh-versfixes-trunks
# on remplacera le pattern par _X. 

# [ovh-versfixes-trunks]
# ; distributions des trunks ovh pour les fixes
# ; en tenant comptes de la limite de 99 numeros par trunks
# exten => _0[1234579]XXXXXXXX,1,AGI(ovh-versfixes-trunks.pl,${EXTEN})
# exten => _0[1234579]XXXXXXXX,n,ResetCDR()
# exten => _0[1234579]XXXXXXXX,n,Set(CDR(userfield)=${OUT_${OVH1}})
# exten => _0[1234579]XXXXXXXX,n,Macro(dialout-trunk,${OVH1},${EXTEN},,)
# exten => _0[1234579]XXXXXXXX,n,Macro(dialout-trunk,${OVH2},${EXTEN},,)
# exten => _0[1234579]XXXXXXXX,n,Macro(dialout-trunk,${OVH3},${EXTEN},,)
# exten => _0[1234579]XXXXXXXX,n,Macro(outisbusy,)
#
#
#Creation de la table dans asteriskcdrdb
#
#CREATE TABLE IF NOT EXISTS `ovhcalls` (
#  `number` bigint(20) unsigned NOT NULL,
#  `trunk` int(10) unsigned NOT NULL,
#  `lastchanged` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
#  PRIMARY KEY  (`number`,`trunk`),
#  UNIQUE KEY `numero` (`number`)
#) ENGINE=InnoDB DEFAULT CHARSET=latin1;
#


use strict;
#use warnings;
#use diagnostics;


use Asterisk::AGI;
use Data::Dump 'dump';

# les trunks ovh a utiliser sont les trunks 1,2,3
# recuperer les id dans l'interface , section trunks (si url finie par OUT_4 , l'id est 4) 
# ou en debut de extensions_additional.conf: OUT_1 -> 1
my @OVHDEFINEDTRUNKS = (1,2,3);
my $DEBUG=1;


# sql support
use DBI;

my $db_host="localhost";
# TODO: read value in cdr_mysql.conf
my $db_base="asteriskcdrdb";
my $db_login="asteriskuser";
my $db_password="infimo";
my $starttime = (times)[0];

### FUNCS
sub get_ovh_trunks ($)
{
	my ($number) = @_;
	my $trunk = $OVHDEFINEDTRUNKS[0];
	my $requete;
	my $sth;
	######################################################
	# Connection à la base mysql
	######################################################
	my $dbh = DBI->connect("DBI:mysql:$db_base;$db_host","$db_login","$db_password") or	die "Echec connexion";

	######################################################
	# effacement données mois precedent
	######################################################
	$requete = "DELETE from ovhcalls where lastchanged < concat(date_format(LAST_DAY(now()),'%Y-%m-'),'01')";
	$sth = $dbh->prepare($requete);
	$sth->execute();
	$sth->finish;


	
	######################################################
	# par defaut recuperation dest trunks les moins utilisés dans l'ordre.
	######################################################
	my @besttrunks=();
	$requete = "SELECT trunk, count(number) as mycount FROM ovhcalls group by trunk order by mycount ";
	my $array_ref = $dbh->selectcol_arrayref($requete);
	print STDERR "best trunks\n";
	dump($array_ref);
	if ( scalar @$array_ref < scalar  @OVHDEFINEDTRUNKS   )
	{
		@besttrunks = @$array_ref;
		# on complete par les trunks pas encore utilises
		foreach my $ovhtrunk (@OVHDEFINEDTRUNKS)
		{
				# si pas dans le tableau , on l'ajoute en tete pour qu'il soit utilisé de preference
				if ( ! grep { $ovhtrunk eq $_ } @besttrunks) 
				{
					unshift(@besttrunks, $ovhtrunk);
				}
		} 	
	}	
	else
	{
		@besttrunks = @$array_ref;
	}	
	print STDERR "best trunks\n";
	dump(@besttrunks);
	
	######################################################
	# recup du trunk ( ou des !! ) deja selectionné
	###################################################### 
	$requete = "SELECT trunk FROM ovhcalls WHERE number=" . $number;
	print STDERR "requete:$requete\n";
	$array_ref = $dbh->selectcol_arrayref($requete);
	print STDERR "trunks for $number\n";
	dump($array_ref);
	if( $array_ref )
	{
		foreach my $alreadyusedtrunk (@$array_ref)
		{
			print STDERR "numéro deja attribué à $alreadyusedtrunk\n";
			### Le trunk deja attribué est mis en tete pour beneficier de l'illimité
			# 1 on enleve trunk
			@besttrunks = grep { $_ != $alreadyusedtrunk } @besttrunks;
			# 2 on rajoute trunk en tete
			unshift(@besttrunks, $alreadyusedtrunk);
		}
	}
	else
	{
		# numero pas encore attribué -> c'est le trunk le moins utilisé qui sera choisi
		print STDERR "nouveau numéro $number\n";
	}

	######################################################
	#save assigned trunk
	######################################################
	$trunk=$besttrunks[0];
	$requete = "REPLACE  ovhcalls SET number = $number,  trunk = $trunk";
	print STDERR "requete:$requete\n";
	$sth = $dbh->prepare($requete);
	$sth->execute();
	$sth->finish;
	$dbh->disconnect;

	print STDERR "resultat:\n";
	dump(@besttrunks);	
	return @besttrunks;
}



### MAIN		
my $number;
my @ovhtrunks;									
if (@ARGV > 0 and lc($ARGV[0]) eq 'test') 
{ 
		# test from the command line
		$number = $ARGV[1];
		#recupere les trunks ovh a utiliser classé par ordre de préférence
		@ovhtrunks = get_ovh_trunks($number);
		my $duration = ((times)[0]-$starttime);
		warn sprintf("trunks ovh determiné en %.4f secondes", $duration) if $DEBUG;

} 
else 
{
	#that should be the case when it is called from asterisk
	my $AGI = new Asterisk::AGI;
	#parse info from asterisk
	my %input = $AGI->ReadParse();
	my $myself = $input{request};
	#get current local time
	my @localtime = localtime(time());
	my ($day, $hour) = (($localtime[6] - 1) % 7, $localtime[2]);
	#get number
	$number = $ARGV[0];
	
	#recupere les trunks ovh a utiliser classés par ordre de préférence
	@ovhtrunks = get_ovh_trunks($number);
	#put out some info and select provider
	my $duration = ((times)[0]-$starttime);
	warn sprintf("$myself: trunks ovh determiné en %.4f secondes", $duration) if $DEBUG;
	
	
	if (@ovhtrunks) 
	{
		if ($DEBUG) 
		{
			#put out list of available providers sorted by rate
			warn "$myself: Ordre des trunks pour $number:";
			foreach my $trunkovh (@ovhtrunks) 
			{
				warn "$myself: OUT_$trunkovh";
			}
		}
	} 
	else 
	{
		die "$myself: Erreur critique, pas de trunks" if $DEBUG;
	}
	
	# on sette ovh1,ovh2....

	my $count=0;
	foreach my $trunkovh (@ovhtrunks) 
	{
		$count++;
		$AGI->set_variable("OVH$count",$trunkovh);
		$AGI->noop("Setting OVH$count to $trunkovh");
	}

}
