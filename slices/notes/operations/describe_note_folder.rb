# frozen_string_literal: true

module Notes
  module Operations
    class DescribeNoteFolder < Blog::Operation
      include Deps[
        contract: "contracts.note_folder_contract",
        note_folder_mutations: "repos.note_folder_mutations",
      ]

      def call(id, params)
        fields = step validated(contract.call(description: params[:description]))

        step found(note_folder_mutations.update(id, fields))
      end
    end
  end
end
