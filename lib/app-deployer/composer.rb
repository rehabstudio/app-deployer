namespace :composer do
  desc "Gets composer and installs it"
  task :get, :roles => :app, :except => { :no_release => true } do
    if remote_file_exists?("#{previous_release}/composer.phar")
      pretty_print "--> Copying Composer from previous release"
      run "#{try_sudo} sh -c 'cp #{previous_release}/composer.phar #{latest_release}/'"
      puts_ok
    end

    if !remote_file_exists?("#{latest_release}/composer.phar")
      pretty_print "--> Downloading Composer"

      run "#{try_sudo} sh -c 'cd #{latest_release} && curl -s http://getcomposer.org/installer | #{php_bin}'"
    else
      pretty_print "--> Updating Composer"

      run "#{try_sudo} sh -c 'cd #{latest_release} && #{php_bin} composer.phar self-update'"
    end
    puts_ok
  end

  desc "Updates composer"

  desc "Runs composer to install vendors from composer.lock file"
  task :install, :roles => :app, :except => { :no_release => true } do
    if !composer_bin
      composer.get
      set :composer_bin, "#{php_bin} composer.phar"
    end

    pretty_print "--> Installing Composer dependencies"
    run "#{try_sudo} sh -c 'cd #{latest_release} && #{composer_bin} install #{composer_options}'"
    puts_ok
  end

  desc "Runs composer to update vendors, and composer.lock file"
  task :update, :roles => :app, :except => { :no_release => true } do
    if !composer_bin
      composer.get
      set :composer_bin, "#{php_bin} composer.phar"
    end

    pretty_print "--> Updating Composer dependencies"
    run "#{try_sudo} sh -c 'cd #{latest_release} && #{composer_bin} update #{composer_options}'"
    puts_ok
  end

  desc "Dumps an optimized autoloader"
  task :dump_autoload, :roles => :app, :except => { :no_release => true } do
    if !composer_bin
      composer.get
      set :composer_bin, "#{php_bin} composer.phar"
    end

    pretty_print "--> Dumping an optimized autoloader"
    run "#{try_sudo} sh -c 'cd #{latest_release} && #{composer_bin} dump-autoload --optimize'"
    puts_ok
  end

  task :copy_vendors, :except => { :no_release => true } do
    pretty_print "--> Copying vendors from previous release"

    run "vendorDir=#{current_path}/libraries; if [ -d $vendorDir ] || [ -h $vendorDir ]; then cp -a $vendorDir #{latest_release}/libraries; fi;"
    puts_ok
  end
end
