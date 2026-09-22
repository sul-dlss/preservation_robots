# frozen_string_literal: true

module Ceph
  # Raised when another host still holds write capabilities on a path after we have
  # waited as long as we are willing to wait for it to release them.
  class WriteCapabilitiesHeldError < Error; end
end
