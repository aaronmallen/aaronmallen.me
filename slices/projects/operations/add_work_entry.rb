# frozen_string_literal: true

module Projects
  module Operations
    class AddWorkEntry < Blog::Operation
      FIELDS = %i[blurb from_year org role to_year].freeze

      include Deps[contract: "contracts.work_entry_contract", work_entry_mutations: "repos.work_entry_mutations"]

      def call(params)
        fields = step validate(params)
        work_entry_mutations.create(**fields, position: work_entry_mutations.next_position)
      end

      private

      def form(params) = FIELDS.to_h { [it, params[it]] }

      def validate(params) = validated(contract.call(form(params)))
    end
  end
end
