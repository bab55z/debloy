#!/usr/bin/env bash

mysql_create_database() {
 local dbname=$1
 local username=$2
 local password=$3

 echo "Creating MySQL user and database"
 if [ -z "$2" ]; then
   PASS=`openssl rand -base64 8`
 fi

 mysql -u root <<MYSQL_SCRIPT
 CREATE DATABASE $dbname;
 CREATE USER '$username'@'localhost' IDENTIFIED BY '$password';
 GRANT ALL PRIVILEGES ON $dbname.* TO '$username'@'localhost';
 FLUSH PRIVILEGES;
 MYSQL_SCRIPT

 echo "MySQL user and database created."
 echo "Username:   $username"
 echo "Database:   $dbname"
 echo "Password:   $password"
}
