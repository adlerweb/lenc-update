# lenc-update
Script to update letsencrypt certificates automatically in a clever way.

Please note that this software is in alpa state and comes with no warranties at all. Run a your own risk. Check thoroughly if it suits your needs before running it.


## Abstract

The script should implement the following features:

1. works with nginx, but can easily altered to work with any other webserver,
1. works with multiple certificates,
1. treats each certificate individually,
1. can be run daily without taking any action without cause,
1. restarts the webserver only once even if multiple certificate shave been updated
1. suitable for unattended usage as often as you like,
1. should request new certificate when expiry of the present one comes closer than an configurable amount of days,
1. expiry date is read from the certificate,
1. if request fails for some reason, the next run retries.


## Prerequisites

1. have @letsencrypt-auto@ installed (see the letsencrypt website for more info about usage of letsencrypt.)
1. have a directory @/etc/letsencrypt@ and create your .ini files with all nexessary saettings to have your certificates processes in a unattended fashion, not requiring any manual intervention.
1. make sure the ini-files do have a suffix of ".ini"
1. 



## Quick start

1. Make sure the prerequisites are met or be prepared to change the defaults more agressively.
1. Put the file @lenc-update@ in your @/usr/local/sbin@ directory and make it exeutable for user root.
1. If you want to change the defaults in the script and want to keep your setting separate (e.g. to not overwriting the settiungs when updating the script)  create a file @/etc/default/lenc-update@ . All global variables can be overridden here. The most interesting ones are:
 1. @DEBUG@: Numeric value to increase verbosity, 0=suitable for unattended execution, 1= some more information but still ok for cron execution, prepare for recieving daily mailing from cron.
 1. @LENC_CONFDIR@: Basedir where the letsencrypt configuration lives. Default is "/etc/letsencrypt"
 1. @LENC_CONFFILE_SFX@: file suffix, indicating that this is a letsencrypt certificate definition. Defaults to ".ini"
 1. @MIN_VALDAYS@: Minimum number of days a certificate is valid untill we start trying to renew the signature. Defaults to 14 days.
1. Make sure you do run the script on a regular basis, e.g. once a day from cron.
 1. To do so you might want to create a softlink:  @cd /etc/cron.daily/; ln -s /usr/local/sbin/lenc-update@ 
 


