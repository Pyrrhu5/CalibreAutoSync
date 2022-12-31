#!/usr/bin/env bash


# ==============================================================================
#                                    SETTINGS
# ==============================================================================
# Absolute root path of the directory
SCRIPT_DIR=`dirname $0`
# The path to Calibre's library root directory
EBOOK_ROOT="/home/pi/md0/Ebooks"
# The path and filename of the logs of the script
LOG="/home/pi/logs/ebook_sync.log"
# File to store the last sync date
# A full path can be provided or it will be stored on the script root path
SYNC_F="$SCRIPT_DIR/last.dat"
# Mount point of the e-reader
EREADER="/mnt/ebook"
EREADER_PATH="/dev/disk/by-label/KOBOeReader"
# Is it a remarkable tablet?
IS_REMARKABLE=1
REMARKABLE_IP="10.11.99.1"
# Which sound to be played after completion of the script
# leave "" if no sound wanted
ALERT="$SCRIPT_DIR/alert.wav"

now=`date +"%Y-%m-%d %H:%M:%S"`


echo "=====" $now "=====" | tee -a $LOG

if [ $IS_REMARKABLE -eq 0 ]; then
    # Tries to mount the ereader 5 times
    limitTries=5
    nTries=1
    while [ $nTries -le $limitTries ]
    do
        if  mount | grep $EREADER > /dev/null; then
            echo "INFO - Ereader $EREADER mounted on try $nTries" | tee -a $LOG
            isMounted=1
            break
        else
            sudo mount $EREADER_PATH $EREADER
            ((nTries++))
            isMounted=0
            sleep 15
            continue
        fi
    done
    if [ $isMounted -eq 0 ]; then
        echo "ERROR - After $nTries tries the ebook $EREADER is still not mounted. Bye." | tee -a $LOG
        exit
    fi
fi
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
	echo "INFO - Last sync was $lastSync" | tee -a $LOG
else
	echo "INFO - First sync" | tee -a $LOG
fi

# ==============================================================================
#                               TRANSFER EBOOKS
# ==============================================================================

IFS=$'\n'

sqlite3 $EBOOK_ROOT/metadata.db "$query" | while read -a r 
do
	if [ -f "$r" ]; then
		echo "INFO - Transfering: $r" | tee -a $LOG
        if [ $IS_REMARKABLE -eq 0 ]; then
            sudo cp "$r" $EREADER
        else
            curl "http://$REMARKABLE_IP/upload" \
                -H "Origin: http://$REMARKABLE_IP" \
                -H "Accept: */*" \
                -H "Referer: http://$REMARKABLE_IP/" \
                -H 'Connection: keep-alive' \
                -F "file=@$r;filename=$(basename $r);type=$(file $r --mime-type -b)"
            echo
        fi
	else
		echo "ERROR - That's not a file: $r" | tee -a $LOG
	fi
done

# ==============================================================================
#                                    CLEAN-UP
# ==============================================================================
if [ $IS_REMARKABLE -eq 0 ]; then
    # Don't unmount until all transfers are done
    wait $!
    sudo umount $EREADER
fi

echo $now > $SYNC_F

if [ -f $ALERT ]; then
	aplay $ALERT >/dev/null
fi

# Reset the string separator
IFS=" "

echo "INFO - Done." | tee -a $LOG
exit 0
