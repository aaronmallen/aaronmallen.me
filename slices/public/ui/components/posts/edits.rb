# frozen_string_literal: true

module Public
  module UI
    module Components
      module Posts
        class Edits < Component
          prop :edits, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))

          def view_template
            return if @edits.empty?

            days = Helpers::EditDays.newest_first(@edits).map(&:last)

            section(class: "post-edits") do
              h2(class: "kicker") { t(".label") }
              ul(class: "post-edit-days") do
                days.each { |edits| day(edits, updated: edits.equal?(days.first)) }
              end
            end
          end

          private

          def date(time, updated:)
            p(class: "post-edit-date") { Moment(at: time, format: :day, class: ("dt-updated" if updated)) }
          end

          def day(edits, updated:)
            li(class: "post-edit") do
              date(edits.last.created_at, updated:)
              whitespace
              edits.one? ? note(edits.first) : notes(edits)
            end
          end

          def markdown(edit) = raw(safe(::Posts::Markdown.to_html(edit.note)))

          def note(edit) = div(class: "post-edit-note") { markdown(edit) }

          def notes(edits)
            ul(class: "post-edit-list") do
              edits.each { |edit| li(class: "post-edit-item") { markdown(edit) } }
            end
          end
        end
      end
    end
  end
end
