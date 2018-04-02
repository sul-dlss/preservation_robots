cert_dir = File.join(File.dirname(__FILE__), '..', 'certs')

Dor::Config.configure do
  # FIXME do we need ssl and certs?
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

REDIS_URL = 'localhost:6379/resque:test'

# kurma-stage has the following (probably to use dor_workflow_service)
# WORKFLOW_URI = 'https://workflows.example.org'
# Dor::WorkflowService.configure(WORKFLOW_URI + '/')
