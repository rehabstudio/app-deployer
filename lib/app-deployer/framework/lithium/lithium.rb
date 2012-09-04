Capistrano::Configuration.instance(:must_exist).load do

  require 'erb'

  # =========================================================================
  # Settings
  # =========================================================================

  _cset :shared_app_dirs, []
  _cset(:lithium_repo)    { "https://github.com/UnionOfRAD/lithium.git" }
  _cset(:lithium_branch)  { "master" }
  _cset :shared_children, %w(libraries tmp)
  _cset :tmp_children,    %w(cache logs tests)
  _cset :cache_children,  %w(templates)
  _cset :logs_files,      %w(debug error)
  _cset(:database_path)   { File.join(File.join(shared_path, "config/bootstrap"), "connections.php") }
  _cset(:tmp_path)        { File.join(shared_path, "tmp") }
  _cset(:cache_path)      { File.join(tmp_path, "cache") }
  _cset(:logs_path)       { File.join(tmp_path, "logs") }

  # =========================================================================
  # Hooks
  # =========================================================================

    after('deploy:setup', 'lithium:setup')
    after('deploy:create_symlink', 'lithium:create_symlink')
    after('deploy:finalize_update', 'lithium:cache:clear')

  # =========================================================================
  # Tasks
  # =========================================================================

  namespace :lithium do

    desc <<-DESC
    Prepares server for deployment of a lithium application. \

    By default, it will create a shallow clone of the lithium repository \
    inside #{shared_path}/libraries/lithium and run deploy:lithium:update.
    DESC
    task :setup do
      transaction do
        run "cd #{shared_path}/libraries && git clone --depth 1 #{lithium_repo} lithium"
        checkout
        connections.setup
        shared.setup
      end
    end

    desc <<-DESC
    Force lithium installation to checkout a new branch/tag.
    DESC
    task :checkout do
      on_rollback { run "rm -rf #{shared_path}/lithium; true" }
      stream "cd #{shared_path}/lithium && git checkout -q #{lithium_branch}"
    end

    desc <<-DESC
    Update the lithium repository to the latest version.
    DESC
    task :update do
      stream "cd #{shared_path}/libraries/lithium && git pull"
    end

    desc <<-DESC
    This is a task that will get called from the deploy:create_symlink task
    It runs just before the release is symlinked to the current directory
    
    You should use it to create symlinks to things like your database config \
    and any shared directories or files that your app uses  
    DESC
    task :create_symlink do
      transaction do
        connections.create_symlink
        shared.create_symlink
      end
    end
    
    # Framework specific tasks

    # Caching
    namespace :cache do
      desc <<-DESC
      Clears cache and sub-directories.

      Recursively finds all files in :cache_path and runs `rm -f` on each. If a file \
      is renamed/removed after it was found but before it removes it, no error \
      will prompt (-ignore_readdir_race). If symlinks are found, they will not be followed

      You will rarely need to call this task directly; instead, use the `deploy' \
      task (which performs a complete deploy, including `lithium:cache:clear')
      DESC
      task :clear, :roles => :web, :except => { :no_release => true } do
        run "#{try_sudo} find -P #{cache_path} -ignore_readdir_race -type f -name '*' -exec rm -f {} \\;"
      end
    end

    # Connections config
    namespace :connections do
      desc <<-DESC
      Generates lithium connections file in #{shared_path}/config/bootstrap/ \
      and symlinks #{current_path}/config/bootstrap/connections.php to it
      DESC
      task :setup, :roles => :web, :except => { :no_release => true } do
          on_rollback { run "rm -f #{database_path}; true" }
          puts "Connections setup"

          prompt_with_default(:type, "database|MongoDb|http")
          case :type
            when 'database'
              prompt_with_default(:login, user)
              set :password, Capistrano::CLI.password_prompt("password:")
              prompt_with_default(:encoding, 'UTF-8')
          end

          prompt_with_default(:host, "127.0.0.1")
          prompt_with_default(:database, application)

          template = File.read(File.join(File.dirname(__FILE__), "templates", "connections.php.erb"))
          result = ERB.new(template).result(binding)

          put(result, "#{database_path}", :mode => 0644, :via => :scp)
      end
  
      desc <<-DESC
      Symlinks the connections file.
      DESC
      task :create_symlink, :roles => :web, :except => { :no_release => true } do
          run "#{try_sudo} ln -s #{database_path} #{current_path}/config/bootstrap/connections.php"
      end
    end

    # Shared directories and files
    namespace :shared do
      desc <<-DESC
      Creates shared folders on the server
      DESC
      task :setup do
        dirs = [deploy_to, releases_path, shared_path]
        dirs += shared_children.map { |d| File.join(shared_path, d) }
        tmp_dirs = tmp_children.map { |d| File.join(tmp_path, d) }
        tmp_dirs += cache_children.map { |d| File.join(cache_path, d) }
        run "echo #{dirs} && #{try_sudo} mkdir -p #{(dirs + tmp_dirs).join(' ')} && #{try_sudo} chmod -R 777 #{tmp_path}" if (!user.empty?)

        if shared_app_dirs
          shared_app_dirs.each { | link | run "#{try_sudo} mkdir -p #{shared_path}/#{link}" }
        end
      end
      
      desc <<-DESC
      Symlinks all shared files and folders
      DESC
      task :symlink do
        run "ln -s #{shared_path}/tmp #{latest_release}/tmp";
        if shared_app_dirs
          shared_app_dirs.each { | link | run "ln -nfs #{shared_path}/#{link} #{current_path}/#{link}" }
        end
      end
    end
   
    # Logs
    namespace :log do
      desc <<-DESC
      Clears logs and sub-directories

      Recursively finds all files in :logs_path and runs `rm -f` on each. If a file \
      is renamed/removed after it was found but before it removes it, no error \
      will prompt (-ignore_readdir_race). If symlinks are found, they will not be followed
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