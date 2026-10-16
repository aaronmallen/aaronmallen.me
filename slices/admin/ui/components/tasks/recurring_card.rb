# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Tasks
        class RecurringCard < Component
          prop :series, Blog::Types::Array.of(Blog::Types::Hash)

          def view_template
            Card(title: t(".title"), class: "task-list") do |card|
              card.side { span(class: "card-note") { t(".count", count: @series.size) } }
              p(class: "card-blurb") { t(".blurb") }
              @series.empty? ? Empty { t(".empty") } : @series.each { row(**it) }
            end
          end

          private

          def cadence(series)
            values = {
              count: series.every, day: series.day, weekday: Date::DAYNAMES[series.weekday.to_i],
              month: Date::MONTHNAMES[series.month.to_i], week: series.week && t([".weeks", series.week].join(".")),
            }

            t([".cadence", series.cadence].join("."), **values)
          end

          def next_on(date) = date ? t(".next", date: l(date, format: :long)) : t(".unscheduled")

          def row(series:, next_on:)
            task = series.task

            div(class: "series-row") do
              div(class: "series-head") do
                a(class: "series-title", href: path(:admin_task, id: task.id)) { task.title }
                p(class: "series-meta") { dotted(cadence(series), next_on(next_on)) }
              end
              switch(series, task)
            end
          end

          def switch(series, task)
            AutoForm(method: "post", action: path(:admin_switch_task_series, id: series.id), data: { morph: true }) do
              Checkbox(
                switch: true, label: t(".label"), name: "on", checked: !series.paused,
                aria: { label: t(".switch", title: task.title) },
              )
              noscript { Button(type: "submit", small: true) { t(".save") } }
            end
          end
        end
      end
    end
  end
end
