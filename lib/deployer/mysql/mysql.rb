Capistrano::Configuration.instance(:must_exist).load do
  namespace :mysql do
    desc <<-DESC
    Creates MySQL database, database user and grants permissions on DB servers
    DESC
    task :create, :roles => :db, :except => { :no_releases => true } do
    	require 'erb'
      prompt_with_default(:mysql_admin_user, 'root')
    	_cset :mysql_admin_password, Capistrano::CLI.password_prompt("password:")
      prompt_with_default(:mysql_grant_priv_type, 'ALL')
      prompt_with_default(:mysql_grant_locations, 'localhost')
      prompt_with_default(:db_login, user)
    	_cset :db_password, Capistrano::CLI.password_prompt("password:")
      prompt_with_default(:db_name, application)
      prompt_with_default(:db_encoding, 'utf8')

    	set :tmp_filename, File.join(shared_path, "config/create_db_#{db_name}.sql") 

    	template = File.read(File.join(File.dirname(__FILE__), "../templates", "create_database.sql.erb"))
    	result = ERB.new(template).result(binding)

    	put(result, "#{tmp_filename}", :mode => 0644, :via => :scp)

    	run "mysql -u #{mysql_admin_user} -p#{mysql_admin_password} < #{tmp_filename}"
    	run "#{try_sudo} rm #{tmp_filename}"
    end

    desc <<-DESC
    Exports MySQL database and copies it to the shared directory
    DESC
    task :export, :roles => :db, :except => { :no_releases => true } do
      prompt_with_default(:mysql_admin_user, 'root')
    	_cset :mysql_admin_password, Capistrano::CLI.password_prompt("password:")
      database = Capistrano::CLI.ui.ask("Which database should we export: ")
      timestamp = Time.now.utc.strftime("%Y%m%d%H%M%S")
      run "mysqldump -u #{mysql_admin_user} -p #{mysql_admin_password} > #{database}-#{timestamp}.sql"
      download "#{database}-#{timestamp}.sql", "~/#{database}-#{timestamp}.sql"
      logger.info "Database dump has been downloaded to ~/#{database}-#{timestamp}.sql"
      run "rm #{database}-#{timestamp}.sql"
    end
  end    
end