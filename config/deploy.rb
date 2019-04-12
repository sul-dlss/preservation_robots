set :application, 'preservation_robots'
set :repo_url, 'https://github.com/sul-dlss/preservation_robots.git'

# Default branch is :master
ask :branch, `git rev-parse --abbrev-ref HEAD`.chomp

# Default deploy_to directory is /var/www/my_app_name
set :deploy_to, "/opt/app/pres/#{fetch(:application)}"

# Default value for :format is :airbrussh.
# set :format, :airbrussh

# You can configure the Airbrussh format using :format_options.
# These are the defaults.
# set :format_options, command_output: true, log_file: "log/capistrano.log", color: :auto, truncate: :auto

# Default value for :pty is false
# set :pty, true

# Default value for :linked_files is []
# append :linked_files, "config/database.yml", "config/secrets.yml"
# append :linked_files, %w(config/honeybadger.yml)

# Default value for linked_dirs is []
# append :linked_dirs, "log", "tmp/pids", "tmp/cache", "tmp/sockets", "public/system"
append :linked_dirs, 'log', 'run', 'config/environments', 'config/certs', 'tmp'

# Default value for default_env is {}
# set :default_env, { path: "/opt/ruby/bin:$PATH" }

# Default value for local_user is ENV['USER']
# set :local_user, -> { `git config user.name`.chomp }

# Default value for keep_releases is 5
# set :keep_releases, 5

# Uncomment the following to require manually verifying the host key before first deploy.
# set :ssh_options, verify_host_key: :secure

set :bundle_without, %w[development deployment test].join(' ')

set :stages, %w[stage prod]

set :honeybadger_env, fetch(:stage)
# for robot-controller's verify command
set :whenever_identifier, -> { "#{fetch(:application)}_#{fetch(:stage)}" }

# update shared_configs before restarting app
before 'deploy:publishing', 'shared_configs:update'

after 'deploy:publishing', 'resque:pool:full_restart'
