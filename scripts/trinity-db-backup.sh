#!/bin/bash
echo=echo

RTS=$(date +"%Y%m%d")
TRINITY_PASSWORD=$(cat /var/trinityscripts/tpwd)

for schema in auth characters world; do
  $echo mysqldump \
     -u trinity --password=${TRINITY_PASSWORD} \
     --skip-lock-tables \
     --flush-logs \
     --all-tablespaces \
     --create-options \
     --flush-privileges \
     $schema > ${RTS}.${schema}.sql
done
