#!/bin/bash

DEBLOYROOT="/var/repo/debloy"
DEBLOYYAMLFILE="debloy.yml"
DBDUMPFILE=

PARAMS=""

while (( "$#" )); do
  case "$1" in
    -y|--yaml-file)
      if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
        DEBLOYYAMLFILE=$2
        shift 2
      else
        echo "Error: web directory argument for $1 is missing" >&2
        exit 1
      fi
      ;;
    -d|--database-dump-file)
      if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
        DBDUMPFILE=$2
        shift 2
      else
        echo "Error: git directory argument for $1 is missing" >&2
        exit 1
      fi
      ;;
    -h|--help)
      echo -e "\n\n\t\t\t\t----Debloy Help----\n"
      echo -e "\t IMPORTANT NOTICE: move to debloy script root folder before running debloy.sh  \n"
      echo -e "\t run debloy.sh with sudo (sudo debloy.sh -y stage-site-debloy.yml -d database-dump-file.sql)  \n"
      echo -e "\t-y, --yaml-file \t\t  config yaml file\n\t-d, --database-dump-file \t  database dump file"
      echo -e "\n\n"
      exit 0
      ;;
    -*|--*=) # unsupported flags
      echo "Error: Unsupported flag $1" >&2
      exit 1
      ;;
    *) # preserve positional arguments
      PARAMS="$PARAMS $1"
      shift
      ;;
  esac
done

# set positional arguments in their proper place
eval set -- "$PARAMS"

# include parse_yaml function and read params
. lib/parse_yaml.sh
create_variables $DEBLOYYAMLFILE

## TEST
#echo "debloy config file -> $DEBLOYYAMLFILE"
#echo "db dump file -> $DBDUMFILE"
#echo "site title -> ${site_name}"
#exit 0
## END TEST

#variables
echo "initializing variables"
D_ENV=${environment,,}

DEPLOY_GIT_FOLDER="$git_bare_root_folder/$git_bare_repo_name"

DOMAIN_NAME_VARIABLE="webserver_domain_name_${D_ENV}"
MAIN_DOMAIN_NAME="$webserver_domain_name_main"
DOMAIN_NAME="${!DOMAIN_NAME_VARIABLE}"

POST_RECEIVE_HOOK_PATH="${git_bare_repo_name}/hooks/post-receive"

NGINX_HOST_FILE_PATH="/etc/nginx/sites-available/${MAIN_DOMAIN_NAME}"
NGINX_ENABLED_SITES_PATH="/etc/nginx/sites-enabled/"

ENV_TEMPLATE_URL="https://raw.githubusercontent.com/laravel/laravel/v$laravel_version/.env.example"
ENV_FILE_DEPLOY_PATH="${webserver_folder}/.env"
LARAVEL_APP_KEY_NOT_GENERATED_FILEPATH="${webserver_folder}/.appkey_notgenerated"

#== CREATE GIT BARE REPO
echo "initializing git bare repository"
# shellcheck disable=SC2164
cd "$git_bare_root_folder"
git init --bare "$git_bare_repo_name"
setfacl -R -m u:"$server_username":rwx "$DEPLOY_GIT_FOLDER"
echo "initializing git bare repository done"

# SET UP GIT POST-RECEIVE HOOK DEPLOYMENT
echo "setting up git post receive hook"
touch "$POST_RECEIVE_HOOK_PATH"
sudo chmod +x "$POST_RECEIVE_HOOK_PATH"
echo "setting up git post receive hook done OK"

# configure post-receive hook
echo "configuring git post receive hook"
bash -c "cat ${DEBLOYROOT}/stubs/post-receive-hook >> $POST_RECEIVE_HOOK_PATH"
sed -i "s=WEBDIRVALUE=${webserver_folder}=" "$POST_RECEIVE_HOOK_PATH"
sed -i "s=GITDIRVALUE=${DEPLOY_GIT_FOLDER}=" "$POST_RECEIVE_HOOK_PATH"
sed -i "s=ADMINUSERNAMEVALUE=${server_username}=" "$POST_RECEIVE_HOOK_PATH"
sed -i "s=DEBLOYROOTVALUE=${DEBLOYROOT}=" "$POST_RECEIVE_HOOK_PATH"
echo "configuring git post receive hook done"
echo "add the remote git bare repository with the following git command "
echo "git remote add production ssh://$server_username@$server_hostname$DEPLOY_GIT_FOLDER"

#=== CREATE WED FOLDER
echo "creating web folder"
sudo mkdir "$webserver_folder"
echo "creating web folder done OK"

# SET WEB FOLDER OWNER TO WWW-DATA
echo "setting web folder owner to www-data"
sudo chown -R www-data:www-data "$webserver_folder"
echo "setting web folder owner to www-data done OK"

# GIVE ADMIN USER PERMISSIONS
echo "giving admin user proper permissions to web folder"
sudo setfacl -R -m u:"$server_username":rwx "$webserver_folder"
echo "giving admin user proper permissions to web folder done"

#=== CREATE NGINX HOST FILE
echo "creating nginx host file"
sudo touch "$NGINX_HOST_FILE_PATH"
sudo bash -c "cat ${DEBLOYROOT}/stubs/nginx-host >> $NGINX_HOST_FILE_PATH"
echo "creating nginx host file done OK"

echo "configuring nginx host file"
sudo sed -i "s=SERVERNAMEVALUE=${DOMAIN_NAME}=" "$NGINX_HOST_FILE_PATH"
sudo sed -i "s=ROOTDIRVALUE=${webserver_folder}/public=" "$NGINX_HOST_FILE_PATH"
sudo sed -i "s=PHPFPMSOCKVALUE=${php_fpm_sock}=" "$NGINX_HOST_FILE_PATH"
echo "configuring nginx host file OK"

# TEST NGINX, activate hosts AND RESTART SERVICE
echo "testing nginx configuration"

if sudo nginx -t 2>&1 | grep 'successful'; then
   echo "Nginx config is ok, deploying site and restarting service"
   sudo ln -s "$NGINX_HOST_FILE_PATH" $NGINX_ENABLED_SITES_PATH
   sudo service nginx stop && sudo service nginx start
   echo "enabled site OK"

   echo "setting up ssl certificate via certbot"
   sudo bash -c "sudo certbot run -n --nginx --agree-tos -d $MAIN_DOMAIN_NAME -m ${server_email} --redirect --no-eff-email"
   echo "SSL certificate setup done"

else
   echo "Nginx config is not ok, not deploying site"
fi
echo "testing nginx configuration done"

#=== CREATE DATABASE, CREATE DATABASE USERNAME AND SET PASSWORD
echo "setting up database"
if [ -d "/var/lib/mysql/$database_dbname" ] ; then
   echo "a database with the same name ($database_dbname) already exists, cannot create database"
else
   echo "creating database with name ($database_dbname)"
   sudo mysql -u root <<MYSQL_SCRIPT
   CREATE DATABASE $database_dbname;
   CREATE USER '$database_user'@'%' IDENTIFIED BY '$database_password';
   GRANT ALL PRIVILEGES ON $database_dbname.* TO '$database_user'@'%';
   FLUSH PRIVILEGES;
MYSQL_SCRIPT
  #Import database if provided
  if [ -f "$DBDUMPFILE" ]; then
    echo "importing database"
    #sudo mysql -u root "$database_dbname" < "$DBDUMPFILE"
    mysql -u "$database_user" -p"$database_password" "$database_dbname" < "$DBDUMPFILE"
  else
    echo "database dump file not provided or wrong path, not importing database"
  fi
fi

#=== ADD .ENV FILE TO WEB FOLDER WITH CORRESPONDING
echo "setting up app .env file"
#if curl -s --head  --request GET "$ENV_TEMPLATE_URL" | grep "200 OK" > /dev/null; then
if curl --write-out '%{http_code}' --silent --output /dev/null "$ENV_TEMPLATE_URL" | grep "200" > /dev/null; then
   echo ".env.example template found for laravel version (${laravel_version}), retrieving it an updating it"
   echo "creating $ENV_FILE_DEPLOY_PATH"
   sudo touch "$ENV_FILE_DEPLOY_PATH"
   ENVTEMPLATE=$(curl -L "$ENV_TEMPLATE_URL")
   #echo "$ENVTEMPLATE"
   echo "$ENVTEMPLATE" > "$ENV_FILE_DEPLOY_PATH"

   echo "configuring app .env file"
   sed -i "s@APP_NAME=Laravel@APP_NAME=\"${site_name}\"@" "$ENV_FILE_DEPLOY_PATH"
   sed -i "s@APP_ENV=local@APP_ENV=${D_ENV}@" "$ENV_FILE_DEPLOY_PATH"
   sed -i "s@APP_URL=http://localhost@APP_URL=https://${DOMAIN_NAME}@" "$ENV_FILE_DEPLOY_PATH"
   sed -i "s/DB_DATABASE=laravel/DB_DATABASE=${database_dbname}/" "$ENV_FILE_DEPLOY_PATH"
   sed -i "s/DB_USERNAME=root/DB_USERNAME=${database_user}/" "$ENV_FILE_DEPLOY_PATH"
   sed -i "s/DB_PASSWORD=/DB_PASSWORD=${database_password}/" "$ENV_FILE_DEPLOY_PATH"

   # GIVE ADMIN USER PERMISSIONS TO EDIT .ENV FILE
   echo "giving admin user permissions to edit .env file"
   sudo setfacl -m u:"$server_username":rwx "$ENV_FILE_DEPLOY_PATH"
   echo ".env file permissions to admin OK"


   #notify that laravel app key was not yet generated
   sudo touch "$LARAVEL_APP_KEY_NOT_GENERATED_FILEPATH"
   echo "setting up app .env file done"
else
   echo ".env.example template of provided laravel version(${laravel_version}) could not be retrieved from (${ENV_TEMPLATE_URL})"
fi
