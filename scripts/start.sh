#!/bin/bash

export BASEHTML="/srv/wow/trinitycore/3.3.5a"
export DOCROOT="/srv/wow/trinitycore/3.3.5a"
export LOCAL_IP=$(hostname -I | awk '{print $1}')
export HOSTIP=$(/sbin/ip route | awk '/default/ { print $3 }')

echo "${HOSTIP} dockerhost" >>/etc/hosts

#
# 0. copy sql create file.
# 1. copy sql import files
# 2. create trinity passwd.
# 3. sed passwd in sql create file.
# 4. sed passwd in worldserver.conf.
# 5. sed passwd in authserver.conf.
# 6. run sql create file.
# 7. run sql import files.
#

#if [ ! -f /var/trinityscripts/create_mysql.sql ]; then
if [ z != z ]; then
  cp /srv/wow/trinitycore/3.3.5a/sql/create/create_mysql.sql /var/trinityscripts
  TRINITY_PASSWORD=$(cat /var/trinityscripts/tpwd)
  sed -i "s/ED BY 'trinity'/ED BY '${TRINITY_PASSWORD}'/" /var/trinityscripts/create_mysql.sql
  ROOT_PASSWORD=$(cat /var/trinityscripts/rpwd)
  cat /var/trinityscripts/create_mysql.sql | mysql -u root -p${ROOT_PASSWORD} -h trinity-db
  for f in local-sql/20*.sql; do
    bn=$(basename $f .sql)
    schema=$(echo $bn | cut -d '.' -f 2)
    echo "${f} > ${bn} > ${schema}"
    echo "cat $f | mysql -u trinity -p${TRINITY_PASSWORD} ${schema}"
  done
fi

echo
echo "---------------------- USERS CREDENTIALS ($(date +%T)) -------------------------------"
echo
echo "    ${LOCAL_IP}              with user/pass: trinity/${TRINITY_PASSWORD}"
echo "    ${LOCAL_IP}              with user/pass: root/${ROOT_PASSWORD}"
echo
echo "------------------------------ STARTING SERVICES ---------------------------------------"

tail -f /tmp/supervisord.log
