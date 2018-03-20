server 'pres-robots1-prod.stanford.edu', user: 'pres', roles: %w[web app db monitor]

Capistrano::OneTimeKey.generate_one_time_key!

set :deploy_environment, 'production'
