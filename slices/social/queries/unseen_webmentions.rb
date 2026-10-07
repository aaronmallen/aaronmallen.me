# frozen_string_literal: true

module Social
  module Queries
    class UnseenWebmentions
      include Deps[webmention_repo: "repos.webmention_repo"]

      def call = webmention_repo.unseen
    end
  end
end
