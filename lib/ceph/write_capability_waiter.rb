# frozen_string_literal: true

module Ceph
  # Blocks until no other host holds write capabilities on the given paths, so that a
  # robot step which reads what a previous step wrote on a different host sees the
  # finished result rather than a partial or invisible one.
  #
  # Waiting is bounded. If the caps are still held when we give up, that is raised: the
  # read that follows is known to be unsafe, so failing the workflow step is better than
  # ingesting whatever we would have read. If the query itself fails, that is reported
  # and we proceed: a broken diagnostic should leave the step behaving exactly as it did
  # before this check existed.
  class WriteCapabilityWaiter
    def initialize(pathnames:,
                   settings: Settings.ceph.write_capability_check,
                   client: nil,
                   logger: Sidekiq.logger)
      @pathnames = Array(pathnames).map { |pathname| Pathname(pathname) }
      @settings = settings
      @client = client
      @logger = logger
    end

    attr_reader :pathnames, :settings, :logger

    # @raise [Ceph::WriteCapabilitiesHeldError] if caps are still held when we stop waiting
    def wait
      return unless settings.enabled

      holders = poll_until_released
      return if holders.empty?

      raise WriteCapabilitiesHeldError,
            "gave up after #{settings.max_wait}s waiting for other hosts to release write " \
            "capabilities on #{described_pathnames}: #{describe(holders)}"
    end

    private

    def client
      @client ||= MdsAdminClient.new(logger:)
    end

    def poll_until_released
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + settings.max_wait
      loop do
        holders = current_holders
        return [] if holders.empty?
        return holders if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline

        logger.info("waiting #{settings.poll_interval}s for write capabilities on " \
                    "#{described_pathnames} to be released: #{describe(holders)}")
        sleep(settings.poll_interval)
      end
    end

    def current_holders
      checks.flat_map(&:write_capability_holders)
    rescue Error => e
      logger.warn("could not check CephFS write capabilities on #{described_pathnames}, " \
                  "proceeding anyway: #{e.message}")
      Honeybadger.notify(e, context: { pathnames: described_pathnames })
      []
    end

    def checks
      @checks ||= checkable_pathnames.map do |pathname|
        WriteCapabilityCheck.new(pathname:, client:, settings:, logger:)
      end
    end

    # A path we cannot see is a path we cannot resolve to an inode, and so cannot ask the
    # MDS about. Worth saying out loud, since a missing path is itself one of the symptoms
    # of the lag this check exists to absorb.
    def checkable_pathnames
      pathnames.select do |pathname|
        next true if pathname.exist?

        logger.warn("skipping CephFS write capability check for #{pathname}: it does not exist")
        false
      end
    end

    def described_pathnames
      pathnames.join(', ')
    end

    def describe(holders)
      holders.map do |holder|
        "inode #{holder[:ino]} held by client #{holder[:client_id]} (#{holder[:write_grants].join(' ')})"
      end.join('; ')
    end
  end
end
