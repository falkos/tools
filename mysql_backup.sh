#!/bin/bash
#
# Autor: Falko Saller
# Version: 1.0
# Date: 10.04.2020
#
#
# This tool creates a mysql dump from the specified databases. 
# To save disk space, after each dump it checks (via sha512sum) if the new dump and the previous one are different.
#
# Exit-Code 1 means something is wrong
#

# Write the log output to Syslog
shopt -s expand_aliases
alias log_error='logger -t mysql_backup --id=$$ -p local0.err'
alias log_info='logger -t mysql_backup --id=$$ -p local0.info'

GLOBAL_DATE=$(date +"%Y%m%d_%H%M") # ISO Date for the Filename
GLOBAL_BACKUP_PATH="/mnt/usb_backup/mysql/" # Path to the Backup Dir
GLOBAL_BACKUP_MAX_COUNT=14 # Keep the last 14 Backup Versions

MYSQL_USER="<user>"
MYSQL_PASS="<pass>"
MYSQL_HOST="<host>"
MYSQL_DBs="<database> <database>"

NEW_BACKUP_FILEPATH=${GLOBAL_BACKUP_PATH}${MYSQL_DBs// /-}_${GLOBAL_DATE}.sql # Create the Filename for the MySQL-Dump

log_info "Start mySQL Backup"
mysqldump --user=${MYSQL_USER} --password=${MYSQL_PASS} --host=${MYSQL_HOST} --databases ${MYSQL_DBs} --skip-dump-date  > ${NEW_BACKUP_FILEPATH}
EXITSTATUS=${PIPESTATUS[0]}
if [ "$EXITSTATUS" -ne "0" ] # If the bin mysqldump not found or a error was returned
then 
	log_error "ERROR when backing up ${MYSQL_HOST}!"
	exit 1
fi


log_info "Run Deduplicate-Check ..."

# Calc the sha512 Hash from the new Backup-File and from the previous version 
NEW_BACKUP_HASH=$(sha512sum ${NEW_BACKUP_FILEPATH} | cut -d" " -f1)
LAST_BACKUP_HASH=""
LAST_BACKUP_FILEPATH=$(ls -t ${GLOBAL_BACKUP_PATH}${MYSQL_DBs// /-}_*.sql | head -2 | tail -1)

if [ -f ${LAST_BACKUP_FILEPATH} ] && [ "$NEW_BACKUP_FILEPATH" != "$LAST_BACKUP_FILEPATH" ] 
then

	log_info "Older Backup file found, calc the Hash. - ${LAST_BACKUP_FILEPATH} "
	LAST_BACKUP_HASH=$(sha512sum ${LAST_BACKUP_FILEPATH} | cut -d" " -f1)

fi

# Compare the hash values; if they are equal, delete the older file
if [ ! -z $LAST_BACKUP_HASH ] && [ "$NEW_BACKUP_HASH" = "$LAST_BACKUP_HASH" ]; then

	log_info "The Hash is equal, deduplicate the older file - $LAST_BACKUP_FILEPATH "
	rm $LAST_BACKUP_FILEPATH
	if [ "$?" -ne "0" ]
	then
		log_error "Failed to remove the file $LAST_BACKUP_FILEPATH"	
		exit 1
	fi

fi

log_info "Cleanup... "
backup_count=0
# Check if there min one File to check
if [ "$(2>/dev/null ls -1 ${GLOBAL_BACKUP_PATH}${MYSQL_DBs// /-}_*.sql | wc -l)" -gt "0" ]
then

   # List the Backups by time
	for ls in `ls -t ${GLOBAL_BACKUP_PATH}${MYSQL_DBs// /-}_*.sql`; do 

		backup_count=$((backup_count+1))
		if [ "$backup_count" -gt "$GLOBAL_BACKUP_MAX_COUNT" ]
		then

			log_error "Cleanup old Backup file $ls"
         rm $ls
			if [ "$?" -ne "0" ]
			then
				log_error "Failed to remove the file $ls"
				exit 1
			fi

		fi

	done

else

	log_info "No File to Cleanup found."

fi


