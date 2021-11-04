#!/bin/bash

# include parse_yaml function and read params
. lib/parse_yaml.sh
create_variables debloy.yml

#variables 
D_ENV=${environment,,}
WEB_FOLDER="/var/www/html/stage/stage.neosurf.africa"

GIT_BASE_FOLDER="/var/repo"
DEPLOY_GIT_FOLDER="${GIT_BASE_FOLDER}/${D_ENV}"

DOMAIN_NAME_VARIABLE="webserver_domain_name_${D_ENV}"
DOMAIN_NAME="${!DOMAIN_NAME_VARIABLE}"

DEPLOY_GIT_REPO_NAME="${D_ENV}.${DOMAIN_NAME}.git" 
POST_RECEIVE_HOOK_PATH="${DEPLOY_GIT_REPO_NAME}/hooks/post-receive"

NGINX_HOST_FILE_PATH="/etc/nginx/sites-available/${DOMAIN_NAME}"
NGINX_ENABLED_SITES_PATH="/etc/nginx/sites-enabled/"

ENV_TEMPLATE_URL= "https://raw.githubusercontent.com/laravel/laravel/v${laravel_version}/.env.example"
ENV_FILE_DEPLOY_PATH= "${WEB_FOLDER}/.env"
LARAVEL_APP_KEY_NOT_GENERATED_FILEPATH="${WEB_FOLDER}/.appkey_notgenerated"


# CREATE GIT BARE REPO
setfacl -R -m u:$server_username:rwx $DEPLOY_GIT_FOLDER
cd $DEPLOY_GIT_FOLDER
git init --bare $DEPLOY_GIT_REPO_NAME

# SET UP GIT POST-RECEIVE HOOK DEOKYMENT
touch $POST_RECEIVE_HOOK_PATH
sudo chmod +x $POST_RECEIVE_HOOK_PATH

# configure post-receive hook
bash -c "cat debloy/stubs/post-receive-hook >> $POST_RECEIVE_HOOK_PATH"
sed -i "s/WEBDIRVALUE/${WEB_FOLDER}/" "$POST_RECEIVE_HOOK_PATH"
sed -i "s/GITDIRVALUE/${DEPLOY_GIT_FOLDER}/" "$POST_RECEIVE_HOOK_PATH"

# CREATE WED FOLDER

sudo mkdir $WEB_FOLDER

# SET WEB FOLDER OWNER TO WWW-DATA
sudo chown -R www-data:www-data $WEB_FOLDER

# SET PROPER WEB FOLDER PERMISSIONS
setfacl -R -m u:$server_username:rwx $WEB_FOLDER

# GIVE ADMIN USER PERMISSIONS
sudo setfacl -R -m u:${server_username}:rwx $WEB_FOLDER


# CREATE NGINX HOST FILE
sudo touch $NGINX_HOST_FILE_PATH
sudo bash -c "cat debloy/stubs/nginx-host >> $NGINX_HOST_FILE_PATH"

sudo sed -i "s/SERVERNAMEVALUE/${DOMAIN_NAME}/" "$NGINX_HOST_FILE_PATH"
sudo sed -i "s/ROOTDIRVALUE/${WEB_FOLDER}/" "$NGINX_HOST_FILE_PATH"
sudo sed -i "s/PHPFPMSOCKVALUE/${php_fpm_sock}/" "$NGINX_HOST_FILE_PATH"

# TEST NGINX, activate hosts AND RESTART SERVICE
NGINX_TEST= `sudo nginx -t`

if [[ $NGINX_TEST =~ "successful" ]]; then
  echo "Nginx config is ok, deploying site and restarting service"
  sudo ln -s $NGINX_HOST_FILE_PATH $NGINX_ENABLED_SITES_PATH
  sudo service nginx stop && sudo service nginx start
  echo "Site enabled successfully"
else
  echo "Nginx config is not ok, not deploying site"
fi

# CREATE DATABASE, CREATE DATABASE USERNAME AND SET PASSWORD
if [ -d /var/lib/mysql/databasename ] ; then 
   echo "database already exists, cannot create database"
else
   echo "creating database"
   mysql -u root <<MYSQL_SCRIPT
   CREATE DATABASE $database_dbname;
   CREATE USER '$database_user'@'localhost' IDENTIFIED BY '$database_password';
   GRANT ALL PRIVILEGES ON $database_dbname.* TO '$database_user'@'localhost';
   FLUSH PRIVILEGES;
MYSQL_SCRIPT
fi

# ADD .ENV FILE TO WEB FOLDER WITH CORRESPONDING 
if curl -s --head  --request GET $ENV_TEMPLATE_URL | grep "200 OK" > /dev/null; then 
   echo ".env.example template found for laravel version (${laravel_version}), retrieving it an updating it"
   sudo touch $ENV_FILE_DEPLOY_PATH
   ENVTEMPLATE=`curl -L $ENV_TEMPLATE_URL`
   cat $ENVTEMPLATE >> $ENV_FILE_DEPLOY_PATH

   sed -i "s/APP_NAME=Laravel/${WEB_FOLDER}/" "$ENV_FILE_DEPLOY_PATH"
   sed -i "s/APP_ENV=local/APP_ENV=${D_ENV}/" "$ENV_FILE_DEPLOY_PATH"
   sed -i "s/APP_URL=http://localhost/APP_URL=https${DOMAIN_NAME}/" "$ENV_FILE_DEPLOY_PATH"
   sed -i "s/DB_DATABASE=laravel/DB_DATABASE=${database_dbname}/" "$ENV_FILE_DEPLOY_PATH"
   sed -i "s/DB_USERNAME=root/DB_USERNAME=${database_user}/" "$ENV_FILE_DEPLOY_PATH"
   sed -i "s/DB_PASSWORD=/DB_PASSWORD=${database_password}/" "$ENV_FILE_DEPLOY_PATH"

   #notify that laravel app key was not yet generated
   sudo touch $LARAVEL_APP_KEY_NOT_GENERATED_FILEPATH

else
   echo ".env.example template of provided laravel version(${laravel_version}) could not be retrieved from (${ENV_TEMPLATE_URL})"
fi
