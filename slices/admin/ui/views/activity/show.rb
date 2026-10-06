# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Activity
        class Show < View
          include Components::Activity

          prop :events, Blog::Types::Array.of(Blog::Types::Instance(Structs::ActivityEvent))
          prop :filters, Blog::Types::Hash
          prop :saved_views, Blog::Types::Hash
          prop :totals, Blog::Types::Hash.map(Blog::Types::Symbol, Blog::Types::Integer)
          prop :older, Blog::Types::Date.optional
          prop :newer, Blog::Types::Date.optional

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
            dotted(
              t(".span", from: date(@filters[:from]), to: date(@filters[:to])),
              t(".across", events: t(".events", count: @totals[:events]), days: t(".days", count: @totals[:days])),
            )
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
