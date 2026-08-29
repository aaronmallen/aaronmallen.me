# frozen_string_literal: true

module Social
  module Queries
    class WebmentionSettings
      include Deps[webmention_repo: "repos.webmention_repo"]

      def call = webmention_repo.settings
    end
  end
end
