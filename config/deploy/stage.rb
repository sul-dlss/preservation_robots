# frozen_string_literal: true

server 'preservation-robots1-stage.stanford.edu', user: 'pres', roles: %w[web app db]
# robots2-stage is a warm standby - no resque-pool up but ready to deploy to if needed
# server 'preservation-robots2-stage.stanford.edu', user: 'pres', roles: %w[web app db]

Capistrano::OneTimeKey.generate_one_time_key!

set :deploy_environment, 'stage'
set :default_env, robot_environment: fetch(:deploy_environment)
