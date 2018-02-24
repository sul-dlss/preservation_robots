cert_dir = File.join(File.dirname(__FILE__), '..', 'certs')

Dor::Config.configure do
  ssl do
    cert_file File.join(cert_dir, '.crt')
    key_file File.join(cert_dir, '.key')
    key_pass ''
  end

  workflow do
    url ''
    logfile 'log/wfs/workflow_service.log'
    shift_age 'weekly'
  end

  # solr.url ''
  dor_services.url ''

  robots do
    workspace '/tmp'
  end

end
#REDIS_URL = ''
REDIS_URL = 'localhost:6379/resque:test'
