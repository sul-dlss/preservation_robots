# frozen_string_literal: true

server 'preservation-robots1-stage.stanford.edu', user: 'pres', roles: %w[web app db worker]
# robots2-stage is a warm standby - no sidekiq up but ready to deploy to if needed
# server 'preservation-robots2-stage.stanford.edu', user: 'pres', roles: %w[web app db worker]

set :deploy_environment, 'stage'
set :default_env, robot_environment: fetch(:deploy_environment)
