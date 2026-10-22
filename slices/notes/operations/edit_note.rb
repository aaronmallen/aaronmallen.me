# frozen_string_literal: true

module Notes
  module Operations
    class EditNote < Blog::Operation
      CHANGED = "changed"
      REFUSALS = { "notes_title_index" => [:title, "taken"] }.freeze

      include Deps[
        contract: "contracts.note_contract",
        note_mutations: "repos.note_mutations",
        note_queries: "repos.note_queries",
      ]

      def call(id, params)
        fields = step validated(contract.call(params.slice(:title, :body, :tags).merge(version: params[:version])))
        step constrained(note_mutations, REFUSALS) { Success(transaction { edit(id, **fields) }) }

        note_queries.by_id(id)
      end

      private

      def current(note, version)
        return Failure(:not_found) unless note

        note.version == version ? Success(note) : invalid(:version, CHANGED)
      end

      def edit(id, version:, tags: nil, **fields)
        step current(note_mutations.by_id_for_update(id), version)
        note_mutations.update(id, fields)
        note_mutations.replace_tags(id, tags) if tags
      end
    end
  end
end
