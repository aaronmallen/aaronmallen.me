# frozen_string_literal: true

module Tasks
  module Operations
    class SaveTaskRule < Operation
      FIELDS = %i[pattern provider tags projects].freeze
      GITHUB = Blog::Types::TaskSourceProvider["github"]
      MISSING = "missing"
      TAKEN = "taken"

      include Deps[
        contract: "contracts.task_rule_contract",
        task_event_mutations: "repos.task_event_mutations",
        task_rule_mutations: "repos.task_rule_mutations",
        task_rule_queries: "repos.task_rule_queries",
      ]

      def call(params, id: nil, now: Time.now)
        step find(id)
        fields = step validate(params)

        step persist(id, fields, now)
      end

      private

      def create(fields, now)
        rule = task_rule_mutations.create(pattern: fields[:pattern], provider: fields[:provider] || GITHUB)
        tag_ids = task_rule_mutations.replace_tags(rule.id, fields[:tags])
        project_ids = projects(fields)
        task_rule_mutations.replace_projects(rule.id, project_ids)
        reach(rule, tag_ids, project_ids, now)
        rule.id
      end

      def edit(id, fields)
        task_rule_mutations.update(id, **fields.slice(:pattern, :provider).compact)
        task_rule_mutations.replace_tags(id, fields[:tags])
        task_rule_mutations.replace_projects(id, projects(fields))
        id
      end

      def find(id)
        return Success(nil) unless id

        found(task_rule_queries.by_id(id) && id)
      end

      def persist(id, fields, now)
        Success(transaction { task_rule_queries.by_id(id ? edit(id, fields) : create(fields, now)) })
      rescue ROM::SQL::UniqueConstraintError
        Failure([:invalid, { pattern: [TAKEN] }])
      rescue ROM::SQL::ForeignKeyConstraintError
        Failure([:invalid, { projects: [MISSING] }])
      end

      def projects(fields) = fields[:projects] || Blog::Constants::EMPTY_ARRAY

      def reach(rule, tag_ids, project_ids, now)
        task_ids = task_rule_queries.matching_task_ids(rule)
        task_event_mutations.track(task_ids, now, seen: false) { task_rule_mutations.tag_tasks(task_ids, tag_ids) }
        task_rule_mutations.link_projects(task_ids, project_ids)
      end

      def validate(params) = validated(contract.call(FIELDS.to_h { [it, params[it]] }))
    end
  end
end
