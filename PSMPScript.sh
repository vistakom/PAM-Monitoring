#!/bin/bash
################################## Create PSMP Script
BASEPATH="/var/opt/CARKpsmp/cron"
mkdir -p $BASEPATH
PSMPLOGS=$BASEPATH/psmplogs.chk
echo ""

if [ ! -f "$PSMPLOGS" ]; then
echo "***** Creating script to get concurrent session *****"
cat <<'EOF' > $BASEPATH/PSMPConcurrentSession.sh
#!/bin/bash
timestamp=$(date +"%Y-%m-%d %H-%M-%S") # get current datetime
count=$(who | awk '$1 ~ /@/ {count++} END {print count}') # count session where username contain "@"
if [ -z "$count" ]; then
    count=0
else
    count=$count
fi
# Write the result to the log file
echo "$timestamp; $count" >> /var/opt/CARKpsmp/cron/$(hostname)_concurrent_session_$(date +"%Y-%m").log
EOF

sleep 5

echo "***** Creating Log rotation mechanism *****"
cat <<'EOF' > $BASEPATH/logCleaner.sh
#!/bin/bash
age1=30 # Log files that are more than 30 day old will be compressed
age2=60 # Compressed file that are more than 60 day old will be deleted
declare -a dirs=("/var/opt/CARKpsmp/logs/old" "/var/opt/CARKpsmpadb/logs/old" "/var/opt/CARKpsmp/logs/components/old")

for d in "${dirs[@]}"
do
        date_string=$(date +"%Y%m%d_%H%M%S")
        find $d -name "*.log" -mtime +$age1 -print | xargs tar -czvPf $d/${date_string}_archive.tar.gz -C $d
        find $d -name "*.log" -mtime +$age1 -print -exec rm {} \;
done

for d in "${dirs[@]}"
do
        find $d -name "*_archive.tar.gz" -mtime +$age2 -exec rm {} \;
done

EOF

sleep 5

chmod 755 $BASEPATH/PSMPConcurrentSession.sh
chmod 755 $BASEPATH/logCleaner.sh

################################## Create CronJob
echo ""
echo "***** Creating Cronjob task to get concurrent session hourly *****"
(crontab -l ; echo '0 * * * * '"$BASEPATH"'/PSMPConcurrentSession.sh') | crontab -

echo "***** Creating Cronjob task to run Log rotation mechanism daily at 04:00 *****"
(crontab -l ; echo '0 4 * * * '"$BASEPATH"'/logCleaner.sh') | crontab -

echo "PSMP Script Logs" >> $PSMPLOGS
echo "1. Create PSMPConcurrentSession.sh" >> $PSMPLOGS
echo "2. Create logCleaner.sh" >> $PSMPLOGS
echo "3. Create Cronjob " >> $PSMPLOGS
fi

echo "---- PSMP Script Setup Was Completed ----"
echo ""
