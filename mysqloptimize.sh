#!/bin/sh

. /etc/profile
#IFCONFIG=`which ifconfig`
GREP=`which grep`
WC=`which wc`
CUT=`which cut`
HEAD=`which head`
TAIL=`which tail`
MYSQLOPTIMIZE=`which mysqloptimize`
EGREP=`which egrep`
RSYNC=`which rsync`
SCP=`which scp`
CHOWN=`which chown`
LS=`which ls`
CP=`which cp`
NICE=`which nice`
GZIP=`which gzip`



BASEDIR="/root/mysqloptimize"
LOGFILE="${BASEDIR}/mysqloptimize_`date +%y-%m-%d-%M`.log"

#############################################################################
## DO NOT EDIT BELOW !! #############################
#############################################################################
# Wenn das BASEDIR nicht vorhanden ist => erstellen
if ! [ -d ${BASEDIR} ]; then
        mkdir ${BASEDIR}
        echo "`date` Logdir not prestent ... build it" >> ${LOGFILE}
fi

${MYSQLOPTIMIZE} -o --all-databases >> ${LOGFILE}
${GZIP} -9 ${LOGFILE}
