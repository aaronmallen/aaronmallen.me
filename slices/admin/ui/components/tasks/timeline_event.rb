# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Tasks
        class TimelineEvent < Component
          EVENTS = {
            Blog::Types::TaskTimelineKind["moved"] => ["fa-solid fa-arrow-right-arrow-left", ".moved"],
            Blog::Types::TaskTimelineKind["recurred"] => ["fa-solid fa-repeat", ".recurred"],
            Blog::Types::TaskTimelineKind["status_changed"] => ["fa-regular fa-circle-dot", ".status_changed"],
            Blog::Types::TaskTimelineKind["tagged"] => ["fa-solid fa-tag", ".tagged"],
            Blog::Types::TaskTimelineKind["untagged"] => ["fa-solid fa-tag", ".untagged"],
          }.freeze

          prop :entry, Blog::Types::Instance(ROM::Struct)

          def view_template
            icon, key = EVENTS.fetch(@entry.kind)

            li(class: "timeline-event") do
              Moment(at: @entry.occurred_at, format: :short, class: "timeline-time")
              span(class: "timeline-event-text") do
                Icon(["timeline-event-icon", icon])
                plain t(key, **parts)
              end
            end
          end

          private

          def parts
            {
              from: place(@entry.from_list, @entry.from_sprint_on) || status_name(@entry.from_status),
              to: place(@entry.to_list, @entry.to_sprint_on) || status_name(@entry.to_status),
              tag: @entry.tag_name,
            }
          end

          def place(list, sprint_on)
            if list then t(Helpers::TaskLists.name(list))
            elsif sprint_on then t(".sprint", day: l(sprint_on, format: :medium))
            end
          end

          def status_name(status) = status && t(Helpers::TaskStatuses.name(status))
        end
      end
    end
  end
end
