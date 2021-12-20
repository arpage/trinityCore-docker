#!/bin/bash

TRINITY_PASSWORD=$(cat /var/trinityscripts/tpwd)

for f in /var/trinityscripts/*{auth,characters}.sql; do
  if [ -f $f ]; then
    bn=$(basename $f .sql)
    schema=$(echo $bn | cut -d '.' -f 2)
    sed 's/\sDEFINER=`[^`]*`@`[^`]*`//g' -i $f
    echo "${f} > ${bn} > ${schema}"
    cat $f | mysql -u trinity -p${TRINITY_PASSWORD} ${schema}
  else
    echo "File not found: $f"
  fi
done
