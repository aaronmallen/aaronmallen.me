# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Settings
        class CronEntryMenu < View
          ACTS = Components::Jobs::CronActs

          layout nil

          prop :entry, Blog::Types::Instance(Data)
          prop :return_to, Blog::Types::String.optional

          def view_template
            ContextMenu(label: @entry.name, return_to: @return_to) do |menu|
              switches(menu)
              performance(menu) if @entry.last
            end
          end

          private

          def performance(menu)
            href = ACTS.performance(@entry, path(:admin_performance, range: ACTS.range(@entry)))

            menu.separator
            menu.link(t(".performance"), href:, icon: ACTS::PERFORMANCE_ICON)
          end

          def switches(menu)
            name = @entry.name
            switch = ACTS.switch(@entry)
            disabled = @entry.unknown?

            menu.post(t(".run"), action: path(:admin_run_cron_entry, name:), icon: ACTS::RUN_ICON, disabled:)
            action = path(:admin_switch_cron_entry, name:, switch:)
            menu.post(t([".switches", switch].join(".")), action:, icon: ACTS::SWITCH_ICONS.fetch(switch), disabled:)
          end
        end
      end
    end
  end
end
