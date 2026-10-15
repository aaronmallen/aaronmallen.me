# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Tasks
        class SessionMenu < View
          layout nil

          prop :session, Blog::Types::Instance(ROM::Struct)
          prop :task_id, Blog::Types::Integer
          prop :return_to, Blog::Types::String.optional

          def view_template
            ContextMenu(label:, return_to: @return_to) do |menu|
              edit(menu)
              delete(menu) unless @session.running?
            end
          end

          private

          def anchor = "task-session-#{@session.source_id}"

          def delete(menu)
            action = path(:admin_delete_task_session, id: @task_id, session_id: @session.source_id)

            menu.separator
            menu.post(t(".delete"), action:, icon: :trash, warn: true, confirm: t(".confirm_delete"))
          end

          def edit(menu)
            href = "#{path(:admin_task, id: @task_id)}##{anchor}"

            menu.link(t(".edit"), href:, icon: :edit, dialog: anchor)
          end

          def label = t(".label", at: l(Blog::TimeZone.local(@session.occurred_at), format: :short))
        end
      end
    end
  end
end
