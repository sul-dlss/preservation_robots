# frozen_string_literal: true

require 'socket'

module Ceph
  # Answers, for one local path on a CephFS mount, "is any other host still holding
  # write capabilities anywhere under here?"
  #
  # CephFS clients cache inode data and metadata under capabilities ("caps") granted by
  # the MDS. A client that holds Fb (buffer) may be sitting on dirty file data that has
  # not reached the OSDs; a client that holds Fx/Ax/Xx holds file or metadata state that
  # the MDS's copy does not reflect. Until those caps come back, another host reading the
  # same path can see stale or missing content, or block waiting on the revoke.
  #
  # Caps held by this host's own CephFS client are ignored: every process on a host shares
  # one client, so those reads are already coherent. We identify our own client by matching
  # the hostname the client reported to the MDS when it mounted.
  class WriteCapabilityCheck
    def initialize(pathname:,
                   client: MdsAdminClient.new,
                   settings: Settings.ceph.write_capability_check,
                   logger: Sidekiq.logger)
      @pathname = Pathname(pathname)
      @client = client
      @settings = settings
      @logger = logger
    end

    attr_reader :pathname, :client, :settings, :logger

    # @return [Array<Hash>] one entry per (inode, client) pair still holding write caps
    # @raise [Ceph::Error] if the path cannot be mapped into the CephFS namespace, or the
    #   MDS cannot be queried
    def write_capability_holders
      # Stat before dumping, both to learn the inode number and to be sure the MDS has the
      # subtree root in cache: holding any cap on an inode pins it there, which is what
      # lets #verify_subtree_found! tell a genuinely quiet subtree apart from a path we
      # mapped into the CephFS namespace incorrectly.
      pinned_inode_number = root_inode_number

      cached_inodes = client.ranks.flat_map { |rank| client.dump_tree(cephfs_path:, rank:) }
      verify_subtree_found!(cached_inodes, pinned_inode_number)
      cached_inodes.flat_map { |cached_inode| holders_for(cached_inode) }
    end

    # The path translated from its local mount point into the CephFS namespace, which is
    # what the MDS knows it as.
    # @return [String]
    def cephfs_path
      @cephfs_path ||= File.join(mount.cephfs_root, resolved_pathname.to_s.delete_prefix(mount.mount_point.chomp('/')))
    end

    private

    # Symlinked storage roots are common, and the MDS only knows the real path.
    def resolved_pathname
      @resolved_pathname ||= pathname.realpath
    end

    def mount
      @mount ||= longest_matching_mount ||
                 raise(Error, "#{resolved_pathname} is not under any mount point in " \
                              'Settings.ceph.write_capability_check.mounts')
    end

    def longest_matching_mount
      settings.mounts
              .select { |candidate| under_mount_point?(candidate.mount_point) }
              .max_by { |candidate| candidate.mount_point.length }
    end

    def under_mount_point?(mount_point)
      mount_point = mount_point.chomp('/')
      resolved_pathname.to_s == mount_point || resolved_pathname.to_s.start_with?("#{mount_point}/")
    end

    # CephFS reports the MDS's own inode number as st_ino on 64 bit hosts, so this is the
    # same number the MDS uses to identify the inode.
    def root_inode_number
      @root_inode_number ||= resolved_pathname.stat.ino
    end

    # Without this, a mount point mapped to the wrong CephFS path would make every check
    # pass vacuously: the MDS would report the path as uncached, and we would read that as
    # "nobody holds caps here".
    def verify_subtree_found!(cached_inodes, inode_number)
      return if cached_inodes.any? { |cached_inode| cached_inode['ino'] == inode_number }

      raise Error,
            "the MDS has no cached inode #{inode_number} under '#{cephfs_path}', but we just " \
            "stat'd #{resolved_pathname}, so it should be pinned in the MDS cache; " \
            'check Settings.ceph.write_capability_check.mounts'
    end

    def holders_for(cached_inode)
      Array(cached_inode['client_caps']).filter_map do |client_cap|
        next if local_client_ids.include?(client_cap['client_id'])

        # "pending" is what the MDS means the client to hold and "issued" is what it has
        # actually been told; during a revoke the former drops first. Treat either as held.
        issued = CapabilityString.new(client_cap['issued'])
        pending = CapabilityString.new(client_cap['pending'])
        next unless issued.write? || pending.write?

        { ino: cached_inode['ino'], client_id: client_cap['client_id'], issued: issued.to_s,
          pending: pending.to_s, write_grants: issued.write_grants | pending.write_grants }
      end
    end

    # Memoized on defined? rather than ||=, because this is asked once per cached inode and
    # an empty result is both common and expensive to recompute.
    def local_client_ids
      return @local_client_ids if defined?(@local_client_ids)

      @local_client_ids = client.ranks
                                .flat_map { |rank| client.sessions(rank:) }
                                .select { |session| local_session?(session) }
                                .map { |session| session['id'] }
                                .uniq
                                .tap { |client_ids| logger.debug("local CephFS client ids: #{client_ids}") }
    end

    def local_session?(session)
      session_hostname = session.dig('client_metadata', 'hostname')
      session_hostname.present? && short_hostname(session_hostname) == short_hostname(local_hostname)
    end

    def short_hostname(hostname)
      hostname.to_s.downcase.split('.').first
    end

    def local_hostname
      settings.local_hostname.presence || Socket.gethostname
    end
  end
end
