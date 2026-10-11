# frozen_string_literal: true

module Media
  module Types
    KEY_BYTES = 16
    PATH = "/media/"
    REFERENCE = /#{PATH}([0-9a-f]{#{KEY_BYTES * 2}}\.(?:#{Blog::Types::PhotoType.values.join('|')}))/
  end
end
