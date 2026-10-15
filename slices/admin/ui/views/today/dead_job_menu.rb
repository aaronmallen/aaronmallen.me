# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Today
        class DeadJobMenu < View
          layout nil

          prop :job, Blog::Types::Instance(Data)

          def view_template
            ContextMenu(label: @job.name) do |menu|
              menu.post(t(".retry"), action: act(:admin_retry_dead_job), icon: "fa-solid fa-rotate-right")
              menu.copy(t(".copy_error"), text: @job.error, copied: t(".copied_error"), icon: :copy)
              menu.separator
              discard(menu)
            end
          end

          private

          def act(route) = path(route, jid: @job.jid)

          def discard(menu)
            action = act(:admin_discard_dead_job)

            menu.post(t(".discard"), action:, icon: :trash, warn: true, confirm: t(".confirm_discard"))
          end
        end
      end
    end
  end
end
