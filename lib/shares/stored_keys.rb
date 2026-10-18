# frozen_string_literal: true

module Shares
  module StoredKeys
    def self.of(*files) = files.flatten.flat_map { [it.preview_key, it.key] }.compact
  end
end
