# frozen_string_literal: true

module Search
  module Repos
    class SearchQueries < Blog::DB::Repo
      NONE = Blog::Constants::EMPTY_ARRAY

      def counts(text:, kinds: Blog::Types::SearchKind.values)
        phrase = text.to_s.strip
        return Blog::Constants::EMPTY_HASH if phrase.empty?

        search_documents.kind_counts(phrase, kinds:).to_a.to_h { [it[:kind], it[:count]] }
      end

      def search(text:, page:, kinds: Blog::Types::SearchKind.values)
        phrase = text.to_s.strip
        return page.fill(NONE) if phrase.empty?

        page.fill(search_documents.hits(phrase, kinds:, page:).map { Structs::Hit.new(**it) })
      end
    end
  end
end
