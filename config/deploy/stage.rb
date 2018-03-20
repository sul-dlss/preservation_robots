server 'pres-robots1-stage.stanford.edu', user: 'pres', roles: %w[web app db]

Capistrano::OneTimeKey.generate_one_time_key!

set :deploy_environment, 'test'
