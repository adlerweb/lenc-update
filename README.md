# lenc-update
Script to update [letsencrypt certificates](https://letsencrypt.org/) automatically in a clever way.

Please note that this software is in alpha state and comes with no warranties at all. Run a your own risk. Check thoroughly if it suits your needs before running it.


## Abstract

The script should implement the following features:

1. works with nginx, but can easily altered to work with any other web server,
1. works with multiple certificates,
1. treats each certificate individually,
1. can be run daily without taking any action without cause,
1. restarts the web server only once even if multiple certificate shave been updated,
1. suitable for unattended usage as often as you like,
1. should request new certificate when expiry of the present one comes closer than an configurable amount of days,
1. expiry date is read from the certificate,
1. if request fails for some reason, the next run retries.


## Prerequisites

1. Have `letsencrypt-auto` installed 
 * see the [letsencrypt website](https://letsencrypt.org/) 
 * and [documentation](https://community.letsencrypt.org/c/docs/) for more info about usage of letsencrypt, or
 * you might be interested in reading my [hands on review on letsencrypt](http://www.mypersonalrocketscience.de/letsencrypt,/nginx,/primer/2015/12/05/my-first-review-on-letsencrypt.html).

1. Have a directory `/etc/letsencrypt` and [create your ".ini" files](http://letsencrypt.readthedocs.org/en/latest/using.html#configuration-file) with all necessary settings to have your certificates processes in a unattended fashion, not requiring any manual intervention.
1. Make sure the ini-files do have a suffix of `.ini` or change the script configuration later on.



## Quick start

1. Make sure the prerequisites above are met or be prepared to change the defaults more aggressively.
1. Put the file `lenc-update` in your `/usr/local/sbin` directory and make it executable for user root.
1. If you want to change the defaults in the script and want to keep your setting separate (e.g. to not overwriting the settings when updating the script)  create a file `/etc/default/lenc-update` . All global variables can be overridden here. The most interesting ones are:
 1. `DEBUG`: Numeric value to increase verbosity, 0=suitable for unattended execution, 1= some more information but still OK for cron execution, prepare for receiving daily mailing from cron.
 1. `LENC_CONFDIR`: Basedir where the letsencrypt configuration lives. Default is "/etc/letsencrypt"
 1. `LENC_CONFFILE_SFX`: file suffix, indicating that this is a letsencrypt certificate definition. Defaults to ".ini"
 1. `MIN_VALDAYS`: Minimum number of days a certificate is valid until we start trying to renew the signature. Defaults to 14 days.
1. Make sure you do run the script on a regular basis, e.g. once a day from cron.
 1. To do so you might want to create a softlink:  `cd /etc/cron.daily/; ln -s /usr/local/sbin/lenc-update` 

 
## Work flow of the script

* On every run the script enumerates the configuration directory for files with the given suffix and processes each of them:
 * it extracts the domain name;
 * it looks for a directory under the configuration directory named after the domain and expect a certificate there;
 * from the certificate the validity is read;
 * if the date is coming closer than the given amount of days, we fire up letsencrypt-auto with the ini file;
* If any certificate has been updated successfully, we do restart nginx at the end of the script. 


## Sample ini file for letsencrypt

This is my sample letsencrypt ini file for unattended certificate retrieval and renewal:

```
# This is an example of the kind of things you can do in a configuration file.
# All flags used by the client can be configured here. Run Let's Encrypt with
# "--help" to learn more about the available options.

# Use a 4096 bit RSA key instead of 2048
rsa-key-size = 4096

# Always use the staging/testing server
#server = https://acme-staging.api.letsencrypt.org/directory

# Uncomment and update to register with the specified e-mail address
email PQGHCTMLCBHY@spammotel.com

# Uncomment to use a text interface instead of ncurses
text = True


# Uncomment to use the webroot authenticator. Replace webroot-path with the
# path to the public_html / webroot folder being served by your web server.
authenticator = webroot
webroot-path = /var/www/namedinstance/webroot/

domain example.personalrocketscience.de

# make renewal noninteractive
renew-by-default

```
