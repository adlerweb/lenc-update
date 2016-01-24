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
# use the configuration file under /etc/default/lenc-update or the optional 
# default configuration /$LENC_CONFDIR/lenc-update.conf .
#
# If a configuration file is provided as the first parameter, this will be 
# read instead of the defaults
#
# You can set the following defaults also from the commandline:
#  export DEBUG=x
#  export DRYRUN=x
# 
# Please note that the values will be superseded if you assign different 
# values in the configuration files. 
#



#################################################################################
#
# No user servicable parts beyond this point!
#


function usage () {

			cat <<EOUSAGE

usage:    lenc-update.sh [CONFIGFILE]

EOUSAGE
}


function setenv () {


	DEBUG=${DEBUG:-0}
	DRYRUN=${DRYRUN:-0}

	[ $DEBUG -ge 5 ] && set -xv


	LENC_CONFDIR="/etc/letsencrypt"
	LENC_RENEWDIR="$LENC_CONFDIR/renewal"
	LENC_LIVEDIRNAME="$LENC_CONFDIR/live"
	LENC_DEFAULT_CERTFILENAME="cert.pem"

	LENC_CONFFILE_SFX=".conf"
	LENC_BINARY="/usr/bin/letsencrypt"
	## letsencrypt command to run if certificate is about to expire
	## default is to renew and not use any integrated install method
	LENC_RENEWCMD="certonly"

	# Minimum days of cert validity that must be left before trying to renew cert
	MIN_VALDAYS=30

	LENC_OPENSSL="/usr/bin/openssl"
	LENC_AWK="/usr/bin/awk"
	LENC_GREP="/bin/grep"

	# Config files
	## debianish default
	LENC_UPDATE_DEFCONFFILE="/etc/default/lenc-update"
	## you might want one in the letsencrypt directory
	LENC_UPDATE_CONFFILE="$LENC_CONFDIR/lenc-update.conf"

	RESTARTS=()

	if [ -z "$1" ];
	then
		# try to read the default configuration files

		# you might want to overide the defaults in the default file (a very debianish way....)
		[ -r "$LENC_UPDATE_DEFCONFFILE" ] && source "$LENC_UPDATE_DEFCONFFILE"

		# you might want to overide the defaults in a config file (the usual trade)
		[ -r "$LENC_UPDATE_CONFFILE" ] && source "$LENC_UPDATE_CONFFILE"
	else
		if [ -r "$1" ] ;
		then
			# read the provided configuration file
			source "$1"
		else
			usage
			exit 1
		fi		
	fi

	[ $DEBUG -ge 5 ] && set -xv



}



function checkenv () {

	# check if LENC_BINARY is set to a reasonable value
	which "$LENC_BINARY" > /dev/null || { echo "ERROR: Variable LENC_BINARY has no reasonable value, >$LENC_BINARY< not found or not executable."; exit 1; }

	
	# check existance of LENC_CONFDIR directory
	[ ! -d "$LENC_CONFDIR" ] && { echo "ERROR: Variable LENC_CONFDIR has no reasonable value, >$LENC_CONFDIR< not found or not an directory."; exit 3; }


	# check existence of LENC_LIVEDIRNAME directory
	[ ! -d "$LENC_LIVEDIRNAME" ] && { echo "ERROR: Variable LENC_LIVEDIRNAME has no reasonable value, >$LENC_LIVEDIRNAME< not found or not an directory."; exit 3; }
}

function updatecert () {


	local DOMAINNAME="$1"
	[ $DEBUG -ge 1 ] && echo "--> Updating cert for domain $DOMAINNAME"

	#Get Domain List
	DOMAINSTR=`$LENC_GREP "domains = " $INIFILE | $LENC_AWK -F "= " '{print $2}'`
	IFS=', ' read -r -a DOMAINLIST <<< "$DOMAINSTR"

	separator=" -d "
	DOMAINCMD="$( printf "${separator}%s" "${DOMAINLIST[@]}" )"
	DOMAINCMD="${DOMAINCMD:${#separator}}" # remove leading separator

	if [ $DRYRUN -eq 0 ] ;
	then
		# be serious and go for it
		$LENC_BINARY -d ${DOMAINCMD} $LENC_RENEWCMD
	else 
		# just tell us what would happen
		echo "DRYRUN: $LENC_BINARY -d $DOMAINCMD $LENC_RENEWCMD"
	fi

}



function getcertdaystoexpiry () {

	# get the days to expiry of the cert

	local CERTFILE="$1"

	local CERT_XPRY_STRING=`$LENC_OPENSSL x509 -in "$CERTFILE" -noout   -enddate | $LENC_AWK -F "=" '{print $2}'`
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
			[[ ! -z ${LENC_SRV_DEFAULT} ]] && RESTARTS=( "${RESTARTS[@]}" "${LENC_SRV_DEFAULT[@]}" )

			if [ -f ${LENC_CONFDIR}/lenc-${DOMAINNAME}.conf ] ;
			then
				#Read file and add each line as command
				while IFS='' read -r line || [[ -n "$line" ]]; do
					RESTARTS+=("${line}")
				done < "${LENC_CONFDIR}/lenc-${DOMAINNAME}.conf"
			fi
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

	local DOMAINNAME="`basename $INIFILE $LENC_CONFFILE_SFX`"

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

	for INIFILE in `find "$LENC_RENEWDIR" -maxdepth 1 -name "*$LENC_CONFFILE_SFX" ` ;
	do 
		runonecert "$INIFILE"
	done


}



function processrestarts () {

	if [ ${#RESTARTS[@]} -gt 0 ];
	then
		#Remove duplicates
		readarray -t commands < <(printf '%s\n' "${RESTARTS[@]}" | sort -u)
		
		for cmd in "${commands[@]}" ;do
			[ $DEBUG -ge 2 ] && echo "DEBUG02: Restarting service: running >$cmd<."
		
			if [ $DRYRUN -eq 0 ] ;
			then
				# being serious and really doing it
				$cmd
			else
				# dry run and jsut showing off
				echo "DRYRUN : $cmd"
			fi
		done
	else
		[ $DEBUG -ge 2 ] && echo "DEBUG02: No restart of services needed."
	fi

}


setenv "$1"
checkenv
runallconfigs
processrestarts


