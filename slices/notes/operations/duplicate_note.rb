# frozen_string_literal: true

module Notes
  module Operations
    class DuplicateNote < Blog::Operation
      REFUSALS = { "notes_title_index" => [:title, "taken"] }.freeze

      include Deps[
        contract: "contracts.note_contract",
        note_mutations: "repos.note_mutations",
        note_queries: "repos.note_queries",
      ]

      def call(id)
        note = step found(note_queries.by_id(id))
        fields = step validated(contract.call(copy(note)))
        copied = step constrained(note_mutations, REFUSALS) { Success(create(fields)) }

        note_queries.by_id(copied.id)
      end

      private

      def copy(note)
        { title: note_queries.free_title("#{note.title} copy"), body: note.body, folder_id: note.folder_id }
      end

      def create(fields)
        transaction do
          note_mutations.create(**fields).tap { note_mutations.store_links(it.id, it.body) }
        end
      end
    end
  end
end
