# frozen_string_literal: true

module Notes
  module Operations
    class CreateNoteFolder < Blog::Operation
      FIELDS = %i[name description parent_id].freeze
      REFUSALS = { "note_folders_parent_id_fkey" => [:parent_id, Blog::Contract::MISSING] }.freeze

      include Deps[
        contract: "contracts.note_folder_contract",
        note_folder_mutations: "repos.note_folder_mutations",
      ]

      def call(params)
        fields = step validated(contract.call(FIELDS.to_h { [it, params[it]] }))

        step constrained(note_folder_mutations, REFUSALS) { Success(create(fields)) }
      end

      private

      def create(fields) = transaction { note_folder_mutations.create(**fields) }
    end
  end
end
