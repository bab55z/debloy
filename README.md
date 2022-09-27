# Debloy
Laravel app deployment made easy with automated environment setup. 

This script, when run, will perform the following actions on your server

- Create the web folder for your app
- Create a database for your app
- Create and configure a Nginx host file to server the app
- Create and configure a git-bare repository on the server for the app to manage your code deployments continuously
- Create and configure a post-receive git hooks for the git-bare repository to handle your code deployments (_file permissions,mix compilation, composer packages install updates, code clean up, caching, various post deployments optimization..._)
- Automatically install Let's Encrypt SSL certificate for your app

# General information
**Recommended steps**

- Initial run to set up the full environment
- After the initial run, add the newly created git-bare repo to your code source, the exact command to do this will be displayed like following after the initial run
```
add the remote git bare repository with the following git command 
git remote add production ssh://username@server.domain.com/repositories/debloy.com.git
```
- Make your first push to the server from your local code base to deploy your code. _Only for the first push, Debloy will detect the push and execute the laravel command to generate the app key_.
- After the initial push, you need to update the .env file of the new environment accordingly to your requirements.
- Voilà! enjoy your newly created app.

**Important notice:**

As of now, you need to move to the folder where debloy script is installed (the folder containing `debloy.sh`).

You must also run debloy.sh with sudo

# Usage
**Running debloy.sh**

`sudo debloy.sh -y stage-site-debloy.yml -d database-dump-file.sql` 

**Parameters**

	-y or --yaml-file 		  the 'debloyment' yaml config file
	-d or --database-dump-file 	  database dump file
	-h or --help 	                  View the help 

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
