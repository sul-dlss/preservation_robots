cert_dir = File.join(File.dirname(__FILE__), '..', 'certs')

Dor::Config.configure do
  ssl do
    cert_file File.join(cert_dir, '.crt')
    key_file File.join(cert_dir, '.key')
    key_pass ''
  end

  workflow do
    url 'https://workflows.example.org'
    logfile 'log/wfs/workflow_service.log'
    shift_age 'weekly'
  end

  # solr.url ''
  # dor_services.url ''
  # fedora do
  #   url ''
  # end

  robots do
    workspace '/tmp'
  end

  transfer_object do
    from_host "userid@from-host"
    from_dir "/dor/export/"
  end
end

#REDIS_URL = ''
REDIS_URL = 'localhost:6379/resque:test'
