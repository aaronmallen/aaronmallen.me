# frozen_string_literal: true

module Tasks
  module Operations
    class LinkTasks < Blog::Operation
      BLOCKED_BY = Blog::Types::TaskLinkKind["blocked_by"]
      BLOCKS = Blog::Types::TaskLinkType["blocks"]
      CONSTRAINTS = {
        "task_links_distinct_check" => [:other_id, "self"],
        "task_links_from_task_id_fkey" => [:other_id, "missing"],
        "task_links_pair_key" => [:other_id, "taken"],
        "task_links_to_task_id_fkey" => [:other_id, "missing"],
      }.freeze
      FIELDS = %i[kind other_id].freeze

      include Deps[
        contract: "contracts.task_link_contract",
        task_mutations: "repos.task_mutations",
        task_queries: "repos.task_queries",
      ]

      def call(id, params)
        step find(id)
        fields = step validate(params)
        step persist(id, **fields)

        task_queries.by_id(id)
      end

      private

      def find(id) = found(task_queries.by_id(id) && id)

      def form(params) = FIELDS.to_h { [it, params[it]] }

      def persist(id, kind:, other_id:)
        from, to, type = kind == BLOCKED_BY ? [other_id, id, BLOCKS] : [id, other_id, kind]

        Success(transaction { task_mutations.link(from, to, type) })
      rescue ROM::SQL::UniqueConstraintError, ROM::SQL::CheckConstraintError, ROM::SQL::ForeignKeyConstraintError => e
        field, code = CONSTRAINTS[task_mutations.violated_constraint(e)]
        raise unless field

        Failure([:invalid, { field => [code] }])
      end

      def validate(params) = validated(contract.call(form(params)))
    end
  end
end
