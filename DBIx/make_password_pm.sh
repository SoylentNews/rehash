#!/bin/sh
sed -e "s:\$MYSQL_HOST:$1:" -e "s:\$MYSQL_DATABASE:$2:" -e "s:\$MYSQL_USERNAME:$3:" -e "s:\$MYSQL_PASSWORD:$4:" Password.pm.in 