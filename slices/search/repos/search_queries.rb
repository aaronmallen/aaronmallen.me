# frozen_string_literal: true

module Search
  module Repos
    class SearchQueries < DB::Repo
      NONE = Blog::Constants::EMPTY_ARRAY

      def search(text:, page:, kinds: Blog::Types::SearchKind.values, per_kind: nil)
        phrase = text.to_s.strip
        return page.fill(NONE) if phrase.empty?

        page.fill(search_documents.hits(phrase, kinds:, per_kind:, page:).map { Structs::Hit.new(**it) })
      end
    end
  end
end
