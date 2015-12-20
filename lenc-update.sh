#!/bin/bash 
#
# Certificate Update script for letsencrypt 
#   by (c) Stefan Beckers 2015
#
# 		Released under 
# GNU GNU GENERAL PUBLIC LICENSE Version 2
#


#################################################################################
#
# If you want to change the defaults it is strongly recommended to 
# use the config file under /etc/default/lenc-update
#




DEBUG=0

[ $DEBUG -ge 3 ] && set -xv


LENC_CONFDIR="/etc/letsencrypt"
LENC_LIVEDIRNAME="$LENC_CONFDIR/live"
LENC_DEFAULT_CERTFILENAME="cert.pem"

LENC_CONFFILE_SFX=".ini"
LENC_AUTOBINARY="/root/install/letsencrypt/bin/letsencrypt/letsencrypt-auto"
LENC_RENEWCMD="renew"
# you might want to replace the certificate, but why??
# LENC_RENEWCMD="certonly"

# Minimum days of cert validity that must be left before trying to renew cert
MIN_VALDAYS=14


## Parameters to restart/reload the webserver
SERVICE_BIN="service"
#WEBSRV_SERVICENAME="apache2"
WEBSRV_SERVICENAME="nginx"
## apache restart
#WEBSRV_CMD01="gracefull-restart"
#WEBSRV_CMD02=""
## nginx, but I am not sure if this will be sufficient to reload the certificates
WEBSRV_CMD01="restart"
WEBSRV_CMD02=""
# the hard way including an outage but making sure to reload
WEBSRV_CMD01="stop"
WEBSRV_CMD02="start"


#################################################################################
#
# No user servicable parts below this point
#


RESTARTWEBSERVER=0

LENC_UPDATE_CONFFILE="/etc/default/lenc-update"



# you might want to overide the defaults in the default file (very debianish way....)
[ -r "$LENC_UPDATE_CONFFILE" ] && source "$LENC_UPDATE_CONFFILE"



function updatecert () {


	local DOMAINNAME="$1"
	[ $DEBUG -ge 1 ] && echo "--> Updating cert for domain $DOMAINNAME"
	$LENC_AUTOBINARY -c "$LENC_CONFDIR/$DOMAINNAME$LENC_CONFFILE_SFX" $LENC_RENEWCMD

}



function getcertdaystoexpiry () {

	# get the days to expiry of the cert

	local CERTFILE="$1"

	local CERT_XPRY_STRING=`openssl x509 -in "$CERTFILE" -noout   -enddate | mawk -F "=" '{print $2}'`
	local CERT_XPRY_NUM=`date -d "$CERT_XPRY_STRING" +%s`
	local DATE_NOW_NUM=`date  +%s`
	[ $DEBUG -ge 2 ] && echo "DEBUG02: Now in seconds since 1970 is $DATE_NOW_NUM"

	local CERT_XPRY_INSECONDS=$(($CERT_XPRY_NUM - $DATE_NOW_NUM))
	[ $DEBUG -ge 2 ] && echo "DEBUG02: Cert expiry in seconds since 1970 is $CERT_XPRY_INSECONDS"
	
	DAYSLEFT=$(( CERT_XPRY_INSECONDS / 86400 ))
	[ $DEBUG -ge 2 ] && echo "DEBUG02: $DAYSLEFT days left to expiry of certificate for domain $DOMAINNAME."
	
}


function checkcertneedsrenewal () {

	local LIVEDIRNAME="$1"
	local DOMAINNAME="$2"

	# set variable to a decent default
	DAYSLEFT=-9999999

	getcertdaystoexpiry "$LIVEDIRNAME/$LENC_DEFAULT_CERTFILENAME"

	[ $DEBUG -ge 2 ] && echo "DEBUG02: $DAYSLEFT days left to exiry of  certificate for domain $DOMAINNAME."

	if [ $DAYSLEFT -lt $MIN_VALDAYS ] ; 
	then 
		## go for the update
		updatecert "$DOMAINNAME"
		if [ $? -eq 0 ] ; 
		then
			RESTARTWEBSERVER=1
		else
			[ $DEBUG -ge 2 ] && echo "DEBUG02: Update of cert did fail."
			
		fi 
	else 
		## not updating cert
		[ $DEBUG -ge 1 ] && echo "DEBUG01: $DAYSLEFT days left to exiry of  certificate for domain $DOMAINNAME. Not exceeding the minimum validity of $MIN_VALDAYS. Not updating certificate."
		 
	fi
	
}

function runonecert () {


	# check one cert and update if necessary


	local INIFILE="$1"

	[ $DEBUG -ge 1 ] && echo "DEBUG01: Inifile is $INIFILE"

	local DOMAINNAME="`grep -E "^[[:space:]]*domain[[:space:]]*.*$" "$INIFILE" | mawk '{print $2}'`"

	[ $DEBUG -ge 1 ] && echo "DEBUG01: Domainname is $DOMAINNAME"
	
	local LIVEDIRNAME="$LENC_LIVEDIRNAME/$DOMAINNAME"
	# check if livedir exists and is accessible
	if [ -r "$LIVEDIRNAME" ] ;
	then
	
		checkcertneedsrenewal "$LIVEDIRNAME" "$DOMAINNAME"
		CERSTSTATE=$?

	else 
		# certstate not found
		echo "ERROR: When checking for cert with domainname >$DOMAINNAME< I could not find livedir >$LIVEDIRNAME<. Please check if it is readable. Aborting this check."
		return -1 
	fi



}




function runallconfigs () {


	# enumerate all letsencrypt files and start the check and update on them 

	for INIFILE in `find "$LENC_CONFDIR" -maxdepth 1 -name "*$LENC_CONFFILE_SFX" ` ; 
	do 
		runonecert "$INIFILE"
	done


}



function careforwebserver () {

	if [ $RESTARTWEBSERVER -eq 1 ] ;
	then

		# need to reload webserver config
		[ $DEBUG -ge 2 ] && echo "DEBUG02: Restarting webserver: running >$SERVICE_BIN  $WEBSRV_SERVICENAME $WEBSRV_CMD01<."
		"$SERVICE_BIN"  "$WEBSRV_SERVICENAME" "$WEBSRV_CMD01"
		RETVAL=$?
		
		[ -n "$WEBSRV_CMD02" -a $DEBUG -ge 2 ] && echo "DEBUG02: Restarting webserver: running >$SERVICE_BIN  $WEBSRV_SERVICENAME $WEBSRV_CMD02<."
		[ -n "$WEBSRV_CMD02" ] && { "$SERVICE_BIN"  "$WEBSRV_SERVICENAME" "$WEBSRV_CMD02"; RETVAL=$?; }
		

		if [ $RETVAL -ne 0 ] ; 
		then
			echo "ERROR: Webserver restart did fail with errorcode $RETVAL. Please check!"
			exit $RETVAL
		else 
		[ $DEBUG -ge 1 ] && echo "DEBUG01: Webserver did restart successfully."
			
		fi
	else
		[ $DEBUG -ge 2 ] && echo "DEBUG02: No restart of webserver needed."
	fi

}


runallconfigs
careforwebserver


