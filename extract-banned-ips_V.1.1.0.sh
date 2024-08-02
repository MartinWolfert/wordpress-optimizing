#!/bin/sh
# Bash script to xxtract already fail-banned ips 
# by Martin Wolfert
# https://wp-loft.de
# V.1.1.0
# 2014/08/28
# Original from - methurt: 
# http://www.fail2ban.org/wiki/index.php/Fail2ban:Community_Portal#Question_about_persistent_IP_address_bans_over_restart

### Some variables ###
GREP=`which grep`
SED=`which sed`
F2BCL=`which fail2ban-client`
CHMOD=`which chmod`
RUNDIR="/root/fail2ban-adds"
BANNED_IPS="${RUNDIR}/fail2ban-manual.list"

 # Function to save the fail2ban rules
do_save()
{
        if [ -f ${BANNED_IPS} ]; then
                rm ${BANNED_IPS}
        fi

        jails=$(${F2BCL} status | ${GREP} Jail list: | ${SED} 's/.*Jail list:t+//;s/,//g')

        for jail in ${jails}; do
                for ip in $(${F2BCL} status ${jail}| ${GREP} IP list| ${SED} 's/.*IP list:t//'); do
                        echo "fail2ban-client set ${jail} banip ${ip} ">> ${BANNED_IPS}
                done
        done
        ${CHMOD} 755 ${BANNED_IPS}
        return 0
}

# Function to restore the fail2ban rules
do_restore()
{
        if [ ! -f ${BANNED_IPS} ]; then
                echo "Hey dude ... first you have to save the fail2ban rules !  :-)"
                exit 3
        fi
        ${BANNED_IPS} >/dev/null 2>&1
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