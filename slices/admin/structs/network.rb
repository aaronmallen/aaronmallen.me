# frozen_string_literal: true

module Admin
  module Structs
    class Network < Data.define(:configured, :label, :limit, :max_bytes, :name, :selected)
      LABELS = {
        Blog::Types::NetworkName["bluesky"] => "social.networks.bluesky",
        Blog::Types::NetworkName["mastodon"] => "social.networks.mastodon",
      }.freeze
      SEPARATOR = " + "
    end
  end
end
