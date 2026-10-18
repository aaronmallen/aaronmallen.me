# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Health
        class DayDetail < Component
          prop :baseline, Blog::Types::Instance(::Health::Structs::Baseline)
          prop :day, Blog::Types::Instance(::Health::Structs::Day)
          prop :first, Blog::Types::Date
          prop :span, Blog::Types::HealthSpan
          prop :today, Blog::Types::Date
          prop :workouts, Blog::Types::Array

          def view_template
            div(class: "health-day") do
              head
              div(class: "health-day-cols") do
                div { body }
                div { work }
              end
            end
          end

          private

          def asleep_label
            return t(".asleep") unless @day.bed_at && @day.woke_at

            t(".asleep_between", bed: clock(@day.bed_at), woke: clock(@day.woke_at))
          end

          def based(key, base) = base ? t(".based", label: t(key), base: base.round) : t(key)

          def body
            rows(".body", body_rows)
            day_workouts.each { Workout(workout: it) }
          end

          def body_rows
            [
              [asleep_label, minutes(@day.minutes_asleep), @day.short_night?],
              *heart_rows,
              [t(".movement"), dotted(count(@day.steps), count(@day.active_zone_minutes)), false],
            ]
          end

          def clock(time) = l(Blog::TimeZone.local(time), format: :clock)

          def count(value) = value.nil? ? t(".none") : Blog::Helpers::Figures.count(value)

          def date = @day.day

          def day_workouts = @workouts.select { Blog::TimeZone.local_date(it.started_at) == date }

          def head
            div(class: "health-day-head") do
              h3(class: "health-day-title") { title }
              Moment(at: date, format: :full, class: "health-day-date")
              SegmentedLinks(
                label: t(".days"),
                items: [
                  step(date - 1, rel: "prev", label: ".previous", icon: "fa-chevron-left", disabled: date == @first),
                  step(date + 1, rel: "next", label: ".next", icon: "fa-chevron-right", disabled: date == @today),
                ],
              )
            end
          end

          def heart_rows
            resting = @day.resting_heart_rate

            [
              [based(".hrv", @baseline.hrv), unit(".ms", @day.hrv), @baseline.low_hrv?(@day)],
              [based(".resting", @baseline.resting_heart_rate), unit(".bpm", resting), @baseline.high_resting?(@day)],
            ]
          end

          def minutes(value) = value.nil? ? t(".none") : Blog::Helpers::Figures.minutes(value)

          def rows(key, found)
            p(class: "health-day-key") { t(key) }
            div(class: "health-rows") do
              found.each do |label, value, low|
                div(class: "health-row") do
                  span { label }
                  span(class: ["health-row-value", ("lo" if low)]) { value }
                end
              end
            end
          end

          def step(day, rel:, label:, icon:, disabled:)
            { href: path(:admin_health, span: @span, day: day.iso8601), text: t(label), icon:, rel:, disabled: }
          end

          def title
            ago = (@today - date).to_i
            return t(".ago", count: ago) if ago > 1

            t(ago.zero? ? ".today" : ".yesterday")
          end

          def unit(key, value) = value.nil? ? t(".none") : t(key, count: value.round)

          def work
            rows(".work", work_rows)
            a(class: "health-day-link", href: path(:admin_activity, day: date.iso8601)) { t(".activity") }
          end

          def work_rows
            [
              [t(".focused"), minutes(@day.focus_minutes), false],
              [t(".commits"), count(@day.commits), false],
              [t(".late"), count(@day.late_commits), @day.late_commits.positive?],
              [t(".tasks_done"), count(@day.tasks_done), false],
            ]
          end
        end
      end
    end
  end
end
