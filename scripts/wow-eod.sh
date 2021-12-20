
#!/bin/sh
rundir=projects/trinityCore-docker

bs=$(ssh pk -t /home/ubuntu/$rundir/scripts/wotlk-stop.sh | \
         grep .auth.sql | sed -r "s#.*scripts/([0-9]+).auth.sql#\1#")

#BACKUP_STAMP=202112190930223603399
BACKUP_STAMP=$(echo $bs | tr -cd [:print:])

echo "Backup stamp: ${BACKUP_STAMP}"

scp pk:/home/ubuntu/$rundir/local-sql/${BACKUP_STAMP}.{auth,characters}.sql \
         ~/$rundir/local-sql/

aws ec2 stop-instances --instance-ids i-02c154a4703a33024

aws s3 sync ~/$rundir/local-sql/ s3://pk.straypacket.com/local-sql
