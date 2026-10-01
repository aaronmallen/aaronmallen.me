# frozen_string_literal: true

module Public
  module UI
    module Components
      module Posts
        class Edits < Component
          prop :edits, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))

          def view_template
            return if @edits.empty?

            days = ::Posts::EditDays.group(@edits).values

            section(class: "post-edits", aria: { label: t(".label") }) do
              days.each { |edits| day(edits, updated: edits.equal?(days.last)) }
            end
          end

          private

          def date(time, updated:)
            p(class: "post-edit-date") do
              plain t(".before")
              whitespace
              time(class: ("dt-updated" if updated), datetime: Blog::TimeZone.local(time).iso8601) do
                l(Blog::TimeZone.today(time), format: :medium)
              end
              plain t(".after")
            end
          end

          def day(edits, updated:)
            div(class: "post-edit") do
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
