distributed-trunk-agi
=====================

Astetisk AGI to distribute calls in a smart way through several "unlimited" trunks. Simple integration with Freebx.

Pas toujours evident de trouver des idees de tutorial "utiles" et en meme temps ni trop simples , ni trop complexes.
Le but ici est de décrire une intégration complète d'un AGI un peu "intelligent" avec Freepbx mais ca ne reste qu'un bout de dialplan intégrable avec d'autres solutions comme xivo par exemple.

Il y a quelques temps, on avait décrit la manière d'alterner différents trunks pour une meme destination. Cela peut etre utile pour ceux disposant de plusieurs lignes avec un certain quota pour utilser au mieux leur forfait.
L'approche LCR ( least cost routing ) n'est pas suffisante pour ces cas ou 2 fournisseurs ont des couts identiques. De plus, les forfaits "illimité" sont apparus. Illimité mais pas sans limite...L'illimité n'est valide que pour un certains nombre de numéros.

Imaginons donc le cas ou on désire gérer au mieux ce type de fournisseurs. Les besoins sont assez simples en fait:
	- Il faut essayer d'utiliser toujours la meme ligne illimité pour un meme numéro appelé.
	- If faut répartir les appels sortants sur les lignes "illimitées' disponibles afin d'optimiser les usages.
	
Avec 10 lignes à 100 numéros illimités, si on gere tres mal et en fonction de l'usage. On risque tres vite de faire du hors forfait avec pas beaucoup plus de 100 numéros distincts appelés. L'idée est d'optimiser au maximum et automatiquement pour atteindre les 1000 numeros illimités possible sans aucun hors forfait ( depassement de 100 numeros sur une ligne "illimité" )


Je joins un agi "exemple" pour optimiser n lignes limité à 100 numeros tels que les lignes chez OVH par exemple. Cela pourrait etre utiliser egameùent avec des gateways de mobiles ou les operateurs ont le meme type de limitation pour l'illimité.

J'ai essayé de commenter le code de l'agi en perl qui initialement était fait pour du LCR classique.

Les étapes de l'intégration sont les suivantes:
1- Copie du contexte [ovh-versfixes-trunks] dans le fichier de conf ( extension_custom.conf pour freepbx ).
2- Création d'une table mysql qui stockera les données necessaires. On pourra utiliser la base asterisk deja utilisé par freepbx par exemple.

Voici le sql à exécuter:
CREATE TABLE IF NOT EXISTS `ovhcalls` (
  `number` bigint(20) unsigned NOT NULL,
  `trunk` int(10) unsigned NOT NULL,
  `lastchanged` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
  PRIMARY KEY  (`number`,`trunk`),
  UNIQUE KEY `numero` (`number`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

On stocke juste l'association numéro/ligne avec un petit timestamp.

3- mettre a jour dans le script nom de la base/user/password pour l'accés avec vos valeurs.
my $db_base="asteriskcdrdb";
my $db_login="asteriskuser";
my $db_password="????";

4- donner/indiquer au scripts les numeros de trunks qu'il doit utiliser pour le dial. Les trunks seront juste l'id dans freepbx pour une intégration facile.

5- Créer un custom trunk qui pourra etre utiliser dans le gui de Freepbx pour les outbounds routes. Le custom trunk aura cette définition: local/$OUTNUM$@ovh-versfixes-trunks
Voir le précédent article sur les customs trunks avec Freepbx.

Dorenavant, chaque appel utilisant ce custom trunk "intelligent" utilisera automatiquement la meme ligne que precedemment. Le script veillera en meme temps a ce que toutes les lignes "illimités" soient uniformement utilisées pour eviter tout hors forfait sur une ligne en particulier. Tout est resetté tous les mois, il n'y a donc pas de maintenance particulière à faire.

Ce script est utilisé en prod depuis de nombreuses années. Il est fonctionnel mais il necessite d'avoir quelques connaissances pour son installation. ;-)

Bon tests.
Francois.

