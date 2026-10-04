# frozen_string_literal: true

module Tasks
  module Operations
    class SaveTaskTagRule < Blog::Operation
      FIELDS = %i[pattern tags].freeze
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
        rule = task_tag_rule_repo.create(pattern: fields[:pattern])
        tag_ids = task_tag_rule_repo.replace_tags(rule.id, fields[:tags])
        task_ids = task_tag_rule_repo.matching_task_ids(rule)
        task_event_repo.track(task_ids, now, seen: false) { task_tag_rule_repo.tag_tasks(task_ids, tag_ids) }
        rule.id
      end

      def edit(id, fields)
        task_tag_rule_repo.update(id, pattern: fields[:pattern])
        task_tag_rule_repo.replace_tags(id, fields[:tags])
        id
      end

      def find(id)
        return Success(nil) unless id

        task_tag_rule_repo.by_id(id) ? Success(id) : Failure(:not_found)
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
