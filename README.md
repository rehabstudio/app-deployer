# App Deployer

This gem makes it easy to deploy non rails apps/sites, it also comes with some useful helper tasks for frameworks like lithium and cakephp.

It is used by rehabstudio for almost every deployment we do.

## Installation
**Please be aware that this gem is in active development and some features may not work as expected.**

If you find any issues/bugs please add them to the issue tracker, or even better, see the Contributing section at the bottom.

####Required Gems
We need to ensure we have the following gems installed

    $ gem install bundler capistrano


####To install locally:

1. clone the repo
2. cd to the directory
3. Run `rake install`

---

When it is available from rubygems.org you will be able to install it yourself as:

    $ gem install app-deployer

## Usage

####Basic deployment

Open your application's Capfile and make it look like this:

    require 'rubygems'
    require 'app-deployer'
    
Open your config/deploy.rb file and add this:

    set :application, 'myapp'
    set :user, "your-deploy-user"
    set :repository, "https://path-to git-repo.git"
    set :deploy_to, "/var/www/myapp"

    server "http://yourserver.com", :web, :app


####Multistage
You can also set this up to use capistrano's multistage extension. This is great if you have to deploy the app to multiple servers like dev, staging etc.

To use multistage you should also add the following to your Capfile:

    require 'capistrano/ext/multistage' 
    set :stages, %w(development, staging, production)
    set :default_stage, "production"
    
The setup of your deploy scripts will also change, instead of having config/deploy.rb you need to create a folder called deploy in your config folder and also separate file for each stage. 

You will need a file for each item in the stages variable in your Capfile.

So in this example we would need development.rb, staging.rb and production.rb to be located in the config/deploy directory.


###Initial setup
To setup your app you need to run 

    cap deploy:setup
    
or if you are using multistage you would use this (subsituting &lt;stage&gt; with the stage name)

    cap <stage> deploy:setup
    
This will create the necessary folder structure for deployment

###Deploying
To deploy your app you can now run

    cap deploy

or for multistage

    cap <stage> deploy
  

##Framework tasks
To use the extra tasks that are available for frameworks you need to include the file at the bottom of your deploy file.


###CakePHP
A lot of the tasks are based on the capcake gem but some have been slightly modified.
To use the CakePHP tasks, add the following at the bottom of your deploy file:
    
    require 'app-deployer/framework/cakephp/cakephp'

This will add in some hooks to the deployment process.

####Setup
On initial setup of your site a DB config file will be generated for you. Just fill in the values at the prompt

The tmp folders and any shared folders will also be setup. See Shared folders below for more info on these.


####After deploy hooks
Each time you deploy, symlinks for the database file and any shared folders will be created for your app.

The tmp cache will also be cleared.

####Changing the CakePHP repo and branch
Use these lines below to change your repo/branch
    
    set :cakephp_repo, "git://github.com/cakephp/cakephp.git"
    set :cake_branch,  "origin/2.2"


####Shared folders
If you have an uploads folder that you want to preserve on each deploy you can declare them using:

    set :shared_app_dirs, ["webroot/uploads"]
    
Each time you deploy these folders will be symlinked to the current directory. 
These folders will also be created on deploy:setup to save you creating them manually

####Older version support
If you are still using CakePHP 1.3 you will need to set the following in your deploy file.
    
    set: cakephp_version, 1.3 

###Lithium
First we need to include the lithium tasks in our deploy file

    require 'app-deployer/framework/lithium/lithium'
    
    
###EC2
If you use Amazon EC2, you can add this line to make capistrano use your pem file

    ssh_options[:keys] = ["#{ENV['HOME']}/.ssh/your-key.pem"]
    

##Servers
###Apache
To use any of the apache tasks you need to include the file in your deploy script

    require 'app-deployer/server/apache/apache'

To put your server into maintenance mode run:

    cap apache:maintenance:start

To take it out of maintenance mode run:

    cap apache:maintenance:end

###Nginx
To be completed

###PHP5-FPM
You can automatically reload the php-fpm service after a deploy by including the task at the bottom of your deploy file

    require 'app-deployer/server/php-fpm'


You should ensure the deploy user has the correct privileges to do this by adding a line to the sudoers file using visudo

    deploy ALL=(ALL) NOPASSWD: /usr/sbin/service php5-fpm reload

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
