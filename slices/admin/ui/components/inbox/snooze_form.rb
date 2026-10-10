# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Inbox
        class SnoozeForm < Component
          HOUR = 3600
          LATER_HOURS = 3
          MORNING_HOUR = 8
          MONDAY = 1

          prop :action, Blog::Types::String
          prop :field_id, Blog::Types::String
          prop :now, Blog::Types::Instance(Time), default: -> { Time.now }

          def view_template(&)
            Form(action: @action, class: "snooze-form") do
              yield if block_given?
              picks
              field
              div(class: "dialog-foot") { Button(type: "submit", variant: :pri, small: true) { t(".save") } }
            end
          end

          private

          def field
            Field(label: t(".until"), id: @field_id) do |control|
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
            later = Time.at(((@now.to_i / HOUR) + LATER_HOURS) * HOUR)

            {
              ".later_today" => (later if Blog::TimeZone.today(later) == today),
              ".tomorrow" => morning(today + 1),
              ".next_week" => morning(today + 7 - ((today.wday - MONDAY) % 7)),
            }.compact
          end
        end
      end
    end
  end
end
