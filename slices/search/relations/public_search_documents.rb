# frozen_string_literal: true

module Search
  module Relations
    class PublicSearchDocuments < Blog::DB::Relation
      include FullText

      LINKED = %i[kind source_id title day status slug project number].freeze

      schema :public_search_documents, infer: true
    end
  end
end
