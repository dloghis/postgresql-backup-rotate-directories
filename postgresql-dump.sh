#!/bin/bash

#-----------------------------------------------------------------------------------------
# This is a script to backup all your databases separately and delete old directories
# It is developed from dloghis (if you like it please leave the comment)
# Name your script "postgresql-dump.sh" and place your script the directory /root/cron-scripts/
# Add the following two lines in cron without the comment sign "#" for every day backup
#
# MAILTO=user@yourdomain.gr
# 0 4 * * * /root/cron-scripts/postgresql-dump.sh
#-----------------------------------------------------------------------------------------

# Remember if someone can read your script he will know the MySQL root password
SERVERIP=$(hostname -i)                 # Your Server IP
SERVERHOSTNAME=$(hostname -A)           # Your Server Host Name just for info if you have multiple servers (-A long , -s sort hostname)
DB_BACKUP="/root/db_backup"             # Dir for backup files like this "/root/db_backup"
TMP=$DB_BACKUP/tmp                      # Temp folder where databases are dumped
DB_USER="postgres"                      # PSQL user name usally root for all dbs
DB_PASSWD="xxxxxxxxxxxx"                # Password of mySQL
adate=$(date +%Y-%m-%d_%H:%M:%S)        # Time that script starts
daily_date=$(date +%Y-%m-%d)            # Destination folder names
month_day=$(date +%d)                   # Get current day of month
week_day=$(date +%u)                    # Get current day of week (1..7) 1 is Monday

# Choose how many days you are keeping backups
daily="14"                              # delete daily backup older than 14 days
weekly="63"                             # delete weekly backup older than 9 weeks
monthly="186"                           # delete monthly backup older than 6 months

# Dump parameters in order to avoid mysql go offline
COMMAND01="--single-transaction --quick --lock-tables=false"


# Title and Version 
echo "*=============================*"
echo "*    PostgreSQL Dump V-20180116    *"
echo "*=============================*"

echo "Server Name: "$SERVERHOSTNAME "IP: "$SERVERIP
echo "is starting script at: "$adate
echo ""

# Uncomment this 4 lines whenever you want your script to wait 10sec
# for a in `seq 1 10`; do
#    echo "please wait...$a/10 " 
#    sleep 1;
# done

# Make dir to dump datadases
mkdir -p $TMP/$daily_date
# mkdir -p $DB_BACKUP/backup-monthly/
# mkdir -p $DB_BACKUP/backup-weekly/
# mkdir -p $DB_BACKUP/backup-daily/

# Starting dump
# POSTGRES DATABASES ----------------------------------------------------------------

# For linux make file with username and password
# nano ~/.pgpass (and place below line)
# *:5432:*:username:password
# chmod 0600 ~/.pgpass

echo ""
echo "Dumping Postgres dbs... in $TMP/$daily_date"

date=`date +%Y-%m-%d_%H.%M`

databases=`/usr/bin/psql -h localhost -U $DB_USER -q -c "\l" | sed -n 4,/\eof/p | grep -v rows\) | grep -v template0 | grep -v template1 | grep [0-9] | awk '{print $1}'`

for s in $databases; 
do
      /usr/bin/vacuumdb -z -h localhost -U $DB_USER $s >/dev/null 2>&1

      /usr/bin/pg_dump -U $DB_USER -h 127.0.0.1 $s -f $TMP/$daily_date/$s-$date.sql -C
      
      echo "Dumped $s"
done

echo "Postgres Databases Dumped ok"
# POSTGRES DATABASES END -------------------------------------------------------------

# move them to the appropriate folder
# On day 1 of current month do
if [ "$month_day" -eq 1 ] ; then
  destination=$DB_BACKUP/backup-monthly/
else
  # On saturdays do
  if [ "$week_day" -eq 6 ] ; then
    destination=$DB_BACKUP/backup-weekly/
  else
    # On any other day do
    destination=$DB_BACKUP/backup-daily/
  fi
fi

echo ""
echo "Moving Directory "$TMP/$daily_date" to "$destination
echo ""

# This rsync is to keep multiple dumps in a day
rsync -av --remove-source-files $TMP/$daily_date $destination
echo ""

rm -rfv $TMP/$daily_date
echo ""

echo "Deleting old Directories in "$DB_BACKUP/backup-daily/
# daily
find $DB_BACKUP/backup-daily/ -maxdepth 1 -mtime +$daily -type d -exec rm -rv {} \;
echo ""

echo "Deleting old Directories in "$DB_BACKUP/backup-weekly/
# weekly
find $DB_BACKUP/backup-weekly/ -maxdepth 1 -mtime +$weekly -type d -exec rm -rv {} \;
echo ""

echo "Deleting old Directories in "$DB_BACKUP/backup-monthly/
# monthly
find $DB_BACKUP/backup-monthly/ -maxdepth 1 -mtime +$monthly -type d -exec rm -rv {} \;
echo ""

# It's nice to have after a big dump clean memory, uncomment if you want it (read your OS Doc)
echo "Dropping Memory Cashe... is OFF"
# sync && echo 3 > /proc/sys/vm/drop_caches
echo ""

# It's nice to know after a big dump how much storage you have
echo "Your Disk space !!! is:"
df -h
echo ""

bdate=$(date +%Y-%m-%d_%H:%M:%S)          # Info for end time
echo "Job  Start  in:     "$adate
echo "All Done! End time: "$bdate         # Just to know how long it took
