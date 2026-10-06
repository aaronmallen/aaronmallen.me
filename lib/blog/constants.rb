# frozen_string_literal: true

module Blog
  module Constants
    include Dry::Core::Constants

    ACTIVITY_RANGES = [7, 30, 90].freeze
    ACTIVITY_SCREEN_KINDS = %w[
      commit post journal social task session comment decision decision_comment webmention
    ].freeze
    CHECKED = "1"
    GAP = :gap
    GITHUB_COMMIT_URL = "https://github.com/%s/commit/%s"
    GITHUB_ISSUE_URL = "https://github.com/%s/issues/%s"
    GITHUB_REPO_URL = "https://github.com/%s"
    INTEGER_MAX = (2**31) - 1
    SLUG_RESERVED = %w[tags].freeze
    TIME_RANGES = [7, 30, 90].freeze
  end
end
