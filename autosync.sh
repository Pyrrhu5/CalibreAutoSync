#!/usr/bin/env bash


# ==============================================================================
#                                    SETTINGS
# ==============================================================================
# The path to Calibre's library root directory
EBOOK_ROOT="/home/pi/md0/Ebooks"
# The path and filename of the logs of the script
LOG="/home/pi/logs/ebook_sync.log"
# File to store the last sync date
# A full path can be provided or it will be stored on the script root path
SYNC_F="last.dat"
# Mount point of the e-reader
EREADER="/mnt/ebook/"
# Increase verbosity
IS_DEBUG=1

now=`date +"%Y-%m-%d %H:%M:%S"`
echo "=====" $now "=====" | tee $LOG


mount $EREADER

set -e
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

if [ $IS_DEBUG ]; then
	echo "DEBUG - Query: $query" | tee $LOG
fi


# ==============================================================================
#                               FETCH EBOOKS LIST
# ==============================================================================

IFS=$'\n'
read -a rows <<< $(sqlite3 $EBOOK_ROOT/metadata.db "$query")

sqlite3 $EBOOK_ROOT/metadata.db "$query" | while read -a r 
do
	# ==========================================================================
	#                                COPY EBOOKS
	# ==========================================================================
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

echo "INFO - Done." | tee $LOG
# Reset the string separator
IFS=" "