# frozen_string_literal: true

module Admin
  module Operations
    class BuildTaskTypesPage
      VALUES = %i[color icon name].freeze

      include Deps[
        task_counts_by_type: "tasks.queries.task_counts_by_type",
        task_types: "tasks.queries.task_types",
      ]

      def call(errors: Dry::Core::Constants::EMPTY_HASH, editing: nil, params: nil)
        {
          counts: task_counts_by_type.call,
          editing:,
          errors:,
          types: task_types.call,
          values: values(params),
        }
      end

      private

      def values(params)
        fields = Blog::Types::Fields[params]

        VALUES.to_h { [it, Blog::Types::Text[fields[it]]] }
      end
    end
  end
end
