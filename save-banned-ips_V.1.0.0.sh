#!/bin/bash
# Little helper to save and restore  blocked (Fail2ban)  IPs
# by Martin Wolfert
# https://wp-loft.de
# V.1.0.0
# 2014/08/28

### Some variables ###
IPT_SAVE=`which iptables-save`
IPT_RESTORE=`which iptables-restore`
RUNDIR="/root/fail2ban-adds"
BANNED_IPS="${RUNDIR}/iptables.list"

# Function to save the iptable rules
do_save()
{
        if [ -f ${BANNED_IPS} ]; then
                rm ${BANNED_IPS}
        fi
        ${IPT_SAVE} >> ${BANNED_IPS}
        return 0
}

# Function to restore the iptables stuff
do_restore()
{
        if [ ! -f ${BANNED_IPS} ]; then
                echo "Hey dude ... first you have to save some fw rules !  :-)"
                exit 3
        fi
        ${IPT_RESTORE} ${BANNED_IPS}
        return 0
}

# Doing
case "$1" in
        save)
                do_save
                ;;

        restore)
                do_restore
                ;;

        *)
                echo "Usage $0 {save|restore}"
                exit 3
                ;;
esac
exit 0