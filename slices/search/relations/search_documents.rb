# frozen_string_literal: true

module Search
  module Relations
    class SearchDocuments < Blog::DB::Relation
      use :full_text

      LINKED = %i[kind source_id title day status].freeze
      PERSON = { kind: Blog::Types::SearchKind["person"] }.freeze

      schema :search_documents, infer: true

      def open_people
        documents = dataset.db[:search_documents]
        vector = Sequel.function(:to_tsvector, Blog::DB::Plugins::FullText::CONFIG, :body)
        opened = { title: open_title, search_vector: vector }
        columns = documents.columns.map do |name|
          opened.key?(name) ? Sequel.case({ PERSON => opened.fetch(name) }, name).as(name) : name
        end

        new(documents.select(*columns).from_self(alias: :search_documents))
      end

      private

      def open_title
        lines = [1, 2].map { Sequel.function(:nullif, Sequel.function(:split_part, :body, "\n", it), "") }

        Sequel.function(:coalesce, *lines)
      end
    end
  end
end
