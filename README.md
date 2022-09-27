# Debloy
Laravel app deployment made easy with automated environment setup

# Usage
**Important notice:** 

as of now, you need to move to the folder where debloy script is installed (the folder containing `debloy.sh`).  

You must also run debloy.sh with sudo 

`sudo debloy.sh -y stage-site-debloy.yml -d database-dump-file.sql` 

**Parameters**

	-y or --yaml-file 		  the 'debloyment' yaml config file
  
	-d or --database-dump-file 	  database dump file

**'debloyment' yaml config file example**

```yaml
site-name: Debloy Web App # name of the app
mode: new #Deployment mode: new, update or override
environment: production #dev, stage, production or anything else
laravel:
  version: 9.0.0 #full laravel version e.g. 8.0.1, used to retrieve latest .env.example,...
server:
  hostname: server.domain.com
  username: coolboy #remote server user name
  email: coolboy@domain.com
php:
  fpm-sock: unix:/var/run/php8.1-fpm.sock
database:
  type: mysql #mysql
  dbname: laravel # the database name
  user: laravel # the database username
  password: $$secured@password12345## # the database password
git-bare:
  root-folder: /repositories/production # the root folder on the deployment server that contains your git-bare repositories
  repo-name: debloy.com.git # the git-bare repository name
webserver:
  type: nginx # the web server used to run the app: nginx only supported
  folder: /var/www/html/production/debloy.com # app web root folder
  domain-name:
    main: debloy.com #the main domain name of your web app
    production: debloy.com #the production environment domain name of your web app
    dev: dev.debloy.com #the dev environment domain name of your web app
    stage: stage.debloy.com #the stage environment domain name of your web app
    others: #list of others domain names used by your web app
      - laravel.app
      - dev.laravel.app
      - stage.laravel.app
  ssl:
    enabled: true # if true, enables ssl for the app
    letsencrypt: true # it true, automatically requests and sets up ssl from Let's Encrypt authority
compile-javascript: true # if true, compiles your mix config
```