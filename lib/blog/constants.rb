# frozen_string_literal: true

module Blog
  module Constants
    include Dry::Core::Constants

    ACTIVITY_RANGES = [7, 30, 90].freeze
    CHECKED = "1"
    GAP = :gap
    GITHUB_COMMIT_URL = "https://github.com/%s/commit/%s"
    GITHUB_REPO_URL = "https://github.com/%s"
    SLUG_RESERVED = %w[tags].freeze
  end
end
