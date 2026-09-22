# frozen_string_literal: true

module Ceph
  # A CephFS capability ("cap") string as rendered by the MDS, e.g. "pAsLsXsFscb", or
  # "-" when a client holds no capabilities at all.
  #
  # The grammar (see ccap_string()/gcap_string() in src/mds/mdstypes.h in the Ceph
  # source) is an optional leading "p" (pin), followed by one section per capability
  # class, each of which is a class letter followed by one or more grant letters:
  #
  #   class letters: A auth, L link, X xattr, F file
  #   grant letters: s shared, x exclusive, c cache, r read,
  #                  w write, b buffer, a wrextend, l lazyio
  #
  # Only the file class uses grant letters beyond "s" and "x".
  #
  # A grant is treated as a write capability when holding it means the client may have
  # state that other clients cannot see yet: an exclusive cap on any class, or the
  # write/buffer/wrextend file caps. In particular "Fb" (buffer) means the client is
  # holding dirty file data that has not necessarily reached the OSDs, and "Fx" means
  # the client, not the MDS, holds the authoritative size and mtime.
  class CapabilityString
    SECTION_PATTERN = /([ALXF])([sxcrwbal]+)/
    PIN = 'p'
    NONE = '-'

    WRITE_GRANTS = {
      'A' => %w[x].freeze,
      'L' => %w[x].freeze,
      'X' => %w[x].freeze,
      'F' => %w[x w b a].freeze
    }.freeze

    attr_reader :capability_string

    # @param capability_string [String] e.g. "pAsLsXsFscb"
    def initialize(capability_string)
      @capability_string = capability_string.to_s
    end

    # @return [Boolean] true when the holder may have unflushed writes or exclusive state
    def write?
      write_grants.any?
    end

    # @return [Array<String>] the write capabilities held, e.g. ["Fw", "Fb"]
    def write_grants
      @write_grants ||= WRITE_GRANTS.flat_map do |capability_class, write_grant_letters|
        (grants_by_class.fetch(capability_class, []) & write_grant_letters)
          .map { |grant_letter| "#{capability_class}#{grant_letter}" }
      end
    end

    # @return [Hash<String, Array<String>>] class letter => grant letters, e.g. { "F" => ["s", "c", "b"] }
    def grants_by_class
      @grants_by_class ||= capability_string.scan(SECTION_PATTERN)
                                            .to_h { |capability_class, grants| [capability_class, grants.chars] }
    end

    def pinned?
      capability_string.start_with?(PIN)
    end

    def none?
      capability_string == NONE || capability_string.empty?
    end

    def to_s
      capability_string
    end
  end
end
