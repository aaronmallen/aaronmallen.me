# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Mail
        class TaskButton < Component
          prop :thread, Blog::Types::Instance(ROM::Struct)
          prop :task, Blog::Types::Integer.optional
          prop :list, Blog::Types::Hash

          def view_template
            return TaskDialog(thread: @thread, list: @list) unless @task

            Button(small: true, icon: "fa-solid fa-square-check", href: path(:admin_task, id: @task)) do
              t(".task", id: @task)
            end
          end
        end
      end
    end
  end
end
