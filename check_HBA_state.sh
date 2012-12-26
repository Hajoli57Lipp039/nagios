ETURN=0
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
version 0.5
Options non obligatoire :
        -h | --help :           Affiche cette ecran d aide
        -d | --debug            Mode debug

Options obligatoire (avec parametre):
        -c | --critical :       Seuil du critical centreon. quand mentionne, Il faut un minimum de hba online pour que le check OK




Examples:
  $APPNAME -c 3
---------------------------------------------------------------------
EOU
exit 3
}

#if [ $# == 0 ]; then usage ;fi

# -o option coute - le caractere ":" indique une attente de parametre
# -l option longue
ARGS=`getopt -o "dhc:" -l "debug,help,critical:" \
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
REP_FC_REMOTE="/sys/class/fc_remote_ports/"
##################################
## LISTES DES FONCTIONS
##################################
function get_port_state() {
COUNT=0


for i in $( ls $REP_FC_REMOTE )
do
STATE=$( cat $REP_FC_REMOTE/${i}/port_state )


                if [[ $STATE -ne "Online" ]] ; then
                        LABEL_OUT_ERR=$(echo ${LABEL_OUT_ERR} "Le port ${i} est en erreur $COMA")
                else
                        LABEL_OUT_OK=$(echo "Toutes les ports sont OK")
                        let "COUNT++"
                fi
done

        if [[ "$COUNT" -lt "$CRITICAL" ]] ; then
                if [[ ! $LABEL_OUT_ERR ]] ; then LABEL_OUT_ERR="Le nombre de remote port n'est pas suffisant"; fi
                CHECK_CRIT=1
        else
                CHECK_OK=1
        fi


exit_return
}



get_port_state
