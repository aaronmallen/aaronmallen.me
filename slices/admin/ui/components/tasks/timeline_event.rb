# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Tasks
        class TimelineEvent < Component
          EVENTS = {
            Blog::Types::TaskTimelineKind["moved"] => ["fa-solid fa-arrow-right-arrow-left", ".moved"],
            Blog::Types::TaskTimelineKind["status_changed"] => ["fa-regular fa-circle-dot", ".status_changed"],
            Blog::Types::TaskTimelineKind["tagged"] => ["fa-solid fa-tag", ".tagged"],
            Blog::Types::TaskTimelineKind["untagged"] => ["fa-solid fa-tag", ".untagged"],
          }.freeze
          LISTS = Blog::Types::TaskList.values.to_h { [it, ".lists.#{it}"] }.freeze
          SESSION_ICON = "fa-regular fa-clock"
          STATUSES = Blog::Types::TaskStatus.values.to_h { [it, ".statuses.#{it}"] }.freeze

          prop :entry, Blog::Types::Instance(ROM::Struct)

          def view_template(&)
            li(class: "timeline-event", id:, data: { task_event: @entry.kind }) do
              Icon(["timeline-event-icon", icon])
              span(class: "timeline-event-text") { @entry.session? ? session : event }
              time(class: "timeline-time", datetime: @entry.occurred_at.iso8601) { stamp(@entry.occurred_at) }
              yield if block_given?
            end
          end

          private

          def event = plain(t(EVENTS.fetch(@entry.kind).last, **parts))

          def icon = @entry.session? ? SESSION_ICON : EVENTS.fetch(@entry.kind).first

          def id = @entry.session? ? "task-session-#{@entry.source_id}" : nil

          def parts
            {
              from: place(@entry.from_list, @entry.from_sprint_on) || status_name(@entry.from_status),
              to: place(@entry.to_list, @entry.to_sprint_on) || status_name(@entry.to_status),
              tag: @entry.tag_name,
            }
          end

          def place(list, sprint_on)
            if list then t(LISTS.fetch(list))
            elsif sprint_on then t(".sprint", day: l(sprint_on, format: :medium))
            end
          end

          def session
            return plain(t(".worked", span: Blog::Figures.hours(@entry.seconds))) unless @entry.running?

            plain(t(".running"))
            Pill(color: :blue) { t(".running_pill") }
          end

          def stamp(time) = l(Blog::TimeZone.local(time), format: :medium)

          def status_name(status) = status && t(STATUSES.fetch(status))
        end
      end
    end
  end
end
