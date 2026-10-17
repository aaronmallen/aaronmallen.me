# frozen_string_literal: true

module Search
  module Relations
    class PublicSearchDocuments < Blog::DB::Relation
      use :full_text

      HIT = Structs::PublicHit
      HEADLINE = %(MaxWords=24, MinWords=12, StartSel="#{HIT::MARK}", StopSel="#{HIT::UNMARK}").freeze
      LINKED = %i[kind source_id title day status slug project number].freeze

      schema :public_search_documents, infer: true
    end
  end
end
