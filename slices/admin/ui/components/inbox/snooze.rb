# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Inbox
        class Snooze < Component
          HOUR = 3600
          LATER_HOURS = 3
          MORNING_HOUR = 8
          MONDAY = 1

          prop :kind, Blog::Types::String
          prop :id, Blog::Types::Integer
          prop :now, Blog::Types::Instance(Time), default: -> { Time.now }

          def view_template
            Button(small: true, data: { dialog_open: dialog_id }) { t(".open") }
            Dialog(id: dialog_id, title_id: "#{dialog_id}-title", title: t(".title"), data: { dialog: true }) do
              Form(action: path(:admin_inbox_snooze, kind: @kind, id: @id), class: "snooze-form") do
                picks
                field
                div(class: "dialog-foot") { Button(type: "submit", variant: :pri, small: true) { t(".save") } }
              end
            end
          end

          private

          def dialog_id = "snooze-#{@kind}-#{@id}"

          def field
            Field(label: t(".until"), id: "#{dialog_id}-until") do |control|
              Input(
                type: "datetime-local", name: "snoozed_until", required: true,
                min: Blog::TimeZone.input_value(@now), **control,
              )
            end
          end

          def morning(day) = Blog::TimeZone.local_time(day.year, day.month, day.day, MORNING_HOUR)

          def pick(label_key, at)
            value = Blog::TimeZone.input_value(at)

            Button(type: "submit", name: "pick", value:, formnovalidate: true, small: true) { t(label_key) }
          end

          def picks = div(class: "snooze-picks") { quick_picks.each { |label_key, at| pick(label_key, at) } }

          def quick_picks
            today = Blog::TimeZone.today(@now)

            {
              ".later_today" => Time.at(((@now.to_i / HOUR) + LATER_HOURS) * HOUR),
              ".tomorrow" => morning(today + 1),
              ".next_week" => morning(today + 7 - ((today.wday - MONDAY) % 7)),
            }
          end
        end
      end
    end
  end
end
