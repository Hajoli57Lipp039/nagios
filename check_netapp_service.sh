#!/bin/bash
###################################################################
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
#    For information : stephane.mouchon@laposte.net
#    Created : 01/dec/2012
#    version 0.3
###################################################################

RETURN=0
APPNAME=$(basename $0)

debug() {
set -x
#set -xv
}

#HELP:
usage () {
cat<<EOU
---------------------------------------------------------------------
Usage of $APPNAME
---------------------------------------------------------------------
Options non obligatoire :
	-h | --help : 		Affiche cet ecran d aide
	-d | --debug		Mode debug
	
Options obligatoire (avec parametre):
	-v | --version :	Version de snmp (disponible : 1-2c)
	-C | --communaute :	Communaute snmp
	-H | --host :	 	nom de la machine 
	-w | --warning : 	Seuil du warning centreon 
	-c | --critical : 	Seuil du critical centreon 

Fonctions:
	-f | --fonction : 	Nom de la fonction a utiliser 
	
Liste des fonctions :
	snapmirror_lag 		(seuil conseille 2 heures)
	snapvault_lag 		(seuil conseille 8 jours = 192H)
	sis_lag 			(peut varier)
	snapmirror_statut  	(pas de seuil)
	snapvault_statut	(pas de seuil)
	vfiler_statut		(pas de seuil)
	ndmp_statut			(pas de seuil)
	cifs_statut			(pas de seuil)
	cf_statut			(pas de seuil)
	
	
Examples:
  $APPNAME -v 2c -C public -H netapp_appliance_name --fonction snapmirror_lag -w 1 -c 3
  $APPNAME -v 2c -C public -H netapp_appliance_name --fonction snapvault_statut 
---------------------------------------------------------------------
EOU
exit 3
}

if [ $# == 0 ]; then usage ;fi

# -o option coute - le caractere ":" indique une attente de parametre
# -l option longue
ARGS=`getopt -o "dhC:v:H:f:w:c:" -l "debug,help,community:,version:,host:,fonction:,warning:,critical:" \
      -n "getopt.sh" -- "$@"`
if [ $? -ne 0 ]; then exit 1 ;fi

eval set -- "$ARGS"
while true;
do
       case "$1" in
			-h|--help ) 
			usage
			shift ;;

			-d|--debug ) 
			debug
			shift ;;
			
			-C|--community ) 
			COMMUNITY=$2
			shift 2 ;;
			
			-v|--version ) 
			VERSION=$2 
			shift 2 ;;
			
			-H|--host ) 
			HOST=$2 
			shift 2 ;;
			
			-f|--fonction ) 
			FUNCTION=$2
			shift 2 ;;
			
			-w|--warning ) 
			WARNING=$2
			shift 2 ;;
			
			-c|--critical ) 
			CRITICAL=$2

			shift 2 ;;
			
			--)
			shift
			break;;
       esac
done


##########################################################
# Gestion du code retour et du label  
##########################################################
function exit_return() {
#verification du level le plus haut
if   [[ $CHECK_CRIT == 1 ]] ; then RETURN=2
elif [[ $CHECK_WARN == 1 ]] ; then RETURN=1
elif [[ $CHECK_OK == 1 ]] ; then RETURN=0
fi 

case $RETURN in
	0 ) 	
	echo $LABEL_OUT_OK
	exit $EXIT_CODE_OK
	 ;;
	1 ) 
	echo $LABEL_OUT_WARN
	exit $EXIT_CODE_WARN
	 ;;
	2 )
	echo $LABEL_OUT_ERR
	exit $EXIT_CODE_ERR
	 ;;
	* )
	echo "une erreur inconnue s'est produite"
	exit $EXIT_CODE_UNKNOWN
	 ;;
esac

}


##################################
## CONSTANTES 
##################################
EXIT_CODE_OK=0
EXIT_CODE_WARN=1
EXIT_CODE_ERR=2
EXIT_CODE_UNKNOWN=3

LABEL_OUT_UNKNOWN="Il y a une erreur dans l\'execution du script"
COMA="-"
##################################
## LISTES DES FONCTIONS 
##################################
function get_snapmirror_lag() {

OID_LAG=".1.3.6.1.4.1.789.1.9.20.1.6"
OID_NAME=".1.3.6.1.4.1.789.1.9.20.1.2"

i=0
let "CRITICAL *=3600"
let "WARNING *=3600"


SNAPMIRROR_LAG=$(snmpwalk -v $VERSION -c $COMMUNITY $HOST $OID_LAG | cut -d'(' -f 2 | cut -d')' -f1) || exit_return RETURN=${EXIT_CODE_UNKNOWN}
SNAPMIRROR_NAME=$(snmpwalk -v $VERSION -c $COMMUNITY $HOST $OID_NAME | cut -d'.' -f 8- ) || exit_return RETURN=${EXIT_CODE_UNKNOWN}

for LAG in $SNAPMIRROR_LAG
do 
	#modification du format centieme de seconde que fournit la sonde
	let LAG=${LAG}/100
	let STAMP_HEURE=$LAG/3600	
	# l'index commence a 1 egalement dans l OID snmp
	let "i++"
		if [[ $LAG -gt $CRITICAL ]] ; then		
			NAME_SNAPMIRROR=$(echo "$SNAPMIRROR_NAME" | grep -w $i | cut -d' ' -f4-5 ) 
			LABEL_OUT_ERR=$(echo ${LABEL_OUT_ERR} "lag de ${STAMP_HEURE}H sur ${NAME_SNAPMIRROR} $COMA")
			CHECK_CRIT=1
		elif [[ $LAG -gt $WARNING ]] ; then		
			NAME_SNAPMIRROR=$(echo "$SNAPMIRROR_NAME" | grep -w $i | cut -d' ' -f4-5 ) 
			LABEL_OUT_WARN=$(echo ${LABEL_OUT_WARN} "lag de ${STAMP_HEURE}H sur ${NAME_SNAPMIRROR} $COMA")
			CHECK_WARN=1
		else
			LABEL_OUT_OK=$(echo "Tous les snapmirrors sont a jour")
			CHECK_OK=1
		fi

done 
exit_return
}

function get_snapvault_lag() {
# some corrections has been advised by Torsten Eymann (DE). Thanks to him.
OID=".1.3.6.1.4.1.789.1.19.11.1.6"
OID_NAME=".1.3.6.1.4.1.789.1.19.11.1.2"

i=0

let "CRITICAL *=3600"
let "WARNING *=3600"

#SNAPVAULT_LAG=$(snmpwalk -v $VERSION -c $COMMUNITY $HOST $OID | cut -d'(' -f 2 | cut -d')' -f1) || exit_return RETURN=${EXIT_CODE_UNKNOWN}
SNAPVAULT_LAG=$(snmpwalk -v $VERSION -c $COMMUNITY $HOST $OID) || exit_return RETURN=${EXIT_CODE_UNKNOWN}
SNAPVAULT_NAME=$(snmpwalk -v $VERSION -c $COMMUNITY $HOST $OID_NAME | cut -d'.' -f 8- ) || exit_return RETURN=${EXIT_CODE_UNKNOWN}

# use newline instat whitespace as seperator in the for loop

SAVEIFS=$IFS
IFS=$(echo -en "\n\b")

for LAGtor in $SNAPVAULT_LAG
do 
	#modification du format centieme de seconde fournit la sonde
	LAG=$(echo "${LAGtor}"| cut -d'(' -f 2 | cut -d')' -f1 )
	let LAG=${LAG}/100
	let STAMP_HEURE=$LAG/3600	
	# l'index commence a 1 egalement dans l OID snmp
	let "i++"
		if [[ $LAG -gt $CRITICAL ]] ; then
			#recuperation des noms des snapmirrors
			let LAGi=$(echo "${LAGtor}"| cut -d'=' -f1 |cut -d'.' -f 8 )
			NAME_SNAPVAULT=$(echo "$SNAPVAULT_NAME"| grep -w $LAGi | cut -d' ' -f4-5 )
			LABEL_OUT_ERR=$(echo ${LABEL_OUT_ERR} "lag de ${STAMP_HEURE}H sur ${NAME_SNAPVAULT} $COMA")
			CHECK_CRIT=1
		elif [[ $LAG -gt $WARNING ]] ; then
			NAME_SNAPVAULT=$(echo "$SNAPVAULT_NAME"| grep -w $i | cut -d' ' -f4-5 )
			LABEL_OUT_WARN=$(echo ${LABEL_OUT_WARN} "lag de ${STAMP_HEURE}H sur ${NAME_SNAPVAULT} $COMA")
			CHECK_WARN=1
		else
			LABEL_OUT_OK=$(echo "Tous les snapvaults sont a jour")
			CHECK_OK=1
		fi
done 
exit_return
}



function get_sis_lag() {

OID_STATE=".1.3.6.1.4.1.789.1.23.2.1.3"
OID_NAME=".1.3.6.1.4.1.789.1.23.2.1.2"
OID_SISPROGRESS=".1.3.6.1.4.1.789.1.23.2.1.5"
i=0


ACTIF=$(snmpwalk -v $VERSION -c $COMMUNITY $HOST $OID_STATE | cut -d'.' -f 8- | grep  ": 2" | awk '{print $1}' | tr -s '\n' '|' |  sed 's/|$/ /' ) || exit_return RETURN=${EXIT_CODE_UNKNOWN}
SISPROGRESS=$(snmpwalk -v $VERSION -c $COMMUNITY $HOST $OID_SISPROGRESS | cut -d'.' -f 8- | egrep -w "$ACTIF" |  cut -d' ' -f6 | cut -d':' -f1  | tr -s '"' ' ') || exit_return RETURN=${EXIT_CODE_UNKNOWN}
NAME_SOURCE=$(snmpwalk -v $VERSION -c $COMMUNITY $HOST $OID_NAME | cut -d'.' -f 8- )	|| exit_return RETURN=${EXIT_CODE_UNKNOWN}


for STAMP in $SISPROGRESS
do 
	let "i++"	
	j=$( echo $ACTIF | cut -d'|' -f $i )		
		if [[ $STAMP -gt $CRITICAL ]] ;	then
			NAME=$(echo "$NAME_SOURCE" | /bin/grep -w ${j} | cut -d'"' -f2 )
			LABEL_OUT_ERR=$(echo ${LABEL_OUT_ERR} "lag de ${STAMP}H sur ${NAME} $COMA")
			CHECK_CRIT=1
		elif [[ $STAMP -gt $WARNING ]] ; then
			NAME=$(echo "$NAME_SOURCE" | /bin/grep -w ${j} | cut -d'"' -f2 )
			LABEL_OUT_WARN=$(echo ${LABEL_OUT_WARN} "lag de ${STAMP}H sur ${NAME} $COMA")
			CHECK_WARN=1
		else
			LABEL_OUT_OK=$(echo "Toutes les dedup sont a jour")
			CHECK_OK=1
		fi

done 
exit_return
}




function get_snapvault_statut() {

OID_STATE=".1.3.6.1.4.1.789.1.19.1"

STATUT=$(snmpwalk -v $VERSION -c $COMMUNITY $HOST $OID_STATE  | awk '{print $4}') || exit_return RETURN=${EXIT_CODE_UNKNOWN}
if [[ $STATUT -eq 2 ]] ;
then 
LABEL_OUT_OK="le service snapvault est actif"
elif [[ $STATUT != 2 ]] ; then
LABEL_OUT_ERR="Le service snapvault est inactif"
RETURN=2		
fi
exit_return
}


function get_snapmirror_statut() {

OID_STATE=".1.3.6.1.4.1.789.1.9.1"

STATUT=$(snmpwalk -v $VERSION -c $COMMUNITY $HOST $OID_STATE  | awk '{print $4}') || exit_return RETURN=${EXIT_CODE_UNKNOWN}

if [[ $STATUT == 2 ]] ;then 
LABEL_OUT_OK="le service snapmirror est actif"
elif [[ $STATUT != 2 ]] ; then
LABEL_OUT_ERR="Le service snapmirror est inactif"
RETURN=2		
fi
exit_return
}


function get_ndmp_statut() {

OID_STATE=".1.3.6.1.4.1.789.1.10.1"

STATUT=$(snmpwalk -v $VERSION -c $COMMUNITY $HOST $OID_STATE  | awk '{print $4}') || exit_return RETURN=${EXIT_CODE_UNKNOWN}

if [[ $STATUT == 2 ]] ;then 
LABEL_OUT_OK="le service ndmp est actif"
elif [[ $STATUT != 2 ]] ; then
LABEL_OUT_ERR="Le service ndmp est inactif"
RETURN=2		
fi
exit_return
}


function get_cifs_statut() {

OID_STATE=".1.3.6.1.4.1.789.1.7.1.1"

STATUT=$(snmpwalk -v $VERSION -c $COMMUNITY $HOST $OID_STATE  | awk '{print $4}') || exit_return RETURN=${EXIT_CODE_UNKNOWN}

if [[ $STATUT == 2 ]] ; then 
LABEL_OUT_OK="le service cifs est actif"
elif [[ $STATUT != 2 ]] ; then
LABEL_OUT_ERR="Le service cifs est inactif"
RETURN=2		
fi
exit_return
}


function get_cf_statut() {

OID_STATE=".1.3.6.1.4.1.789.1.2.3.2"

STATUT=$(snmpwalk -v $VERSION -c $COMMUNITY $HOST $OID_STATE  | awk '{print $4}') || exit_return RETURN=${EXIT_CODE_UNKNOWN}

if [[ $STATUT == 2 ]] ; then 
LABEL_OUT_OK="le service cf est en etat OK"

elif [[ $STATUT != 2 ]] ; then
LABEL_OUT_ERR="Le takeOver est active "
RETURN=2		
fi
exit_return
}




function get_vfiler_statut() {

OID_STATE=".1.3.6.1.4.1.789.1.16.3.1.9"
OID_NAME=".1.3.6.1.4.1.789.1.16.3.1.2"
i=0

STATUT=$(snmpwalk -v $VERSION -c $COMMUNITY $HOST $OID_STATE  | awk '{print $4}') || exit_return RETURN=${EXIT_CODE_UNKNOWN}
FILER_NAME=$(snmpwalk -v $VERSION -c $COMMUNITY $HOST $OID_NAME | cut -d'.' -f 8- )	|| exit_return RETURN=${EXIT_CODE_UNKNOWN}

for VFILER in $STATUT
do 
	let "i++"
	if [[ $VFILER != 2 ]] ; then
		NAME=$(echo "$FILER_NAME"| /bin/grep  ${i} | cut -d'"' -f2 )	
		LABEL_OUT_ERR=$(echo ${LABEL_OUT_ERR} "Le VFILER ${NAME} est arrete $COMA")
		RETURN=2		
	fi
		
LABEL_OUT_OK=$(echo "Tous les VFILER sont actifs")
done 

exit_return
}








##########################################################
# lancement de la fonction via le parametre -f
##########################################################
case $FUNCTION in
		snapmirror_lag ) get_snapmirror_lag ;;
		snapvault_lag ) get_snapvault_lag ;;
		sis_lag ) get_sis_lag ;;
		snapmirror_statut ) get_snapmirror_statut ;;
		snapvault_statut ) get_snapvault_statut ;;
		vfiler_statut ) get_vfiler_statut ;;
		ndmp_statut ) get_ndmp_statut ;;
		cifs_statut ) get_cifs_statut ;;
		cf_statut ) get_cf_statut ;;
		
esac
