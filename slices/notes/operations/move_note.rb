# frozen_string_literal: true

module Notes
  module Operations
    class MoveNote < Blog::Operation
      REFUSALS = { "notes_folder_id_fkey" => [:folder_id, Blog::Contract::MISSING] }.freeze

      include Deps[
        contract: "contracts.note_contract",
        note_mutations: "repos.note_mutations",
        note_queries: "repos.note_queries",
      ]

      def call(id, params)
        fields = step validated(contract.call(folder_id: params[:folder_id]))
        step constrained(note_mutations, REFUSALS) { transaction { found(note_mutations.update(id, fields)) } }

        note_queries.by_id(id)
      end
    end
  end
end
