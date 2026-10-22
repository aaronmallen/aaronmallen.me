# frozen_string_literal: true

module Notes
  module Operations
    class MoveNoteFolder < Blog::Operation
      REFUSALS = {
        "note_folders_parent_id_fkey" => [:parent_id, Blog::Contract::MISSING],
        "note_folders_parent_loop" => [:parent_id, "inside"],
      }.freeze

      include Deps[
        contract: "contracts.note_folder_contract",
        note_folder_mutations: "repos.note_folder_mutations",
      ]

      def call(id, params)
        fields = step validated(contract.call(parent_id: params[:parent_id]))

        step constrained(note_folder_mutations, REFUSALS) { move(id, fields) }
      end

      private

      def move(id, fields) = transaction { found(note_folder_mutations.update(id, fields)) }
    end
  end
end
