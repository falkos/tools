#!/bin/bash
#
# Autor: Falko Saller
# Version: 1.0
# Date: 11.04.2020
#
#
# This tool creates a Backup (tar.bz2)
# To save disk space, after each backup it checks (via sha512sum) if the new file and the previous one are different.
#
# Usage: file_backup.sh /Source/Dir/ /Target/Dir/
#
# Exit-Code 1 means something is wrong
#

# Write the log output to Syslog
shopt -s expand_aliases
alias log_error='logger -t file_backup --id=$$ -p local0.err'
alias log_info='logger -t file_backup --id=$$ -p local0.info'

GLOBAL_DATE=$(date +"%Y%m%d_%H%M") # ISO Date for the Filename
GLOBAL_BACKUP_MAX_COUNT=14 # Keep the last 14 Backup Versions


log_info "Start File-Backup"

# Check the parameters
if [[ -d $1 ]]; then
   BACKUP_NAME=$(basename $1) # Set the Backup-Name
   BACKUP_NAME=${BACKUP_NAME// /-} # Remove all spaces
   BACKUP_SOURCE_PATH=$1
else
   log_error "ERROR Source (${1}) is not a directory!"
   echo "ERROR Source (${1}) is not a directory!"
   exit 1
fi

if [[ -d $2 ]]; then
   BACKUP_TARGET_PATH="$(dirname ${2})/$(basename ${2})/" # 
   BACKUP_TARGET_FILE="${BACKUP_TARGET_PATH}${BACKUP_NAME}_${GLOBAL_DATE}.tar.bz2"
   BACKUP_TARGET_HASHFILE="${BACKUP_TARGET_FILE}.sha512"

else
   log_error "ERROR Target (${2}) is not a directory!"
   echo "ERROR Target (${2}) is not a directory!"
   exit 1
fi

# Create the Backup file
tar cjf ${BACKUP_TARGET_FILE} ${BACKUP_SOURCE_PATH}
if [ "$?" -ne "0" ]
then
   log_error "Failed to create the Backup!" 
   exit 1
fi

# Calc the sha512 Hash from the Backup file
sha512sum ${BACKUP_TARGET_FILE} > ${BACKUP_TARGET_HASHFILE}
if [ "$?" -ne "0" ]
then
   log_error "Failed to create the Hash!" 
   exit 1
else
   NEW_BACKUP_HASH=$(cat ${BACKUP_TARGET_HASHFILE} | cut -d" " -f1 | head -1) # extract the new hash
fi

# select the last sha512 file, as only a backup with a sha512 file is valid
LAST_BACKUP_HASHFILE=$(ls -t ${BACKUP_TARGET_PATH}${BACKUP_NAME}_*.tar.bz2.sha512 | head -2 | tail -1)
if [ -f ${LAST_BACKUP_HASHFILE} ] && [ "$BACKUP_TARGET_HASHFILE" != "$LAST_BACKUP_HASHFILE" ] 
then

   log_info "Older Backup-Hash file found, extract the Hash. - ${LAST_BACKUP_HASHFILE} "
   LAST_BACKUP_HASH=$(cat ${LAST_BACKUP_HASHFILE} | cut -d" " -f1 | head -1)
   LAST_BACKUP_FILE=$(cat ${LAST_BACKUP_HASHFILE} | cut -d" " -f3 | head -1)

fi

# Compare the hash values; if they are equal, delete the older file
if [ ! -z $LAST_BACKUP_HASH ] && [ "$NEW_BACKUP_HASH" = "$LAST_BACKUP_HASH" ]; then

   log_info "The Hash is equal, deduplicate the older Hash and Backup-File - $LAST_BACKUP_HASHFILE | $LAST_BACKUP_FILE "
   rm $LAST_BACKUP_HASHFILE
   if [ "$?" -ne "0" ]
   then
      log_error "Failed to remove the Hash-File $LAST_BACKUP_HASHFILE" 
      exit 1
   fi

   rm $LAST_BACKUP_FILE
   if [ "$?" -ne "0" ]
   then
      log_error "Failed to remove the Backup-File $LAST_BACKUP_FILE" 
      exit 1
   fi

fi

log_info "Cleanup... "
backup_count=0

# List the Hash Files from the Backups by time
for ls in `ls -t ${BACKUP_TARGET_PATH}${BACKUP_NAME}_*.tar.bz2.sha512`; do 

   backup_count=$((backup_count+1))
   if [ "$backup_count" -gt "$GLOBAL_BACKUP_MAX_COUNT" ]
   then

      OBSOLET_BACKUP_FILE=$(cat $ls | cut -d" " -f3 | head -1)
      log_info "Remove old Backup file: $OBSOLET_BACKUP_FILE"
      rm $OBSOLET_BACKUP_FILE
      if [ "$?" -ne "0" ]
      then
         log_error "Failed to remove the Backup file $OBSOLET_BACKUP_FILE"
         exit 1
      fi

      log_info "Remove old Hash file: $ls"
      rm $ls
      if [ "$?" -ne "0" ]
      then
         log_error "Failed to remove the Hash file $ls"
         exit 1
      fi

   fi

done

exit 0
