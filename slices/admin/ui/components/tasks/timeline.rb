# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Tasks
        class Timeline < Component
          prop :entries, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))

          def view_template
            details(class: "today-more task-timeline") do
              summary do
                Icon("fa-solid fa-chevron-right today-more-chev")
                plain t(".title")
                span(class: "task-timeline-count") { t(".count", count: events.size) }
              end
              next Hint { t(".empty") } if events.empty?

              ol(class: "timeline") { events.each { TimelineEvent(entry: it) } }
            end
          end

          private

          def events = @events ||= @entries.reject { it.comment? || it.session? }
        end
      end
    end
  end
end
