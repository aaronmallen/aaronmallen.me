# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Tasks
        class TaskKey < Component
          PREFIX = "#"

          prop :task, Blog::Types::Instance(ROM::Struct)

          def view_template
            button(
              type: "button",
              class: "task-key",
              title: t(".copy", key:),
              data: { task_key: key, task_key_copied: t(".copied", key:) },
            ) { key }
          end

          private

          def key = "#{PREFIX}#{@task.id}"
        end
      end
    end
  end
end
