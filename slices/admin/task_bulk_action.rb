# auto_register: false
# frozen_string_literal: true

module Admin
  class TaskBulkAction < BulkAction
    include Deps[task_queries: "tasks.repos.task_queries"]

    private

    def named(id)
      task = task_queries.by_id(id)

      { task: task ? "#{task.label} #{task.title}" : UI::Components::RecordKey.key(id) }
    end

    def refusal(errors)
      errors.key?(:to) ? "to_#{Blog::Contract::BLANK}" : super
    end
  end
end
