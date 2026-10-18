# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Settings
        class SetJobMenu < View
          ACTS = Components::Jobs::SetActs

          layout nil

          prop :job, Blog::Types::Instance(Data)
          prop :return_to, Blog::Types::String.optional

          def view_template
            ContextMenu(label: @job.name, return_to: @return_to) do |menu|
              warned, acts = ACTS.acts(@job.set).partition { ACTS::WARNED.include?(it) }
              acts.each { act(menu, it) }
              copy_error(menu) if @job.error?
              warned.each { act(menu, it) }
            end
          end

          private

          def act(menu, act)
            warn = ACTS::WARNED.include?(act)
            confirm = (t([".confirm", act].join(".")) if ACTS::CONFIRMED.include?(act))

            menu.separator if warn
            menu.post(
              t([ACTS::LABELS, act].join(".")), action: path(:admin_act_on_set_job, set: @job.set, jid: @job.jid, act:),
                                                icon: ACTS::ICONS.fetch(act), warn:, confirm:,
            )
          end

          def copy_error(menu)
            menu.copy(t(".copy_error"), text: @job.error, copied: t(".copied_error"), icon: :copy)
          end
        end
      end
    end
  end
end
