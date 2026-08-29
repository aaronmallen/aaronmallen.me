# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Activity
        class Show < View
          include Components::Activity

          SEPARATOR = " · "

          def initialize(events:, filters:)
            super()
            @events = events
            @filters = filters
          end

          def view_template
            PageHead(title: t(".heading"), sub:)

            Split do
              Filters(**@filters)
              div(class: "activity-main") { timeline }
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
              t(".across", events: t(".events", count: @events.size), days: t(".days", count: days.size)),
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
