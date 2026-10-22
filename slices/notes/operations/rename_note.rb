# frozen_string_literal: true

module Notes
  module Operations
    class RenameNote < Blog::Operation
      REFUSALS = { "notes_title_index" => [:title, "taken"] }.freeze

      include Deps[
        contract: "contracts.note_contract",
        note_mutations: "repos.note_mutations",
        note_queries: "repos.note_queries",
      ]

      def call(id, params)
        fields = step validated(contract.call(title: params[:title]))
        step constrained(note_mutations, REFUSALS) { Success(transaction { rename(id, fields.fetch(:title)) }) }

        note_queries.by_id(id)
      end

      private

      def rename(id, title)
        note = step found(note_mutations.by_id_for_update(id))
        note_mutations.update(id, title:)
        note_mutations.relink(note.title, title) unless note.title == title
      end
    end
  end
end
