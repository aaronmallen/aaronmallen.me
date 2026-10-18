# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Jobs
        class CronActs < Component
          PERFORMANCE_ICON = "fa-solid fa-gauge-high"
          RANGES = Blog::Types::AnalyticsRange.values.sort.freeze
          RUN_ICON = "fa-solid fa-play"
          SWITCH_ICONS = { "enable" => RUN_ICON, "pause" => "fa-solid fa-pause" }.freeze

          def self.performance(entry, base) = "#{base}##{Performance::TimingTable.anchor(entry.job)}"

          def self.range(entry)
            days = Blog::TimeZone.today - Blog::TimeZone.today(entry.last[:occurred_at]) + 1

            RANGES.find { it >= days } || RANGES.last
          end

          def self.switch(entry) = entry.paused? ? "enable" : "pause"

          prop :entry, Blog::Types::Instance(Data)
          prop :return_to, Blog::Types::String

          def view_template
            div(class: "jobs-cron-acts") do
              switches unless @entry.enabled.nil?
              performance_link if @entry.last
            end
          end

          private

          def performance_link
            href = self.class.performance(@entry, path(:admin_performance, range: self.class.range(@entry)))

            Button(href:, small: true, icon: PERFORMANCE_ICON, label: t(".performance", name: @entry.name))
          end

          def switches
            name = @entry.name
            switch = self.class.switch(@entry)

            hidden = { return_to: @return_to }

            ButtonForm(
              action: path(:admin_run_cron_entry, name:), label: t(".run", name:), icon: RUN_ICON, icon_only: true,
              hidden:,
            )
            ButtonForm(
              action: path(:admin_switch_cron_entry, name:, switch:), label: t(["", switch].join("."), name:),
              icon: SWITCH_ICONS.fetch(switch), icon_only: true, hidden:,
            )
          end
        end
      end
    end
  end
end
