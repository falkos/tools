#!/bin/bash
#
# Autor: Falko Saller
# Version: 0.5
# Date: 06.10.2017
#
#
# This Script will download the Config of a Pfsense Firewall. 
# If the new Config different the old one will replaced. 
# 
# Exit-Code 1 means something is wrong
#


# IP and Port of the Firewall
PFSENSE_IP="192.168.0.1:8080"

# Admin User-Account
PFSENSE_USER="admin"

# Password of the User
PFSENSE_PASSWORD="pfsense"

# Save location of the Old Config-File
PFSENS_CONFIGFILE="/tmp/config-pfsense.xml"

# Location of the tmp Config-File
PFSENS_CONFIGFILE_DOWNLOAD="/tmp/config-pfsense_tmp.xml"


#Create the tmp Folder for the cookies and so
mkdir -p /tmp/pfsens_config_downloader/
if [ $? -ne 0 ]
then

	echo "ERROR: Failed to crate tmp Folder"
	exit 1

fi 

# Remove the old cookies and tmp Files
rm -f /tmp/pfsens_config_downloader/*
if [ $? -ne 0 ]
then

	echo "ERROR: Failed to remove old tmp Files"
	exit 1

fi 

# Get the cookie
wget -qO- --keep-session-cookies --save-cookies /tmp/pfsens_config_downloader/cookies.txt --no-check-certificate https://$PFSENSE_IP/diag_backup.php | grep "name='__csrf_magic'" | sed 's/.*value="\(.*\)".*/\1/' > /tmp/pfsens_config_downloader/csrf.txt
if [ $? -ne 0 ]
then

	echo "Error: Cann't create cookie"
	exit 1

fi 

# Failed to send Login infos
wget -qO- --keep-session-cookies --load-cookies /tmp/pfsens_config_downloader/cookies.txt --save-cookies /tmp/pfsens_config_downloader/cookies.txt --no-check-certificate --post-data "login=Login&usernamefld=$PFSENSE_USER&passwordfld=$PFSENSE_PASSWORD&__csrf_magic=$(cat /tmp/pfsens_config_downloader/csrf.txt)" https://$PFSENSE_IP/diag_backup.php  | grep "name='__csrf_magic'" | sed 's/.*value="\(.*\)".*/\1/' > /tmp/pfsens_config_downloader/csrf2.txt
if [ $? -ne 0 ]
then

	echo "Error: Cann't send Login informations."
	exit 1

fi 

# Cann't download the Config File
wget --keep-session-cookies --load-cookies /tmp/pfsens_config_downloader/cookies.txt --no-check-certificate --post-data "download=download&donotbackuprrd=yes&__csrf_magic=$(head -n 1 /tmp/pfsens_config_downloader/csrf2.txt)" https://$PFSENSE_IP/diag_backup.php -O $PFSENS_CONFIGFILE_DOWNLOAD
if [ $? -ne 0 ]
then

	echo "Download of the Config-File failed"
	exit 1

fi 

# If the tmp Config File exist? 
if [ ! -f $PFSENS_CONFIGFILE_DOWNLOAD ]
then

	echo "ERROR: File dosn't exist"
	exit 1

fi 

# If the Login 
cat $PFSENS_CONFIGFILE_DOWNLOAD |grep 'Username or Password incorrect' >> /dev/null
if [ $? -ne 1 ]
then

	echo "ERROR: Username or Password incorrect"
	exit 1

fi 

# Create the Hash of the Config-Files
HASH_CONFIGFILE=$(openssl dgst -sha512 $PFSENS_CONFIGFILE | cut -d \  -f 2)
if [ $? -ne 0 ]
then

	echo "Error: Failed to create the Hash (Config)"
	exit 1

fi 

# Create the Hash of the tmp Config-Files
HASH_CONFIGFILE_DOWNLOAD=$(openssl dgst -sha512 $PFSENS_CONFIGFILE_DOWNLOAD | cut -d \  -f 2)
if [ $? -ne 0 ]
then

	echo "Error: Failed to create the Hash (tmp Config)"
	exit 1

fi 

# Are the Hash's equal?
if [ "$HASH_CONFIGFILE" == "$HASH_CONFIGFILE_DOWNLOAD" ]
then

	# No new Version of the Config
	echo "Info: Alk ok, nothing new"
	exit 0 

else 

	# New Version of the Config file! 
	cp $PFSENS_CONFIGFILE_DOWNLOAD $PFSENS_CONFIGFILE
	echo "Info: New Version of the File copied"
	exit 0

fi