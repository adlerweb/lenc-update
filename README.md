# lenc-update
Script to update [letsencrypt certificates](https://letsencrypt.org/) automatically in a clever way.

Please note that this software is in alpha state and comes with no warranties at all. Run a your own risk. Check thoroughly if it suits your needs before running it.

This fork is based on [lenc-update by Stefan Beckers](https://github.com/myprs/lenc-update)

## Abstract

The script should implement the following features:

 * Automatically reload or restart services associated with a renewed certificate
 * Detects installed certificates automatically
 * Only renewes certificates close to expiration
 * Restarts services only once even if multiple certificate have been updated
 * Suitable for unattended or timed usage

## Prerequisites

 * Letsencrypt Client
 * OpenSSL
 * grep
 * awk
 * bash

## Quick Start

1. Make sure the prerequisites above are met
1. Copy lenc-update.conf to /etc/letsencrypt/lenc-update.conf and adjust to your system
1. Ensure /etc/letsencrypt/cli.ini is set for automatic usage (see below)
1. Run

## Service handling
Inside the global config you can define a command to be executed if any certificate was renewed. This could for example reload
your webserver. Additionally you can create a file /etc/letsencrypt/lenc-example.com.conf - each line will be executed if the
domain named in the filename is renewed. If multiple domains are renewed and specify a identical command it will only run once.

Since the script is most likely run with extended privileges you really want to prevent users writing to your letsencrypt directory

## Work Flow of the Script

* On every run the script enumerates the configuration directory for files with the given suffix and processes each of them:
 * it extracts the certificate name;
 * from the certificate the validity is read;
 * if the date is coming closer than the given amount of days, we fire up letsencrypt with the ini file;
* If any certificate has been updated successfully, we do restart services at the end of the script.


## Sample Ini File for Letsencrypt

This is a sample letsencrypt ini file for unattended certificate retrieval and renewal:

```
# Use a 4096 bit RSA key instead of 2048
rsa-key-size = 4096

# Uncomment and update to register with the specified e-mail address
email YOURMAIL@example.com

# Uncomment to use a text interface instead of ncurses
text = True

# Uncomment to use the webroot authenticator. Replace webroot-path with the
# path to the public_html / webroot folder being served by your web server.
authenticator = webroot
webroot-path = /var/www/

# always renew if requested - without LE will skip certificates still valid for some time
renew-by-default = True

```

Now obtaining and renewing the certificates can be done without user interaction by running something like:
 
* ```letsencrypt -d example.com certonly```.

Please note that letsencrypt needs write access to the named instance's webroot when using the webroot authenticator.
  
