#!/bin/bash

export BASEHTML="/srv/wow/trinitycore/3.3.5a"
export DOCROOT="/srv/wow/trinitycore/3.3.5a"
export GRPID=1000
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



# Setup Drupal if services.yml or settings.php is missing
if (! grep -q 'database.*=>.*drupal' ${DOCROOT}/sites/default/settings.php 2>/dev/null); then
  # Generate random passwords
  DRUPAL_DB="drupal"
  DBPASS=$(grep password /etc/mysql/debian.cnf | head -n1 | awk '{print $3}')
  ROOT_PASSWORD=$(pwgen -c -n -1 12)
  DRUPAL_PASSWORD=$(pwgen -c -n -1 12)
  echo ${ROOT_PASSWORD} >/var/lib/mysql/mysql/mysql-root-pw.txt
  echo ${DRUPAL_PASSWORD} >/var/lib/mysql/mysql/drupal-db-pw.txt
  # Wait for mysql
  echo -n "Waiting for mysql "
  while ! mysqladmin status >/dev/null 2>&1; do
    echo -n .
    sleep 1
  done
  echo
  # Create and change MySQL creds
  mysqladmin -u root password ${ROOT_PASSWORD} 2>/dev/null
  echo -e "[client]\npassword=${ROOT_PASSWORD}\n" >/root/.my.cnf
  mysql -e \
    "CREATE USER 'debian-sys-maint'@'localhost' IDENTIFIED WITH mysql_native_password BY '${DBPASS}';
         GRANT ALL ON *.* TO 'debian-sys-maint'@'localhost';
         CREATE DATABASE ${DRUPAL_DB};
         CREATE USER 'drupal'@'%' IDENTIFIED WITH mysql_native_password BY '${DRUPAL_PASSWORD}';
         GRANT ALL ON ${DRUPAL_DB}.* TO 'drupal'@'%';
         FLUSH PRIVILEGES;"
else
  echo "**** ${DOCROOT}/sites/default/settings.php database found ****"
  ROOT_PASSWORD=$(cat /var/lib/mysql/mysql/mysql-root-pw.txt)
  DRUPAL_PASSWORD=$(cat /var/lib/mysql/mysql/drupal-db-pw.txt)
fi

# Change root password
echo "root:${ROOT_PASSWORD}" | chpasswd

# Clear caches and reset files perms
XDEBUG_LOG=/tmp/xdebug.log
XDEBUG_HOST=`netstat -nr | grep '^0\.0\.0\.0' | awk '{print $2}'`
sed -i "s/XDEBUG_HOST/$XDEBUG_HOST/" /etc/php/7.4/mods-available/xdebug.ini
touch $XDEBUG_LOG
chown www-data:${GRPID} $XDEBUG_LOG
chmod ugo+rw $XDEBUG_LOG
chown -R www-data:${GRPID} ${DOCROOT}/sites/default/
chmod -R ug+w ${DOCROOT}/sites/default/
chown -R mysql:${GRPID} /var/lib/mysql/
chmod -R ug+w /var/lib/mysql/
find -type d -exec chmod +xr {} \;
(
  sleep 3
  drush --root=${DOCROOT}/ cache-rebuild 2>/dev/null
) &

echo
echo "---------------------- USERS CREDENTIALS ($(date +%T)) -------------------------------"
echo
echo "    DRUPAL:  http://${LOCAL_IP}              with user/pass: admin/admin"
echo
echo "    MYSQL :  http://${LOCAL_IP}/adminer.php  drupal/${DRUPAL_PASSWORD} or root/${ROOT_PASSWORD}"
echo "    SSH   :  ssh root@${LOCAL_IP}            with user/pass: root/${ROOT_PASSWORD}"
echo
echo "  Please report any issues to https://github.com/ricardoamaro/drupal9-docker-app"
echo "  USE CTRL+C TO STOP THIS APP"
echo
echo "------------------------------ STARTING SERVICES ---------------------------------------"

tail -f /tmp/supervisord.log
