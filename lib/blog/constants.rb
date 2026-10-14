# frozen_string_literal: true

require "dry/core/constants"

module Blog
  module Constants
    include Dry::Core::Constants

    CHECKED = "1"
    GAP = :gap
    INTEGER_MAX = (2**31) - 1
    MAIL_BODY_MAX = 5000
    MAIL_SUBJECT_MAX = 200
    MEDIA_PATH = "/media/"
    MEDIA_REFERENCE = /#{MEDIA_PATH}([0-9a-f]{32}\.(?:#{Types::PhotoType.values.join('|')}))/
    NETWORK_ICONS = {
      Types::NetworkName["bluesky"] => "fa-brands fa-bluesky",
      Types::NetworkName["linkedin"] => "fa-brands fa-linkedin",
      Types::NetworkName["mastodon"] => "fa-brands fa-mastodon",
    }.freeze
    SUGGESTION_EDITS_MAX = 50
    SUGGESTION_REASON_MAX = 200
    SUGGESTION_TEXT_MAX = 1000
    TOUCH_EVERY = 5 * 60
    WRITING_PATH = "/writing"
  end
end
