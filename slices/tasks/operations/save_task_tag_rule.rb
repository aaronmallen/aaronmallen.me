# frozen_string_literal: true

module Tasks
  module Operations
    class SaveTaskTagRule < Operation
      FIELDS = %i[pattern provider tags].freeze
      GITHUB = Blog::Types::TaskSourceProvider["github"]
      TAKEN = "taken"

      include Deps[
        contract: "contracts.task_tag_rule_contract",
        task_event_repo: "repos.task_event_repo",
        task_tag_rule_repo: "repos.task_tag_rule_repo",
      ]

      def call(params, id: nil, now: Time.now)
        step find(id)
        fields = step validate(params)

        step persist(id, fields, now)
      end

      private

      def create(fields, now)
        rule = task_tag_rule_repo.create(pattern: fields[:pattern], provider: fields[:provider] || GITHUB)
        tag_ids = task_tag_rule_repo.replace_tags(rule.id, fields[:tags])
        task_ids = task_tag_rule_repo.matching_task_ids(rule)
        task_event_repo.track(task_ids, now, seen: false) { task_tag_rule_repo.tag_tasks(task_ids, tag_ids) }
        rule.id
      end

      def edit(id, fields)
        task_tag_rule_repo.update(id, **fields.slice(:pattern, :provider).compact)
        task_tag_rule_repo.replace_tags(id, fields[:tags])
        id
      end

      def find(id)
        return Success(nil) unless id

        found(task_tag_rule_repo.by_id(id) && id)
      end

      def persist(id, fields, now)
        Success(transaction { task_tag_rule_repo.by_id(id ? edit(id, fields) : create(fields, now)) })
      rescue ROM::SQL::UniqueConstraintError
        Failure([:invalid, { pattern: [TAKEN] }])
      end

      def validate(params) = validated(contract.call(FIELDS.to_h { [it, params[it]] }))
    end
  end
end
