# frozen_string_literal: true

require "dry/core/constants"

module Blog
  module Constants
    include Dry::Core::Constants

    BEARER = /\ABearer +(?<token>\S+)\z/i
    CHECKED = "1"
    GAP = :gap
    HANAKAI_URL = "https://hanakai.org"
    INTEGER_MAX = (2**31) - 1
    MAIL_BODY_MAX = 5000
    MAIL_SUBJECT_MAX = 200
    MEDIA_PATH = "/media/"
    MEDIA_REFERENCE = %r{#{MEDIA_PATH}(?:\d+/)?(#{Types::PHOTO_KEY})}
    GITHUB_ICON = "fa-brands fa-github"
    NETWORK_ICONS = {
      Types::NetworkName["bluesky"] => "fa-brands fa-bluesky",
      Types::NetworkName["linkedin"] => "fa-brands fa-linkedin",
      Types::NetworkName["mastodon"] => "fa-brands fa-mastodon",
    }.freeze
    READ_SECONDS_MAX = 20 * 60
    REF_KEY = "ref"
    SUGGESTION_EDITS_MAX = 50
    SUGGESTION_REASON_MAX = 200
    SUGGESTION_TEXT_MAX = 1000
    TOUCH_EVERY = 5 * 60
    UNMADE_SHORT_CODE = "x" * 5
    WRITING_PATH = "/writing"
  end
end
