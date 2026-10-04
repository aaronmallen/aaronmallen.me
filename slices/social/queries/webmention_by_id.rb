# frozen_string_literal: true

module Social
  module Queries
    class WebmentionById
      include Deps[webmention_repo: "repos.webmention_repo"]

      def call(id) = webmention_repo.by_id(id)
    end
  end
end
