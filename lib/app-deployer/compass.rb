Capistrano::Configuration.instance(:must_exist).load do
	namespace :compass do
		desc 'Compiles Compass files into stylsheets'
		task :compile do
			run("cd #{latest_release}/webroot; compass compile --output-style nested --force -e production")
		end
	end
end