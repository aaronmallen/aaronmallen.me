# frozen_string_literal: true

module Projects
  module Operations
    class AddWorkEntry < Blog::Operation
      include Deps[
        contract: "contracts.work_entry_contract",
        work_entry_mutations: "repos.work_entry_mutations",
      ]

      def call(params)
        fields = step validate(params)
        work_entry_mutations.create(**fields, position: work_entry_mutations.next_position)
      end
    end
  end
end
