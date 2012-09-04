Capistrano::Configuration.instance(:must_exist).load do

  require 'erb'

  # =========================================================================
  # Settings
  # =========================================================================

  _cset :shared_app_dirs, []
  _cset(:cakephp_branch)  { "master" }
  _cset(:cakephp_repo)    { "https://github.com/cakephp/cakephp.git" }
  _cset :cakephp_version, 2
  _cset :tmp_children,    %w(cache logs sessions tests)
  _cset :cache_children,  %w(models persistent views)
  _cset :logs_files,      %w(debug error)
  _cset(:tmp_path)        { File.join(shared_path, "tmp") }
  _cset(:cache_path)      { File.join(tmp_path, "cache") }
  _cset(:logs_path)       { File.join(tmp_path, "logs") }
  if cakephp_version >= 2
    _cset :shared_children,       %w(Config tmp)
    _cset :database_partial_path, "Config/database.php"
  else
    _cset :shared_children,       %w(config tmp)
    _cset :database_partial_path, "config/database.php"
  end
  set(:database_path)     { File.join(shared_path, database_partial_path) }

  # =========================================================================
  # Hooks
  # =========================================================================

  after('deploy:setup',           'cakephp:setup')
  after('deploy:create_symlink',  'cakephp:create_symlink')
  after('deploy:finalize_update', 'cakephp:cache:clear')

  # =========================================================================
  # Tasks
  # =========================================================================

  namespace :cakephp do

    desc <<-DESC
      Prepares server for deployment of a CakePHP application. \

      By default, it will create a shallow clone of the CakePHP repository \
      inside #{shared_path}/cakephp and run deploy:cake:update.
    DESC
    task :setup do
      transaction do
        run "cd #{shared_path} && git clone --depth 1 #{cakephp_repo} cakephp"
        checkout
        shared.setup
        database.config.setup
      end
    end

    desc <<-DESC
      Checkout a new branch/tag.
    DESC
    task :checkout do
      stream "cd #{shared_path}/cakephp && git checkout -q #{cakephp_branch}"
    end

    desc <<-DESC
      Update the cake repository to the latest version.
    DESC
    task :update do
      stream "cd #{shared_path}/cakephp && git pull"
    end

    desc <<-DESC
      This is a task that will get called from the deploy:create_symlink task \
      It runs just before the release is symlinked to the current directory \

      You should use it to create symlinks to things like your database config \
      and any shared directories or files that your app uses  .
    DESC
    task :create_symlink do
      transaction do
        database.create_symlink
        shared.create_symlink
      end
    end
    
    # Framework specific tasks
    
    # Caching
    namespace :cache do
      desc <<-DESC
        Clears CakePHP's APP/tmp/cache and its sub-directories.

        Recursively finds all files in :cache_path and runs `rm -f` on each. If a file \
        is renamed/removed after it was found but before it removes it, no error \
        will prompt (-ignore_readdir_race). If symlinks are found, they will not be followed.

        You will rarely need to call this task directly; instead, use the `deploy' \
        task (which performs a complete deploy, including `cake:cache:clear')
      DESC
      task :clear, :roles => :web, :except => { :no_release => true } do
        run "#{try_sudo} find -P #{cache_path} -ignore_readdir_race -type f -name '*' -exec rm -f {} \\;"
      end
    end

    # Database config
    namespace :database do
      desc <<-DESC
        Generates CakePHP database configuration file in #{shared_path}/config \
        and symlinks #{current_path}/config/database.php to it
      DESC
      task :config, :roles => :web, :except => { :no_release => true } do
        on_rollback { run "rm -f #{database_path}; true" }
        puts "Database configuration"
        prompt_with_default(:datasource, cakephp_version >= 2 ? "Database/Mysql" : "mysql")
        prompt_with_default(:persistent, 'false')
        prompt_with_default(:host, "localhost")
        prompt_with_default(:login, user)
        set :password, Capistrano::CLI.password_prompt("password:")
        prompt_with_default(:database, application)
        prompt_with_default(:prefix, "")
        prompt_with_default(:encoding, 'utf8')

        template = File.read(File.join(File.dirname(__FILE__), "templates", "database.php.erb"))
        result = ERB.new(template).result(binding)

        put(result, "#{database_path}", :mode => 0644, :via => :scp)
        after("deploy:create_symlink", "cakephp:database:create_symlink")
      end

      desc <<-DESC
        Creates required CakePHP's APP/config/database.php as a symlink to \
        #{deploy_to}/shared/config/database.php
      DESC
      task :create_symlink, :roles => :web, :except => { :no_release => true } do
        run "#{try_sudo} rm -f #{current_path}/#{database_partial_path}"
        run "#{try_sudo} ln -s #{database_path} #{current_path}/#{database_partial_path}"
      end
    end
    
    # Shared directories and files
    namespace :shared do
      desc <<-DESC
        Creates shared folders on the server
      DESC
      task :setup do
        dirs      = [deploy_to, releases_path, shared_path]
        dirs     += shared_children.map { |d| File.join(shared_path, d) }
        tmp_dirs  = tmp_children.map { |d| File.join(tmp_path, d) }
        tmp_dirs += cache_children.map { |d| File.join(cache_path, d) }
        run "#{try_sudo} mkdir -p #{(dirs + tmp_dirs).join(' ')}"
        run "#{try_sudo} chmod -R 777 #{tmp_path}" if (!user.empty?)

        if shared_app_dirs
          shared_app_dirs.each { | link | run "#{try_sudo} mkdir -p #{shared_path}/#{link}" }
        end
      end
      
      desc <<-DESC
        Symlinks all files and folders
      DESC
      task :create_symlink do
        run "ln -s #{shared_path}/tmp #{latest_release}/tmp";
        if shared_app_dirs
          shared_app_dirs.each { | link | run "ln -s #{shared_path}/#{link} #{current_path}/#{link}" }
        end
      end
    end
   
    # Logs
    namespace :log do
      desc <<-DESC
        Clears CakePHP's APP/tmp/logs and its sub-directories

        Recursively finds all files in :logs_path and runs `rm -f` on each. If a file \
        is renamed/removed after it was found but before it removes it, no error \
        will prompt (-ignore_readdir_race). If symlinks are found, they will not be followed.
      DESC
      task :clear, :roles => :web, :except => { :no_release => true } do
        run "#{try_sudo} find -P #{logs_path} -ignore_readdir_race -type f -name '*' -exec rm -f {} \\;"
      end

      desc <<-DESC
        Streams the result of `tail -f` on all :logs_files \

        By default, the files are `debug` and `error`. You can add your own \
        in config/deploy.rb

        set :logs_files %w(debug error my_log_file)
      DESC
      task :tail, :roles => :web, :except => { :no_release => true } do
        files = logs_files.map { |d| File.join(logs_path, d) }
        stream "#{try_sudo} tail -f #{files.join(' ')}"
      end
    end
  end
end