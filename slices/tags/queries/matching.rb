# frozen_string_literal: true

module Tags
  module Queries
    class Matching
      include Deps[tag_repo: "repos.tag_repo"]

      def call(scope:, text:, page:) = tag_repo.page_matching(scope, text, page)
    end
  end
end
