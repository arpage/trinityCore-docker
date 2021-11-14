#!/bin/bash
#echo="echo"

RTS=$(date +"%Y%m%d%H%M%N")
ROOT_PASSWORD=$(cat /var/trinityscripts/rpwd)

for schema in auth characters world; do
  echo dumping $schema to /var/trinityscripts/"${RTS}.${schema}.sql"
  $echo mysqldump \
     -u root --password="${ROOT_PASSWORD}" \
     --skip-lock-tables \
     --flush-logs \
     --all-tablespaces \
     --create-options \
     --flush-privileges \
     $schema > /var/trinityscripts/"${RTS}.${schema}.sql"
done
