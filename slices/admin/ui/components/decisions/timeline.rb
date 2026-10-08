# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Decisions
        class Timeline < Component
          prop :decision, Blog::Types::Instance(ROM::Struct)
          prop :entries, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))

          def view_template
            Card(title: t(".title"), class: "timeline-card") do
              next Hint { t(".empty") } if events.empty?

              ol(class: "timeline") { events.each { TimelineEvent(entry: it, options:) } }
            end
          end

          private

          def events = @events ||= @entries.reject(&:comment?)

          def options = @options ||= @decision.options.to_h { [it.id, it.title] }
        end
      end
    end
  end
end
