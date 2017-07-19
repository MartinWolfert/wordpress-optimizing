#!/bin/sh

. /etc/profile
GREP=`which grep`
WC=`which wc`
CUT=`which cut`
HEAD=`which head`
TAIL=`which tail`
MYSQLHOTCOPY=`which mysqlhotcopy`
MYSQLDUMP=`which mysqldump`
MYSQL=`which mysql`
MYSQLADMIN=`which mysqladmin`
EGREP=`which egrep`
RSYNC=`which rsync`
SCP=`which scp`
CHOWN=`which chown`
LS=`which ls`
CP=`which cp`
NICE=`which nice`
GZIP=`which gzip`


BACKUPBASEDIR="/BACKUPS/mysql"
# Da der Backupjob nach Mittenacht laeuft, bekommt der Ordner den Datumsstempel von gestern
BACKUPDIR="${BACKUPBASEDIR}/`date -d "yesterday" +%Y-%m-%d`"
LOGPATH="/var/log/mysqlhotcopy"
LOGFILE="${LOGPATH}/mysqlhotcopy_`date +%y-%m-%d-%M`.log"
MYSQLDATAPATH="/var/lib/mysql/"
MYSQLINIT="/etc/init.s/mysql"

# Hier traegt man die Tabellen ein, die nicht gebackupt werden sollen
# Kann ergaenzt werden: DBFILTER="(information_schema|tmp|...|)"
DBFILTER="(information_schema|dev|tmp)";


#############################################################################
## DO NOT EDIT BELOW !! #############################
#############################################################################

# Wenn das Logdir nicht vorhanden ist => erstellen
if ! [ -d ${LOGPATH} ]; then
        mkdir ${LOGPATH}
        echo "`date` Logdir not prestent ... build it" >> ${LOGFILE}
fi

#  Wenn der Backupordner nicht vorhanden ist => erstellen
if ! [ -d ${BACKUPDIR} ]; then
         mkdir ${BACKUPDIR}
        echo "`date` Backupdir not present ... build it" >> ${LOGFILE}
fi

DBS=$($MYSQL -Bse "show databases");

for db in $DBS
do
        if !(echo $db | $EGREP $DBFILTER > /dev/null);
                then
                        FILENAME="$db-`date +%Y_%m_%d_%H_%M_%S`.sql.gz";
                        $NICE -n 20 $MYSQLDUMP $db | $NICE -n 20 $GZIP -c > "$BACKUPDIR/$FILENAME";
        fi
done

exit 1
