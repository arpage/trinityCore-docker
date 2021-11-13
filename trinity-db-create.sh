#!/bin/bash
cat /var/trinityscripts/create_mysql.sql | mysql -u root -p$(cat /var/trinityscripts/rpwd)
