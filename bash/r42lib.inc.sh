# --------------------------------------------------------------------------- #
#
# shlib.inc.sh : fonction facilitant l'ecriture de scripts bash
#
# @author Denis Sacchet <denis@rack42.fr>
# @author Loic Barreau <loic@rack42.fr>
#
# Changelog :
#
#   26 Jun 2014; Denis Sacchet <denis@rack42.fr>
#   Import dans le repo rack42
#
#   3 Feb 2011; Denis Sacchet <denis@rack42.fr>
#   Lors du log_init, on tente de creer le repertoire de log et on
#   met un message plus explicite en cas de souci
#
#   30 Jun 2011; Loic Barreau <loic.barreau@rack42.fr>
#   [BUGFIX] s/message/MESSAGE/ logger dans la fonction log_message
#   On utilise local4 pour syslog-er
#
#   17 May 2011; Loic Barreau <loic.barreau@rack42.fr>
#   On positionne un PATH correct, soucis dans certains cas:
#   probleme d'env pour wrapper_tmpreaper.sh, echec sur 'which',
#   quand execute depuis .sh lui meme dans une crontab
#
#   22 Apr 2011; Denis Sacchet <denis@rack42.fr>
#   Changement de la fonction duration_format pour un algo plus simple
#   Ajout des fonctions info_start et info_stop qui affiche en debug des infos
#   sur le deroulement d'un script
#
#   23 Nov 2009; Loic Barreau <loic.barreau@rack42.fr>
#   Typo dans certains noms de variables $PIDXXX et non $PID_XXX
#
#   20 Feb 2008; Denis Sacchet <denis@rack42.fr>
#   Ajout de la fonction verify_pid qui permet de verifier si un PID donne
#   correspond a un processus qui tourne actuellement et optionnellement
#   que la ligne de commande utilisee pour lancer ce processus correspond
#   bien a un pattern donne
#
#   17 Feb 2008; Denis Sacchet <denis@rack42.fr>
#   Correction d'un bug dans la fonction log_message empechant le logage
#   dans un fichier de fonctionner (probleme de casse sur le nom d'une
#   variable)
#
#   02 Jan 2008; Denis Sacchet <denis@rack42.fr>
#   Correction bug log from file : prise en compte du mode debug egalement
#
#   11 Sep 2008; Denis Sacchet <denis@rack42.fr>
#   Ajout du type de message debug
#
#   10 Sep 2008; Denis Sacchet <denis@rack42.fr>
#   Ajout des constantes EXIT_*
# 
#   07 Dec 2007; Denis Sacchet <denis@rack42.fr>
#   Premiere version avec commentaires
# 
# --------------------------------------------------------------------------- #

export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export EXIT_OK=0
export EXIT_WARNING=1
export EXIT_ERROR=2
export EXIT_ALERT=3
export LOCAL_QUIET=0
export LOCAL_DEBUG=0

export PID_RUNNING=0
export PID_NOTRUNNING=1
export PID_USEDBYANOTHER=2

# Cette fonction permet d'initialiser un fichier de log qui sera utilise par
# les fonctions log_message et log_message_from_file

function set_logquiet {
	if [ "x$1" = "xtrue" ]
	then
		LOCAL_QUIET=1
	else
		LOCAL_QUIET=0
	fi
}

function set_logdebug {
	if [ "x$1" = "xtrue" ]
	then
		LOCAL_DEBUG=1
	else
		LOCAL_DEBUG=0
	fi
}

function set_logfile {
	FILE=$1
	if [ -d "$FILE" ]
	then
		log_message "error" "log_init: Le chemin specifie ('$FILE') correspond a un repertoire"
		return $EXIT_ERROR
	fi
	DIR=$(dirname "$FILE")
	mkdir -p "$DIR" &> /dev/null
	if [ $? -ne 0 ]
	then
		log_message "error" "Impossible de creer le repertoire de log '$DIR'"
		return $EXIT_ERROR
	fi
	if [ ! -f "$FILE" ]
	then
		touch "$FILE" &> /dev/null
		if [ $? -ne 0 ]
		then
			log_message "error" "log_init: Impossible de creer le fichier '$FILE'"
			return $EXIT_ERROR
		fi
	fi

	if [ ! -w "$FILE" ]
	then
		log_message "error" "log_init: Vous n'avez pas les droits en ecriture sur le fichier '$FILE'"
		return $EXIT_ERROR
	fi
	export LOCAL_LOG_FILE="$FILE"
	export LOCAL_LOG_PID="$$"
}

function set_logsyslog {
	if [ "x$1" = "xtrue" ]
	then
		LOCAL_SYSLOG=1
	else
		LOCAL_SYSLOG=0
	fi
}

# Cette fonction permet de wrapper la gestion des messages dans un script
# Elle s'attends a avoir certaines variables definies et notamment :
#  - LOCAL_LOG_FILE qui est le fichier de destination
#  - LOCAL_LOG_PID qui est le PID du processus pour lequel on loggue
#  - LOCAL_QUIET pour indiquer si on doit ecrire ou pas sur la sortie standard
#  - LOCAL_DEBUG pour indiquer si on doit ecrire ou pas les messages de debug
# Ensuite la fonction prend deux arguments :
#  - le type de message : info ou error, il sont traites differemment, un
#    message de type error est envoye sur la sortie d'erreur systematiquement,
#    un message de type info est envoye sur la sortie standard seulement si
#    on n'est pas en mode LOCAL_QUIET. Si LOGFILE est defini, le message est ecrit
#    dedans quelque soit son type.
#  - le message en lui meme

function log_message {
	MESSAGE=$2
	TYPE=$1

	case $TYPE in
		info)
			if [ "x$LOCAL_QUIET" = "x" -o "x$LOCAL_QUIET" = "x0" ]
			then
				echo "$MESSAGE"
			fi
			;;
		debug)
			if [ "x$LOCAL_DEBUG" != "x" -a "x$LOCAL_DEBUG" = "x1" ]
			then
				echo "$MESSAGE"
			fi
			;;
		error)
			echo "$MESSAGE" 1>&2
			;;
		*)
			return
			;;
	esac;

	if [ "x$MESSAGE" != "x" ]
	then
		if [ "x$LOCAL_LOG_FILE" != "x" -a "x$TYPE" != "xdebug" ]
		then
			echo "`LC_ALL=C; date +"%b %e %T" | sed -e 's/^./\U&/'` `hostname -s` ${SCRIPT_NAME}[${LOCAL_LOG_PID}]: (${TYPE}) $MESSAGE" >> $LOCAL_LOG_FILE
		fi

		if [ "x$LOCAL_SYSLOG" = "x1" ]
		then
			logger -p local4.$TYPE -i -t ${SCRIPT_NAME} -- "$MESSAGE"
		fi
	fi
}

function log_message_from_file {
	FILE=$2
	TYPE=$1

	case $TYPE in
		info)
			if [ "x$LOCAL_QUIET" = "x" -o "x$LOCAL_QUIET" != "x1" ]
			then
				cat "$FILE"
			fi
			;;
		debug)
			if [ "x$LOCAL_DEBUG" != "x" -a "x$LOCAL_DEBUG" = "x1" ]
			then
				cat "$FILE"
			fi
			;;
		error)
			cat "$FILE" 1>&2
			;;
	esac;

	if [ "x$LOCAL_LOG_FILE" != "x" -a "x$TYPE" != "xdebug" ]
	then
		cat "$FILE" | while read line;
		do
			echo "`LC_ALL=C; date +"%b %e %T" | sed -e 's/^./\U&/'` `hostname -s` ${SCRIPT_NAME}[${LOCAL_LOG_PID}]: (${TYPE}) $line" >> $LOCAL_LOG_FILE
		done
	fi

	if [ "x$LOCAL_SYSLOG" = "x1" ]
	then
		logger -p local4.$TYPE -i -t ${SCRIPT_NAME} -f "$FILE"
	fi
}

# Les fonctions suivantes permettent d'avoir des informations
# en mode debug sur les temps d'execution de differentes parties
# d'un script

function info_init() {
	if [ "x$CURRENT_LEVEL" = "x" ]
	then
		CURRENT_LEVEL=0
	fi
}

function info_start() {
        CURRENT_LEVEL=$((${CURRENT_LEVEL}+1))
        TIMESTAMP[${CURRENT_LEVEL}]=$(date +%s):$1
        RESULT="<"
        for ((i=0;i<${CURRENT_LEVEL};i++))
        do
               RESULT="${RESULT}="
        done
        RESULT="$RESULT $1 ($(date))"
	log_message debug $RESULT
}

function info_stop {
        if [ ${CURRENT_LEVEL} -eq 0 ]
        then
                exit
        fi
        START=$(echo ${TIMESTAMP[${CURRENT_LEVEL}]} | cut -d ":" -f 1)
        COMMENTS=$(echo ${TIMESTAMP[${CURRENT_LEVEL}]} | cut -d ":" -f 2)
        END=$(date +%s)
	RESULT=""
        for ((i=0;i<${CURRENT_LEVEL};i++))
        do
                RESULT="${RESULT}="
        done
        RESULT="${RESULT}>"
        RESULT="${RESULT} ${COMMENTS} ($(date) / $(duration_format $(($END-$START))))"
        CURRENT_LEVEL=$((CURRENT_LEVEL-1))
	log_message debug $RESULT
}

function info_stop_all {
	while [ ${CURRENT_LEVEL} -ne 0 ]
	do
		info_stop
		CURRENT_LEVEL=$((CURRENT_LEVEL-1))
	done
}

# duration_format et timing permettent d'afficher sous forme lisible
# une duree. Duration prend en argument un chiffre qui represente une
# duree en seconde. Ensuite, le script s'efforce de transformer celle
# ci en quelque chose de lisible (separation heure, minute, seconde)

function duration_format {
        H=$(($1/3600))
        M=$((($1-$H*3600)/60))
        S=$(($1-$H*3600-M*60))
        echo -n "$(printf '%03d' $H):$(printf '%02d' $M):$(printf '%02d' $S)"
}

# Affiche le timing a partir de variable normalisee STARTTIME et ENDTIME
# passes en parametres. Le formatage est effectue par duration_format.

function timing {
	STARTTIME=$1
	ENDTIME=$2
	duration_format $((ENDTIME-STARTTIME))
}

# Cette fonction permet de poser un fichier sur un serveur distant en
# controlant un certain nombre de choses :
# - si CONTROL = 1, alors a la fin de l'upload, le fichier CONTROL_FILE est
#   cree, indiquant que le fichier est complet
# - si CHECKSUM = 1, alors le fichier CHECKSUM_FILE est genere sur le serveur
#   distant en utilisant la methode CHECKSUM_METHOD (pour l'instant uniquement
#   md5sum), il pourra etre utiliser pour verifier l'integrite du fichier
# Si vous avez besoin d'un nom d'utilisateur et d'un mot de passe pour acceder
# au serveur distant, n'hesitez pas a utiliser le fichier .netrc
#
# Codes de retour :
#  - 0 => tout est ok
#  - 1 => impossible de se connecter au serveur
#  - 2 => le fichier local n'existe pas ou n'est pas lisible
#  - 3 => le fichier distant existe deja et l'option force n'est pas mise
#  - 4 => l'envoi du fichier a echoue
#  - 5 => l'envoi du fichier checksum a echoue
#  - 6 => la methode pour calculer le checksum n'est pas reconnue
#  - 7 => l'envoi du fichier control a echoue

function put_fichier_by_ftp {
	FTP_SERVER=${1}
	LOCAL_FILE=${2}
	REMOTE_FILE=${3}
	RETRY_COUNT=${4}
	RETRY_DELAY=${5}
	CONTROL=${6}
	CONTROL_FILE=${7}
	CHECKSUM=${8}
	CHECKSUM_FILE=${9}
	CHECKSUM_METHOD=${10}
	FORCE=${11}
	PASSIVE=${12}

	# Mise en place des options

	if [ "x$PASSIVE" = "x" -o "x$PASSIVE" = "0" ]
	then
		CURL_OPTS=" --disable-epsv"
	else
		CURL_OPTS=" --ftp-pasv"
	fi

	CURL_OPTS="$CURL_OPTS --ftp-create-dirs"

	if [ -f ~/.netrc ]
	then
		CURL_OPTS="$CURL_OPTS --netrc"
	fi

	# Test de la connexion au serveur

	curl ${CURL_OPTS} ftp://${FTP_SERVER} &> /dev/null
	if [ ${?} -ne 0 ]
	then
		return 1
	fi

	# On regarde si le fichier source existe et est lisible

	if [ ! -r "${LOCAL_FILE}" ]
	then
		return 2
	fi

	# On regarde si le fichier distant existe

	if [ `curl -q ${CURL_OPTS} --list-only ftp://${FTP_SERVER}/${REMOTE_FILE} 2> /dev/null| grep "^$(basename $REMOTE_FILE)\$" | wc -l` -ne 0 -a $FORCE -ne 1 ]
	then
		return 3
	fi

	# Si le fichier n'existe pas ou on force le reupload,
	# on commence a essayer

	current_count=0
	while [ $current_count -lt $RETRY_COUNT ]
	do
		curl ${CURL_OPTS} --upload-file "${LOCAL_FILE}" "ftp://${FTP_SERVER}/${REMOTE_FILE}" 2> /dev/null
		if [ $? -ne 0 ]
		then
			sleep ${RETRY_DELAY}
			current_count=$(($current_count+1))
		else
			break
		fi
	done

	# Dans le cas ci-dessous, l'upload a echoue
	if [ $current_count -eq $RETRY_COUNT ]
	then
		return 4
	fi

	# Si on doit realiser un checksum, le faire maintenant
	if [ "x$CHECKSUM" = "x1" ]
	then
		case ${CHECKSUM_METHOD} in
			md5sum)
				CHECKSUM_FILE_TEMP=`mktemp`
				md5sum "${LOCAL_FILE}" | cut -f 1 -d " " > ${CHECKSUM_FILE_TEMP}
				curl ${CURL_OPTS} --upload-file "${CHECKSUM_FILE_TEMP}" "ftp://${FTP_SERVER}/${CHECKSUM_FILE}" 2> /dev/null
				if [ $? -ne 0 ]
				then
					rm "$CHECKSUM_FILE_TEMP"
					return 5
				fi
				;;
			*)
				return 6
				;;
		esac
	fi

	# Le fichier est uploade, le checksum aussi si on
	# devait en faire un, plus qu'a uploade le fichier
	# indiquant que c'est termine (si besoin ...)

	if [ "x$CONTROL" = "x1" ]
	then
		CONTROL_FILE_TEMP=`mktemp`
		curl ${CURL_OPTS} --upload-file "${CONTROL_FILE_TEMP}" "ftp://${FTP_SERVER}/${CONTROL_FILE}" 2> /dev/null
		if [ $? -ne 0 ]
		then
			rm "$CONTROL_FILE_TEMP"
			return 7
		fi
	fi
		
	rm "$CHECKSUM_FILE_TEMP"
	rm "$CONTROL_FILE_TEMP"

	return 0
}

# Permet de verifier qu'un fichier de configuration sourcé par . ne redefini pas
# une liste de variable passée en paramètre

function verify_conffile {
	if [ $# -lt 1 ]
	then
		log_message error "verify_conffile take at least 1 parameter"
		exit ${EXIT_OK}
	fi
	CONFFILE=$1
	if [ ! -f $CONFFILE ]
	then
		exit ${EXIT_OK}
	fi

	shift 1
	VARIABLES="$* EXIT_OK EXIT_WARNING EXIT_ERROR EXIT_ALERT LOCAL_QUIET LOCAL_DEBUG PID_RUNNING PID_NOTRUNNING PID_USEDBYANOTHER"
	(
		for i in $VARIABLES
		do
			unset $i
		done
		. "$CONFFILE"
		for i in $*
		do
			if [ "x$(eval echo \$$i)" != "x" ]
			then
				exit 1
			fi
		done
		exit 0
	)
	if [ $? -ne 0 ]
	then
		return ${EXIT_ERROR}
	else
		return ${EXIT_OK}
	fi
}

function verify_variables {
	for i in $*
	do
		if [ "x$(eval echo \$$i)" = "x" ]
		then
			return ${EXIT_ERROR}
		fi
	done
	return ${EXIT_OK}
}

function verify_pid {
	PID=$1
	CHECKSTRING=$2

	if [ ! -d /proc/$PID ]
	then
		return $PID_NOTRUNNING
	fi

	if [ -d /proc/$PID ]
	then
		if [ "x$CHECKSTRING" != "x" ]
		then
			if [ $(grep "$CHECKSTRING" /proc/$PID/cmdline | wc -l) -eq 0 ]
			then
				return $PID_USEDBYANOTHER
			fi
		fi
		return $PID_RUNNING
	fi
}

function is_unsigned_int {
	if [[ "$1" =~ ^[0-9]+$ ]]
	then
		return ${EXIT_OK}
	else
		return ${EXIT_ERROR}
	fi
}

function cron_init {
        export SCRIPT_DIR=$(dirname $(realpath ${0}))
        export SCRIPT_NAME=$(basename ${0})
        export CRON_BASE=$(echo ${SCRIPT_DIR} | sed "s@\(.*\)/cronjobs.*@\1@");

        export TEMP_DIR_LOCAL=${CRON_BASE}/tmp/${SCRIPT_NAME}

        export LOGS_DIR_BASE=${CRON_BASE}/logs
        export LOGS_DIR_LOCAL=${CRON_BASE}/logs/${SCRIPT_NAME}

        export DATA_DIR_BASE=${CRON_BASE}/data/
        export DATA_DIR_LOCAL=${CRON_BASE}/data/${SCRIPT_NAME}

        export CONF_DIR_BASE=${CRON_BASE}/conf
        export CONF_DIR_LOCAL=${CRON_BASE}/conf/${SCRIPT_NAME}

        export LIB_DIR_BASE=${CRON_BASE}/lib
        export LIB_DIR_LOCAL=${CRON_BASE}/lib/${SCRIPT_NAME}

        export RUN_DIR_BASE=${CRON_BASE}/run
        export RUN_DIR_LOCAL=${CRON_BASE}/run/${SCRIPT_NAME}
}
