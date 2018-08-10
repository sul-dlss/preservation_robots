# houses shared functionality for the *_reporters
class Reporter
  def self.default_log_files
    Dir.glob("#{Dir.pwd}/log/sdr_preservationIngestWF*.log").sort
  end
end
