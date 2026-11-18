# frozen_string_literal: true

module Ceph
  # Raised when a query against the Ceph cluster cannot be completed (e.g. the `ceph`
  # executable is missing, the keyring lacks the required capabilities, the command
  # times out, or the response is not parseable).
  class Error < StandardError; end
end
