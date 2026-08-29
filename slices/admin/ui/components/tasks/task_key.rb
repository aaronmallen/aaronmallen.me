# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Tasks
        class TaskKey < Component
          PREFIX = "#"

          prop :task, Blog::Types::Instance(ROM::Struct)
          prop :type, Blog::Types::Instance(ROM::Struct).optional, default: nil

          def view_template
            button(
              type: "button",
              class: ["task-key", color],
              title: t(".copy", key:),
              data: { task_key: key, task_key_copied: t(".copied", key:) },
            ) { key }
          end

          private

          def color = Blog::UI::Components::Pill.for_tag_color(@type&.color)&.to_s

          def key = "#{PREFIX}#{@task.id}"
        end
      end
    end
  end
end
