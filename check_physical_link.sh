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
        -I | --interface        Nom de l interface a verifier
        -N | --negocation       Vitesse de la negication attendue
                        Par defaut tous les bondings sont prise en compte


Liste des fonctions :
        network                 permets de valider la negociation et letat du link


Examples:
  $APPNAME  --fonction network -I eth0 -N 10000
  $APPNAME  --fonction network -I "eth0 eth1" -N 10000

*Si l'on ne place pas l'option Interface, le script va prendre toutes les interfaces presentent sur la machine.
  $APPNAME  --fonction network  -N 10000
---------------------------------------------------------------------
EOU
exit 3
}

if [ $# == 0 ]; then usage ;fi

# -o option coute - le caractere ":" indique une attente de parametre
# -l option longue
ARGS=`getopt -o "dhf:w:c:I:N:" -l "debug,help,network,fonction:,interface:,negociation:" \
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

                        -f|--fonction )
                        FUNCTION=$2
                        shift 2 ;;

                        -I|--interface )
                        INTERFACE=$2
                        shift 2 ;;

                        -N|--negociation )
                        NEGOCIATION=$2

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


INTERFACE_DIR="/sys/class/net"



##################################
## LISTES DES FONCTIONS
##################################
function get_network() {

#liste des interfaces eth
ETHTMP=$(ls -d ${INTERFACE_DIR}/eth*)


# verification de la liste fournie en entree
if [[ $INTERFACE ]]
then
ETHTMP=""
        for i in $INTERFACE
        do
                ETHTMP=$(echo "$ETHTMP" `ls -d ${INTERFACE_DIR}/${i}`)
        done
fi


# verif si il existe au moins une interface reseau
COUNTETH=`echo $ETHTMP | wc -w`

if [[ "$COUNTETH" -lt 1 ]]
        then
                LABEL_CODE_UNKNOWN="Aucune interface detecte"
                exit_return
fi


# verification du statut
for ETHTRUE in $(echo "$ETHTMP");
do
        if [[ "$ETHTRUE" ]]
        then

        BASENAME_ETH=$(basename $ETHTRUE)

        #version fichier
        #SPEED=$(dmesg | grep BASEBAME_ETH | grep Up  | tail -1 | cut -d'U' -f2 | awk {'print $2'})
        STATUS=$( cat $ETHTRUE/operstate )

        # version commande
        SPEED=$(ethtool $BASENAME_ETH | grep Speed | awk {'print $2'} | cut -d'M' -f1)
        # ATTENTION de retour de ethtool retourne yes au lieu de Up. Il faut donc modifier la ligne en dessous pour le controle
        #STATUS=$(ethtool $BASENAME_ETH | grep 'Link' | awk {' print $3'})

                if [[ "$SPEED" != "$NEGOCIATION" ]] || [[ "$STATUS" -ne "up" ]]
                then
                        LABEL_OUT_ERR=$(echo -n ${LABEL_OUT_ERR} "CRITICAL - $BASENAME_ETH: is $STATUS,$SPEED" $COMA)
                        CHECK_CRIT=1
                else
                        LABEL_OUT_OK=$(echo -n ${LABEL_OUT_OK} "OK - $BASENAME_ETH: is $STATUS,$SPEED " $COMA)
                        CHECK_OK=1
                fi

        fi

done
exit_return

}



##########################################################
# lancement de la fonction via le parametre -f
##########################################################
case $FUNCTION in
                network ) get_network ;;

esac

