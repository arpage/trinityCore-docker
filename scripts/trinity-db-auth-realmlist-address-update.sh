#!/bin/bash

TRINITY_PASSWORD=$(cat /var/trinityscripts/tpwd)

FILE=/var/trinityscripts/auth-realmlist-address.sql

if [ -f $FILE ]; then
    cat $FILE | mysql -u trinity -p${TRINITY_PASSWORD} auth
else
    echo "File not found: $FILE"
fi
