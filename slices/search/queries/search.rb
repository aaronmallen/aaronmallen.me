# frozen_string_literal: true

module Search
  module Queries
    class Search
      include Deps[search_repo: "repos.search_repo"]

      def call(text:, page:, kinds: Blog::Types::SearchKind.values, per_kind: nil)
        search_repo.search(text:, page:, kinds:, per_kind:)
      end
    end
  end
end
