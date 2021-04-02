#!/usr/bin/env bash


# ==============================================================================
#                                    SETTINGS
# ==============================================================================
# Absolute root path of the directory
SCRIPT_DIR=$(cd `dirname $0` && PWD)
# The path to Calibre's library root directory
EBOOK_ROOT="/home/pi/md0/Ebooks"
# The path and filename of the logs of the script
LOG="/home/pi/logs/ebook_sync.log"
# File to store the last sync date
# A full path can be provided or it will be stored on the script root path
SYNC_F="$SCRIPT_DIR/last.dat"
# Mount point of the e-reader
EREADER="/mnt/ebook/"
# Which sound to be played after completion of the script
# leave "" if no sound wanted
ALERT="$SCRIPT_DIR/alert.wav"
# Linux user to run the script as
USR="pi"

now=`date +"%Y-%m-%d %H:%M:%S"`

# exit on error
set -e

echo "=====" $now "=====" | tee $LOG


mount -a $EREADER

# ==============================================================================
#                                 PREPARE QUERY
# ==============================================================================


query="
SELECT
	'$EBOOK_ROOT/' || path || '/' || COALESCE(epub.name || '.epub', pdf.name || '.pdf')
FROM
	books
	LEFT JOIN data epub ON epub.book = books.id AND epub.format = 'EPUB'
	LEFT JOIN data pdf  ON pdf.book  = books.id AND pdf.format  = 'PDF' 
"

if [ -f $SYNC_F ]; then
	lastSync=`cat $SYNC_F`
	query=$query" WHERE timestamp > DATETIME('$lastSync')"
	echo "INFO - Last sync was $lastSync" | tee $LOG
else
	echo "INFO - First sync" | tee $LOG
fi

# ==============================================================================
#                               TRANSFER EBOOKS
# ==============================================================================

IFS=$'\n'
read -a rows <<< $(sqlite3 $EBOOK_ROOT/metadata.db "$query")

sqlite3 $EBOOK_ROOT/metadata.db "$query" | while read -a r 
do
	if [ -f "$r" ]; then
		echo "INFO - Transfering: $r" | tee $LOG
		cp "$r" $EREADER
	else
		echo "ERROR - That's not a file: $r" | tee $LOG
	fi
done

# ==============================================================================
#                                    CLEAN-UP
# ==============================================================================

umount $EREADER

echo $now > $SYNC_F

if [ -f $ALERT ]; then
	aplay $ALERT
fi

# Reset the string separator
IFS=" "

echo "INFO - Done." | tee $LOG
EOF
