# encoding: utf-8
Capistrano::Configuration.instance(:must_exist).load do
  # =========================================================================
  # These are helper methods that will be available to your recipes.
  # =========================================================================

  def _cset(name, *args, &block)
    unless exists?(name)
      set(name, *args, &block)
    end
  end

  # Asks the shell for a response or else uses the default if nothing
  # is entered
  def prompt_with_default(var, default, &block)
    set(var) do
      Capistrano::CLI.ui.ask("#{var} [#{default}] : ", &block)
    end
    set var, default if eval("#{var.to_s}.empty?")
  end

  # Check to see if a file exists
  def remote_file_exists?(full_path)
  	'true' ==  capture("if [ -e #{full_path} ]; then echo 'true'; fi").strip
  end

  # Auxiliary helper method for the `deploy:check' task. Lets you set up your
  # own dependencies.
  def depend(location, type, *args)
    deps = fetch(:dependencies, {})
    deps[location] ||= {}
    deps[location][type] ||= []
    deps[location][type] << args
    set :dependencies, deps
  end

  # Temporarily sets an environment variable, yields to a block, and restores
  # the value when it is done.
  def with_env(name, value)
    saved, ENV[name] = ENV[name], value
    yield
  ensure
    ENV[name] = saved
  end

  # logs the command then executes it locally.
  # returns the command output as a string
  def run_locally(cmd)
    logger.trace "executing locally: #{cmd.inspect}" if logger
    output_on_stdout = nil
    elapsed = Benchmark.realtime do
      output_on_stdout = `#{cmd}`
    end
    if $?.to_i > 0 # $? is command exit code (posix style)
      raise Capistrano::LocalArgumentError, "Command #{cmd} returned status code #{$?}"
    end
    logger.trace "command finished in #{(elapsed * 1000).round}ms" if logger
    output_on_stdout
  end

  # If a command is given, this will try to execute the given command, as
  # described below. Otherwise, it will return a string for use in embedding in
  # another command, for executing that command as described below.
  #
  # If :run_method is :sudo (or :use_sudo is true), this executes the given command
  # via +sudo+. Otherwise is uses +run+. If :as is given as a key, it will be
  # passed as the user to sudo as, if using sudo. If the :as key is not given,
  # it will default to whatever the value of the :admin_runner variable is,
  # which (by default) is unset.
  #
  # THUS, if you want to try to run something via sudo, and what to use the
  # root user, you'd just to try_sudo('something'). If you wanted to try_sudo as
  # someone else, you'd just do try_sudo('something', :as => "bob"). If you
  # always wanted sudo to run as a particular user, you could do
  # set(:admin_runner, "bob").
  def try_sudo(*args)
    options = args.last.is_a?(Hash) ? args.pop : {}
    command = args.shift
    raise ArgumentError, "too many arguments" if args.any?

    as = options.fetch(:as, fetch(:admin_runner, nil))
    via = fetch(:run_method, :sudo)
    if command
      invoke_command(command, :via => via, :as => as)
    elsif via == :sudo
      sudo(:as => as)
    else
      ""
    end
  end

  # Same as sudo, but tries sudo with :as set to the value of the :runner
  # variable (which defaults to "app").
  def try_runner(*args)
    options = args.last.is_a?(Hash) ? args.pop : {}
    args << options.merge(:as => fetch(:runner, "app"))
    try_sudo(*args)
  end


  def pretty_print(msg)
    if logger.level == Capistrano::Logger::IMPORTANT
      pretty_errors

      msg = msg.slice(0, 57)
      msg << '.' * (60 - msg.size)
      print msg
    else
      puts msg.green
    end
  end

  def puts_ok
    if logger.level == Capistrano::Logger::IMPORTANT && !$error
      puts '✔'.green
    end

    $error = false
  end

  def pretty_errors
    if !$pretty_errors_defined
      $pretty_errors_defined = true

      class << $stderr
        @@firstLine = true
        alias _write write

        def write(s)
          if @@firstLine
            s = '✘' << "\n" << s
            @@firstLine = false
          end

          _write(s.red)
          $error = true
        end
      end
    end
  end

end