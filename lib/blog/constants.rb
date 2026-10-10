# frozen_string_literal: true

require "dry/core/constants"

module Blog
  module Constants
    include Dry::Core::Constants

    CHECKED = "1"
    GAP = :gap
    INTEGER_MAX = (2**31) - 1
    NETWORK_ICONS = {
      Types::NetworkName["bluesky"] => "fa-brands fa-bluesky",
      Types::NetworkName["mastodon"] => "fa-brands fa-mastodon",
    }.freeze
    WRITING_PATH = "/writing"
  end
end
