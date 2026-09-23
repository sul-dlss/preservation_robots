# frozen_string_literal: true

require 'json'
require 'open3'

module Ceph
  # Runs the handful of Ceph admin commands we need by shelling out to the `ceph` CLI,
  # and returns the parsed JSON.
  #
  # We shell out rather than binding librados directly because librados exposes these
  # as `rados_mon_command`/`rados_mds_command`, which would mean hand-writing FFI
  # bindings (no maintained Ruby gem wraps them -- the `ceph-ruby` gem binds only
  # rados object and RBD operations) for no behavioral gain over the CLI.
  #
  # IMPORTANT: `ceph tell mds.<...>` is only permitted for a key whose MDS capability
  # is `allow *`. The MDS rejects tell commands from every other key outright; there is
  # no narrower grant (see MDSDaemon::handle_command in the Ceph source).
  class MdsAdminClient
    def initialize(settings: Settings.ceph, logger: Sidekiq.logger)
      @settings = settings
      @logger = logger
    end

    attr_reader :settings, :logger

    # The MDS ranks serving our filesystem, either as configured or as reported by the cluster.
    # @return [Array<Integer>]
    def ranks
      @ranks ||= Array(settings.write_capability_check.ranks).presence || ranks_from_cluster
    end

    # Dump the MDS's cached metadata for the subtree rooted at the given CephFS path.
    #
    # The MDS pins an inode in its cache for as long as any client holds a capability on
    # it, so an uncached subtree is one that no client holds capabilities on. In that
    # case the MDS reports the miss on stderr and returns no JSON, and we return no inodes.
    #
    # @param cephfs_path [String] path relative to the root of the CephFS namespace
    # @param rank [Integer]
    # @return [Array<Hash>] one entry per cached inode in the subtree
    def dump_tree(cephfs_path:, rank:)
      stdout = tell(rank, 'dump', 'tree', cephfs_path)
      return [] if stdout.blank?

      Array(parse_json(stdout)['inodes'])
    end

    # The MDS's client sessions, which carry the client metadata we use to tell our own
    # host's CephFS client apart from every other host's.
    #
    # @param rank [Integer]
    # @return [Array<Hash>]
    def sessions(rank:)
      stdout = tell(rank, 'session', 'ls')
      return [] if stdout.blank?

      Array(parse_json(stdout))
    end

    private

    def filesystem_name
      settings.write_capability_check.filesystem_name
    end

    def mds_target(rank)
      "mds.#{filesystem_name}:#{rank}"
    end

    def ranks_from_cluster
      mdsmap = parse_json(run('fs', 'get', filesystem_name))['mdsmap'] || {}
      Array(mdsmap['in']).presence ||
        raise(Error, "no MDS ranks are in for CephFS filesystem '#{filesystem_name}'")
    end

    def tell(rank, *command_arguments)
      run('tell', mds_target(rank), *command_arguments)
    end

    def run(*command_arguments)
      command = base_command + command_arguments
      stdout, stderr, status = Open3.capture3(*command)
      raise Error, "#{command.join(' ')} exited #{status.exitstatus}: #{stderr.strip}" unless status.success?

      logger.debug("#{command.join(' ')}: #{stderr.strip}") if stderr.present?
      stdout
    rescue Errno::ENOENT, Errno::EACCES => e
      raise Error, "unable to run #{command_arguments.join(' ')}: #{e.message}"
    end

    def base_command
      cli = settings.cli
      [cli.executable, '--format', 'json'].tap do |command|
        command.push('--conf', cli.conf) if cli.conf
        command.push('--name', cli.name) if cli.name
        command.push('--keyring', cli.keyring) if cli.keyring
        command.push('--connect-timeout', cli.connect_timeout.to_s) if cli.connect_timeout
      end
    end

    def parse_json(stdout)
      JSON.parse(stdout)
    rescue JSON::ParserError => e
      raise Error, "unparseable response from ceph: #{e.message}"
    end
  end
end
