# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Activity
        class Show < View
          include Components::Activity

          SEPARATOR = " · "

          def initialize(events:, filters:, saved_views:, totals:, older:, newer:)
            super()
            @events = events
            @filters = filters
            @saved_views = saved_views
            @totals = totals
            @older = older
            @newer = newer
          end

          def view_template
            PageHead(title: t(".heading"), sub:)

            Split do
              Filters(**@filters, saved_views: @saved_views)
              div(class: "activity-main") do
                timeline
                DayPager(older: @older, newer: @newer, **@filters.slice(:from, :to, :types, :text))
              end
            end
          end

          private

          def date(value) = l(value, format: :medium)

          def days
            @days ||= @events.chunk_while { |one, other| one.occurred_on == other.occurred_on }.map do |group|
              [group.first.occurred_on, group]
            end
          end

          def sub
            [
              t(".span", from: date(@filters[:from]), to: date(@filters[:to])),
              t(".across", events: t(".events", count: @totals[:events]), days: t(".days", count: @totals[:days])),
            ].join(SEPARATOR)
          end

          def timeline
            return Empty { t(".empty") } if days.empty?

            days.each { |(date, events)| Day(date:, events:, today: @filters[:today]) }
          end
        end
      end
    end
  end
end
