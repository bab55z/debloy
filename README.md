# Debloy
Laravel app deployment made easy with automated environment setup. 

This script, when run, will perform the following actions on your server

- Create the web folder for your app
- Create a database for your app
- Create and configure a Nginx host file to server the app
- Create and configure a git-bare repository on the server for the app to manage your code deployments continuously
- Create and configure a post-receive git hooks for the git-bare repository to handle your code deployments (_file permissions,mix compilation, composer packages install updates, code clean up, caching, various post deployments optimization..._)
- Automatically install Let's Encrypt SSL certificate for your app
- Temporarily give granular permissions to the unix user in charge of the app maintenance only when deploying and removed after deployment
- Properly manage the app files access permissions for best security

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
- If after the above steps your app has errors, try to clean and refresh your app caches with following commands

  ```php artisan route:clear```

  ```php artisan config:clear```

  ```php artisan view:clear```

  ```php artisan cache:clear```

- Voilà! enjoy your newly created app.

**Important notice:**

As of now, you need to move to the folder where debloy script is installed (the folder containing `debloy.sh`).

You must also run debloy.sh with sudo

# Usage
**Requirements**
- A linux server with ssh access
- A domain name pointing to the server
- A database server running on the server
  - you'll need to provide an admin user with the right to create new databases
- A database dump file of your app database (optional)
- git installed on the server
- php-cli installed on the server
- php FPM installed on the server (socks path must be specified in the yaml config file)
- nginx installed on the server
- composer installed on the server
- setfacl command installed on the server
  - `sudo apt-get install acl` on debian/ubuntu


**Installation & Running debloy.sh**
- clone this repository on your server 
  
  ```git clone https://github.com/bab55z/debloy.git```

- move to the folder where debloy script is installed (the folder containing `debloy.sh`)

  ```cd debloy```

- configure your yaml config file (see example below)

- run debloy.sh with sudo

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
  username: username #remote server user name
  email: username@domain.com
php:
  executable: php #php executable name, edit if you want to use a custom command to run php during ci/cd, e.g. php7.4
  composer-command: composer #composer executable name, edit if you want to use a custom command to run composer during ci/cd deployments, e.g. php7.4 /usr/local/bin/composer
  fpm-sock: unix:/var/run/php8.1-fpm.sock
database:
  type: mysql #mysql
  admin: #database admin credentials
    user: root # the database admin username with all privileges
    password: $$secured@password12345## # the database admin password
  dbname: laravel # the database name
  user: laravel # the database username
  password: $$secured@password12345## # the database password
git-bare:
  root-folder: /repositories/production # the root folder on the deployment server that contains your git-bare repositories
  repo-name: debloy.com.git # the git-bare repository name
webserver:
  type: nginx # the web server used to run the app: nginx only supported
  user: www-data # the web server username
  user-group: www-data # the web server user group name
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
**Security & safety**

After successfully running the script, do not forget to delete the yaml config file for security reasons.

If you do not want to delete the file, you should remove sensitive information like the database admin credentials and the app database credentials.
```yaml
database:
  type: #mysql
  admin: #database admin credentials
    user: # the database admin username with all privileges
    password: # the database admin password
  dbname: # the database name
  user: # the database username
  password: # the database password
```

**Bonus: recommended deployment architecture**

this is a personal suggestion, feel free to user it or not.

_Web folder_
```
-> Structure: /var/www/html/{environment}/{app-domain}
Example1: /var/www/html/production/mysite.com #mysite.com in production environment
Example2: /var/www/html/stage/mysite.com #mysite.com in staging environment
```
_Git bare repositories folder_
```
-> Structure repositories folder: /var/repo/{environment}/{app-domain}.git
Example1: /var/repo/production/mysite.com.git #mysite.com in production environment
Example2: /var/repo/stage/mysite.com.git #mysite.com in staging environment
```
_Nginx config folder_
```
-> Structure: /etc/nginx/sites-available/{environment}.{app-domain} (no environment for production)
Example1: /etc/nginx/sites-available/mysite.com #mysite.com in production environment
Example2: /etc/nginx/sites-available/stage.mysite.com #mysite.com in staging environment
```

Thanks!