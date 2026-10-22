# frozen_string_literal: true

module Notes
  module Operations
    class CreateNote < Blog::Operation
      REFUSALS = {
        "notes_folder_id_fkey" => [:folder_id, Blog::Contract::MISSING],
        "notes_title_index" => [:title, "taken"],
      }.freeze
      UNTITLED = "Untitled"

      include Deps[
        contract: "contracts.note_contract",
        note_mutations: "repos.note_mutations",
        note_queries: "repos.note_queries",
      ]

      def call(params)
        fields = step validated(contract.call(form(params)))
        id = step constrained(note_mutations, REFUSALS) { Success(transaction { create(fields) }) }

        note_queries.by_id(id)
      end

      private

      def create(fields)
        note = note_mutations.create(**fields.except(:tags))
        note_mutations.replace_tags(note.id, fields.fetch(:tags))
        note_mutations.store_links(note.id, note.body)
        note.id
      end

      def form(params)
        title = Blog::Types::TrimmedText[params[:title]]
        title = note_queries.free_title(UNTITLED) if title.empty?

        { title:, body: params[:body], folder_id: params[:folder_id], tags: params[:tags] }
      end
    end
  end
end
