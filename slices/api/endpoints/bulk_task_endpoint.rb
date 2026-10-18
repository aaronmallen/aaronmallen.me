# auto_register: false
# frozen_string_literal: true

module API
  module Endpoints
    class BulkTaskEndpoint < BulkEndpoint
      CONTRACTS = [::Tasks::Contracts::BulkContract].freeze
      COMPLAINTS = Tasks::COMPLAINTS
      FIELDS = { to: :list }.freeze
      KEY = :tasks
      NOUN = "task"
      REFUSALS = { closed: Tasks::CLOSED }.freeze
      REPLY = Helpers::Schema.object({ tasks: Helpers::Schema.list(Serializers::Task.reference) }).freeze
      SCHEMA = Tasks::BULK

      include Deps[act_on: "tasks.operations.act_on_tasks"]

      private

      def answered(tasks) = serialized(Serializers::Task, task_queries.detailed_in_order(tasks.map(&:id).uniq))

      def keyed(errors) = super.transform_keys { FIELDS.fetch(it, it) }
    end
  end
end
