#!/bin/bash
 
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
version 0.6
Options non obligatoire :
        -h | --help :           Affiche cette ecran d aide
        -d | --debug            Mode debug
 
Obsolete:
        -w | --warning :        Seuil du warning centreon
        -c | --critical :       Seuil du critical centreon
 
Fonctions:
        -f | --fonction :       Nom de la fonction a utiliser
        -b | --bonding          Specifier la liste de bonding a prendre en charge.
                        Par defaut tous les bondings sont prise en compte
 
Liste des fonctions :
        bonding                 permets de valider le bonding
 
 
 
Examples:
checker tous les bond de la machine
  $APPNAME  --fonction bonding
 
ne verifier qu'un seul bond
  $APPNAME  --fonction bonding --bonding bond0
 
specifier la liste des bond a verifier
  $APPNAME  --fonction bonding -b "bond0 bond1"
---------------------------------------------------------------------
EOU
exit 3
}
 
if [ $# == 0 ]; then usage ;fi
 
# -o option coute - le caractere ":" indique une attente de parametre
# -l option longue
ARGS=`getopt -o "dhb:f:w:c:" -l "debug,help,bonding,fonction:,warning:,critical:" \
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
 
                        -b|--bonding )
                        MY_BOND_LIST=$2
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
else RETURN=3
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
        echo $LABEL_CODE_UNKNOWN
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
 
# commands
CAT=/bin/cat
GREP=/bin/grep
EGREP=/bin/egrep
AWK=/usr/bin/gawk
FIND=/usr/bin/find
SED=/bin/sed
WC=/usr/bin/wc
TAIL=/usr/bin/tail
ECHO=/bin/echo
LS=/bin/ls
TR=/usr/bin/tr
 
BONDING_LIST_DIR="/proc/net/bonding"
 
 
 
##################################
## LISTES DES FONCTIONS
##################################
function get_bonding() {
 
# nombre de bonding present sur la machine
BONDTMP=$($LS $BONDING_LIST_DIR)
 
 
# verification de la liste fournie en entree
if [[ $MY_BOND_LIST ]]
then
BONDTMP=""
cd $BONDING_LIST_DIR
        for i in $MY_BOND_LIST
        do
                BONDTMP=$($ECHO "$BONDTMP" `$LS ${i}`)
        done
fi
 
 
# verif si il existe au moins un bonding
COUNTBONDS=`$ECHO $BONDTMP | $WC -l`
 
if [[ "$COUNTBONDS" -lt 1 ]]
        then
                LABEL_CODE_UNKNOWN="Aucun bonding detecte"
                exit_return
fi
 
 
 
 
 
# verification du statut
for BONDTRUE in $($ECHO "$BONDTMP");
do
        if [[ "$BONDTRUE" ]]
        then
            BONDMODE=`$CAT $BONDING_LIST_DIR/$BONDTRUE |$GREP "Bonding Mode"|$AWK {'print $3$4$5'}`
            ETHLIST=$($CAT  $BONDING_LIST_DIR/$BONDTRUE |$GREP eth|$AWK {'print $3'}|$EGREP -v "Slave|Master|Interface|Active")
            for list in $($ECHO $ETHLIST)
                do
                        ETHS=$($CAT $BONDING_LIST_DIR/$BONDTRUE | $GREP -A 1 "$list" | $AWK {'print $3'}|$SED 's/Slave/Bond/' | $TR "\n" " ")
                        STATE=$(echo "$STATE - $ETHS" )
                done
        STATECOUNT=$( echo $STATE | tr -s ' ' '\n' | grep up | wc -l )
        if [[ "$STATECOUNT" -lt 3 ]] ; then
                LABEL_OUT_ERR=$($ECHO -n ${LABEL_OUT_ERR} "CRITICAL: $BONDTRUE" $COMA)
                CHECK_CRIT=1
                STATE=
        else
                LABEL_OUT_OK=$($ECHO -n ${LABEL_OUT_ERR} "OK - $BONDTRUE: Mode: $BONDMODE." $COMA)
                CHECK_OK=1
                STATE=
        fi
 
        fi
 
done
exit_return
 
}
 
 
 
##########################################################
# lancement de la fonction via le parametre -f
##########################################################
case $FUNCTION in
                bonding ) get_bonding ;;
 
esac
