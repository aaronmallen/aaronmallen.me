# frozen_string_literal: true

module Search
  module Relations
    class SearchDocuments < Blog::DB::Relation
      use :full_text

      LINKED = %i[kind source_id title day status].freeze

      schema :search_documents, infer: true
    end
  end
end
