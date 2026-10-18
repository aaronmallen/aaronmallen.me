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

          def self.morning(day) = Blog::TimeZone.local_time(day.year, day.month, day.day, MORNING_HOUR)

          def self.quick_picks(now)
            today = Blog::TimeZone.local_date(now)
            later = Time.at(((now.to_i / HOUR) + LATER_HOURS) * HOUR)

            {
              later_today: (later if Blog::TimeZone.local_date(later) == today),
              tomorrow: morning(today + 1),
              next_week: morning(today + 7 - ((today.wday - MONDAY) % 7)),
            }.compact
          end

          prop :action, Blog::Types::String
          prop :id, Blog::Types::String
          prop :dialog, Blog::Types::Instance(Dialog)

          def view_template(&)
            @now = Time.now

            @dialog.foot { Button(type: "submit", form: form_id, variant: :pri, small: true) { t(".save") } }

            Form(id: form_id, action: @action, class: "snooze-form", data: { morph: true }) do
              yield if block_given?
              picks
              field
            end
          end

          private

          def field
            Field(label: t(".until"), id: "#{@id}-until") do |control|
              Input(
                type: "datetime-local", name: "snoozed_until", required: true,
                min: Blog::TimeZone.input_value(@now), **control,
              )
            end
          end

          def form_id = "#{@id}-form"

          def pick(label_key, at)
            value = Blog::TimeZone.input_value(at)

            Button(type: "submit", name: "pick", value:, formnovalidate: true, small: true) { t(label_key) }
          end

          def picks = div(class: "snooze-picks") { self.class.quick_picks(@now).each { |key, at| pick(".#{key}", at) } }
        end
      end
    end
  end
end
