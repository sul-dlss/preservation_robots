module Preservation

  # ItemError wraps a causal exception, creating a new exception
  #   that usually terminates processing of the current item
  class ItemError < StandardError
  end
end
