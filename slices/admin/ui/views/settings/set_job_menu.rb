# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Settings
        class SetJobMenu < View
          ACTS = Components::Jobs::SetActs
          CONFIRMS = %w[kill delete discard].to_h { [it, ".confirm.#{it}"] }.freeze
          LABELS = %w[run retry kill delete discard].to_h { [it, ".#{it}"] }.freeze

          layout nil

          prop :job, Blog::Types::Instance(Data)
          prop :return_to, Blog::Types::String.optional

          def view_template
            ContextMenu(label: @job.name, return_to: @return_to) do |menu|
              ACTS::ACTS.fetch(@job.set).each { act(menu, it) }
            end
          end

          private

          def act(menu, act)
            warn = ACTS::WARNED.include?(act)
            confirm = (t(CONFIRMS[act]) if CONFIRMS.key?(act))

            menu.separator if warn
            menu.post(
              t(LABELS.fetch(act)), action: path(:admin_act_on_set_job, set: @job.set, jid: @job.jid, act:),
                                    icon: ACTS::ICONS.fetch(act), warn:, confirm:,
            )
          end
        end
      end
    end
  end
end
