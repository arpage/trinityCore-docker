#!/bin/bash

export BASEHTML="/srv/wow/trinitycore/3.3.5a"
export DOCROOT="/srv/wow/trinitycore/3.3.5a"
export GRPID=1000
export LOCAL_IP=$(hostname -I | awk '{print $1}')
export HOSTIP=$(/sbin/ip route | awk '/default/ { print $3 }')

echo "${HOSTIP} dockerhost" >>/etc/hosts
echo "Started Container: $(date)"

# Create a basic mysql install
if [ ! -d /var/lib/mysql/mysql ]; then
  echo "**** No MySQL data found. Creating data on /var/lib/mysql/ ****"
  rm -rf /var/lib/mysql/*;
  /usr/sbin/mysqld --initialize-insecure
  sed -i 's/^bind-address/#bind-address/g' /etc/mysql/mysql.conf.d/mysqld.cnf;
  sed -i "s/Basic Settings/Basic Settings\ndefault-authentication-plugin=mysql_native_password\n/" /etc/mysql/mysql.conf.d/mysqld.cnf
else
  echo "**** MySQL data found on /var/lib/mysql/ ****"
fi

# Start supervisord
#supervisord -c /etc/supervisor/conf.d/supervisord.conf -l /tmp/supervisord.log

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
         CREATE DATABASE drupal;
         CREATE USER 'drupal'@'%' IDENTIFIED WITH mysql_native_password BY '${DRUPAL_PASSWORD}';
         GRANT ALL ON drupal.* TO 'drupal'@'%';
         FLUSH PRIVILEGES;"
  cd ${DOCROOT}
  cp sites/default/default.settings.php sites/default/settings.php
  cp sites/example.settings.local.php sites/default/settings.local.php
  ${DRUSH} site-install standard -y --account-name=admin --account-pass=admin \
    --db-url="mysql://drupal:${DRUPAL_PASSWORD}@localhost:3306/drupal" \
    --site-name="CAP Testing Services" | grep -v 'continue?' 2>/dev/null
  ${DRUSH} cr
  ${DRUSH} cset system.site uuid "6abb4f05-743c-4ed5-a90a-64c5fd121bca" -y
  ${DRUSH} scr clear_shortcut_set.php
  ${DRUSH} cim -y
  ${DRUSH} cr
  ${DRUSH} tome:import -y
  ${DRUSH} user:password admin "admin"
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
