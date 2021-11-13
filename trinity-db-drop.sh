#!/bin/bash
cat /var/trinityscripts/drop_mysql.sql | mysql -u root -p$(cat /var/trinityscripts/rpwd)
