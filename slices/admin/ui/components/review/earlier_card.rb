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
              Capped(items: @earlier) { line(it) }
            end
          end

          private

          def href(record)
            return path(:admin_edit_post, id: record.source_id) if record.type == POST

            Blog::Helpers::RecordKinds.journal_day(routes, record.occurred_on)
          end

          def line(record)
            Line(href: href(record), text: record.name, day: record.occurred_on, format: :medium, menu: menu(record))
          end

          def menu(record)
            path(record.type == POST ? :admin_post_menu : :admin_journal_entry_menu, id: record.source_id)
          end
        end
      end
    end
  end
end
