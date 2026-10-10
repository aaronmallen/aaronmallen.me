# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Review
        class EarlierCard < Component
          POST = Blog::Types::ActivityKind["post"]

          prop :earlier, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))

          def render? = @earlier.any?

          def view_template
            Card(title: dotted(t(".title"), Blog::Helpers::Figures.count(@earlier.size)), id: "review-earlier") do
              Capped(items: @earlier) { Line(href: href(it), text: it.name, day: it.occurred_on, format: :medium) }
            end
          end

          private

          def href(record)
            day = record.occurred_on
            return path(:admin_edit_post, id: record.source_id) if record.type == POST

            "#{path(:admin_journal, to: day.iso8601)}##{Journal::Day.anchor(day)}"
          end
        end
      end
    end
  end
end
