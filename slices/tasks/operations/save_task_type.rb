# frozen_string_literal: true

module Tasks
  module Operations
    class SaveTaskType < Blog::Operation
      CLEARABLE = %i[icon].freeze
      FIELDS = %i[color icon name].freeze
      NAME_KEY = "task_types_name_key"
      TAKEN = "taken"

      include Deps[contract: "contracts.task_type_contract", task_type_repo: "repos.task_type_repo"]

      def call(params, id: nil)
        step find(id)
        fields = step validate(params)

        step persist(id, fields, params)
      end

      private

      def changes(fields, params) = fields.compact.merge(fields.slice(*CLEARABLE.select { params.key?(it) }))

      def find(id)
        return Success(nil) unless id

        task_type_repo.by_id(id) ? Success(id) : Failure(:not_found)
      end

      def form(params) = FIELDS.to_h { [it, params[it]] }

      def persist(id, fields, params)
        Success(transaction { id ? task_type_repo.update(id, **changes(fields, params)) : store(fields) })
      rescue ROM::SQL::UniqueConstraintError => e
        raise unless task_type_repo.violated_constraint(e) == NAME_KEY

        Failure([:invalid, { name: [TAKEN] }])
      end

      def store(fields)
        task_type_repo.create(
          color: task_type_repo.next_color, position: task_type_repo.next_position, **fields.compact,
        )
      end

      def validate(params) = validated(contract.call(form(params)))
    end
  end
end
